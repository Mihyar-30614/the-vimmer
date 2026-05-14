-- Deterministic daily challenge: room + mutators are seeded from the date string
-- (YYYY-MM-DD → integer seed) so every player sees the same room on the same day.
-- Results are cached in `prog` fields so re-calling on the same day returns the same room.
local M = {}

local progress = require("the-vimmer.progress")
local rooms_mod = require("the-vimmer.rooms")

function M.today_stamp()
  return os.date("%Y-%m-%d")
end

-- Resolve today's challenge room + mutators; writes daily_stamp/daily_room_id/daily_mutators
-- into prog when a new day is detected (caller must call progress.save afterwards).
-- 65% chance of adding one unlocked mutator to the daily run.
function M.resolve_for_today(prog, rooms_by_tier)
  local stamp = M.today_stamp()
  prog.daily_stamp = prog.daily_stamp or ""
  prog.daily_room_id = prog.daily_room_id or ""
  prog.daily_mutators = prog.daily_mutators or {}

  if prog.daily_stamp == stamp and prog.daily_room_id ~= "" then
    local room = rooms_mod.get_room(prog.daily_room_id)
    return room, prog.daily_mutators
  end

  math.randomseed(tonumber(stamp:gsub("-", ""), 10))

  local pool = {}
  for _, tier in ipairs(rooms_mod.all_tiers()) do
    local list = rooms_by_tier[tier] or {}
    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    if progress.is_tier_unlocked(tier, prog.cleared, total_prereq) then
      for _, r in ipairs(list) do
        if not r.is_boss then pool[#pool + 1] = r end
      end
    end
  end

  if #pool == 0 then return nil, {} end

  local choice = pool[math.random(#pool)]
  local mut_pool = {}
  for name, on in pairs(prog.unlocked_mutators or {}) do
    if on then mut_pool[#mut_pool + 1] = name end
  end

  local mutators = {}
  if #mut_pool > 0 and math.random() < 0.65 then
    mutators[1] = mut_pool[math.random(#mut_pool)]
  end

  prog.daily_stamp = stamp
  prog.daily_room_id = choice.id
  prog.daily_mutators = mutators
  return choice, mutators
end

return M
