-- Persistence layer for the player's save data (JSON file in stdpath("data")).
-- All functions operate on a plain Lua table ("prog"); callers must call M.save() to persist.
-- The save file lives at: <stdpath("data")>/the-vimmer/progress.json
local M = {}

local function json_encode(t)
  local ok, r = pcall((vim.json or require("the-vimmer.json")).encode, t)
  return ok and r or nil
end

local function json_decode(s)
  local ok, r = pcall((vim.json or require("the-vimmer.json")).decode, s)
  return ok and type(r) == "table" and r or nil
end

local function default_state()
  return {
    total_xp = 0,
    cleared = {},
    streak = 0,
    unlocked_tiers = { beginner = true },
    room_best = {},
    room_stats = {},
    unlocked_mutators = {},
    daily_stamp = "",
    daily_room_id = "",
    daily_mutators = {},
  }
end

--- Mutators unlock when lifetime XP reaches threshold (single-player meta).
M.MUTATOR_UNLOCK_XP = {
  iron = 120,
  glass = 280,
  rush = 480,
}

-- Lazily initialise per-room stat counters; returns the stats sub-table.
function M.ensure_room_stats(prog, room_id)
  prog.room_stats = prog.room_stats or {}
  if not prog.room_stats[room_id] then
    prog.room_stats[room_id] = {
      attempts = 0,
      clears = 0,
      deaths = 0,
      flawless_clears = 0,
      keys_correct = 0,
      keys_wrong = 0,
    }
  end
  return prog.room_stats[room_id]
end

-- Increment attempt counter when the player starts playing (after the teach screen).
function M.record_attempt(prog, room_id)
  local s = M.ensure_room_stats(prog, room_id)
  s.attempts = s.attempts + 1
end

-- Record a successful clear: increments clears, accumulates key stats, marks flawless runs.
function M.record_clear_run(prog, room_id, game_state)
  local s = M.ensure_room_stats(prog, room_id)
  s.clears = s.clears + 1
  s.keys_correct = s.keys_correct + (game_state.keys_correct or 0)
  s.keys_wrong = s.keys_wrong + (game_state.keys_wrong or 0)
  if game_state.flawless_run then
    s.flawless_clears = s.flawless_clears + 1
  end
end

-- Increment death counter (HP → 0 or timer expired).
function M.record_death(prog, room_id)
  local s = M.ensure_room_stats(prog, room_id)
  s.deaths = s.deaths + 1
end

-- Re-evaluate mutator unlocks from lifetime XP; call after every XP gain.
function M.refresh_mutator_unlocks(prog)
  prog.unlocked_mutators = prog.unlocked_mutators or {}
  local xp = prog.total_xp or 0
  for name, need in pairs(M.MUTATOR_UNLOCK_XP) do
    if xp >= need then prog.unlocked_mutators[name] = true end
  end
end

-- Find the regular room where (keys_correct / total_keys) is lowest across all unlocked tiers.
-- Used by the map and progress screens to suggest a practice target.
function M.weakest_regular_room_id(prog, rooms_by_tier)
  local tiers = require("the-vimmer.rooms").all_tiers()
  local worst_id, worst_ratio = nil, 1.0001
  for _, tier in ipairs(tiers) do
    local list = rooms_by_tier[tier] or {}
    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    if M.is_tier_unlocked(tier, prog.cleared, total_prereq) then
      for _, r in ipairs(list) do
        if not r.is_boss then
          local st = prog.room_stats and prog.room_stats[r.id]
          if st and st.attempts > 0 then
            local denom = st.keys_correct + st.keys_wrong
            if denom > 0 then
              local ratio = st.keys_correct / denom
              if ratio < worst_ratio then
                worst_ratio = ratio
                worst_id = r.id
              end
            end
          end
        end
      end
    end
  end
  return worst_id
end

-- XP formula: base + HP bonus (up to +100%), +50% for streak >= 3,
-- × efficiency_mult, × 2 if double. efficiency_mult is computed by
-- game.lua as clamp(#optimal_keystrokes / keystrokes_used, 0.5, 3.0).
function M.calculate_xp(base_xp, remaining_hp, streak, efficiency_mult, double_xp)
  efficiency_mult = efficiency_mult or 1
  local hp_bonus = math.floor(remaining_hp / 100 * base_xp)
  local subtotal = base_xp + hp_bonus
  local streak_bonus = (streak >= 3) and math.floor(subtotal * 0.5) or 0
  local total = (subtotal + streak_bonus) * efficiency_mult
  if double_xp then total = total * 2 end
  return math.floor(total)
end

-- Beginner is always unlocked; warrior/ninja unlock after clearing the previous tier's boss.
function M.is_tier_unlocked(tier, cleared, total_in_tier)
  if tier == "beginner" then return true end
  local boss_id = (tier == "warrior") and "beginner_boss" or "warrior_boss"
  return cleared[boss_id] == true
end

-- Boss unlocks when at least 80% of regular rooms in the tier are cleared.
function M.is_boss_unlocked(tier, cleared, total_regular)
  local prefix = tier .. "_"
  local count = 0
  for k, v in pairs(cleared) do
    if v and k:match("^" .. prefix) and not k:match("_boss$") then
      count = count + 1
    end
  end
  return count >= math.ceil((total_regular or 1) * 0.8)
end

function M.default_path()
  local data_dir = (vim.fn and vim.fn.stdpath("data") or "/tmp") .. "/the-vimmer"
  if vim.fn then vim.fn.mkdir(data_dir, "p") end
  return data_dir .. "/progress.json"
end

function M.save(data, path)
  path = path or M.default_path()
  local encoded = json_encode(data)
  if not encoded then return end
  local f = io.open(path, "w")
  if f then f:write(encoded); f:close() end
end

function M.load(path)
  path = path or M.default_path()
  local f = io.open(path, "r")
  if not f then return default_state() end
  local raw = f:read("*a"); f:close()
  local data = json_decode(raw)
  if not data then return default_state() end
  local def = default_state()
  return vim.tbl_deep_extend("force", def, data)
end

function M.reset(path)
  local state = default_state()
  M.save(state, path)
  return state
end

function M.reset_data()
  return default_state()
end

return M
