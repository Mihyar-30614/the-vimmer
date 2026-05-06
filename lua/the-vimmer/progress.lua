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
  return { total_xp = 0, cleared = {}, streak = 0, unlocked_tiers = { beginner = true } }
end

function M.calculate_xp(base_xp, remaining_hp, streak)
  local hp_bonus = math.floor(remaining_hp / 100 * base_xp)
  local subtotal = base_xp + hp_bonus
  local streak_bonus = (streak >= 3) and math.floor(subtotal * 0.5) or 0
  return subtotal + streak_bonus
end

function M.is_tier_unlocked(tier, cleared, total_in_tier)
  if tier == "beginner" then return true end
  local prefix = (tier == "warrior") and "beginner_" or "warrior_"
  local count = 0
  for k in pairs(cleared) do
    if k:match("^" .. prefix) then count = count + 1 end
  end
  return count >= math.ceil((total_in_tier or 1) * 0.8)
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
