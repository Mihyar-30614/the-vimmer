local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local progress = require("the-vimmer.progress")

local TIERS = { "beginner", "warrior", "ninja", "grandmaster" }
local TIER_LABELS = {
  beginner = "BEGINNER", warrior = "WARRIOR",
  ninja = "NINJA", grandmaster = "GRANDMASTER",
}
local TIER_ROMAN = {
  beginner = "I", warrior = "II", ninja = "III", grandmaster = "IV",
}
local TIER_COLORS = {
  beginner = "VimmerTierBeginner",
  warrior = "VimmerTierWarrior",
  ninja = "VimmerTierNinja",
  grandmaster = "VimmerTierGrandmaster",
}
local TIER_PREREQ = {
  warrior = "beat beginner boss",
  ninja = "beat warrior boss",
  grandmaster = "beat ninja boss",
}

function M.open_progress(progress_data, rooms_by_tier)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}
  progress_data.streak = progress_data.streak or 0

  local width = common.pick_float_width(float.FLOAT_PROGRESS_W)
  local b = common.make_border(width)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end

  local cleared_total, room_total = 0, 0
  for _, tier in ipairs(TIERS) do
    for _, r in ipairs(rooms_by_tier[tier] or {}) do
      if not r.is_boss then
        room_total = room_total + 1
        if progress_data.cleared[r.id] then cleared_total = cleared_total + 1 end
      end
    end
  end

  add(b.top)
  add(common.spread_row("⚔  HERO STATUS  ⚔",
    string.format("LV %02d", common.game_level(progress_data.total_xp)), width),
    "VimmerPanel")
  add(b.row(common.game_hud_row(
    width, progress_data.total_xp, progress_data.streak, cleared_total, room_total)),
    "VimmerXP")
  add(b.sep)

  do
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    if weak_id then
      local wr = require("the-vimmer.rooms").get_room(weak_id)
      if wr then
        add(b.row(common.game_section("TRAINING TARGET", width)), "VimmerSection")
        add(b.row(common.game_menu_row(false, "★", wr.title, width - 12)),
          "VimmerBadge")
        add(b.sep)
      end
    end
  end

  do
    local muts = progress_data.unlocked_mutators or {}
    local names = {}
    for k, v in pairs(muts) do
      if v then names[#names + 1] = k end
    end
    table.sort(names)
    if #names > 0 then
      add(b.row(common.game_section("MUTATORS", width)), "VimmerSection")
      add(b.row("  ✦  " .. table.concat(names, "  ·  ")), "VimmerTimerWarn")
      add(b.sep)
    end
  end

  add(b.row(common.game_section("TIER PROGRESS", width)), "VimmerSection")

  for _, tier in ipairs(TIERS) do
    local all_tier = rooms_by_tier[tier] or {}
    local tier_rooms, boss_room = {}, nil
    for _, room in ipairs(all_tier) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms + 1] = room end
    end

    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared)
    local roman = TIER_ROMAN[tier]
    local label = TIER_LABELS[tier]

    if not unlocked then
      add(b.row(string.format("  🔒 %s · %s  —  %s",
        roman, label, TIER_PREREQ[tier] or "locked")), "VimmerLocked")
    else
      local cleared_ct = 0
      local total_ct = #tier_rooms
      for _, room in ipairs(tier_rooms) do
        if progress_data.cleared[room.id] then cleared_ct = cleared_ct + 1 end
      end
      local boss_txt = "—"
      if boss_room then
        local bc = progress_data.cleared[boss_room.id]
        local bu = progress.is_boss_unlocked(tier, progress_data.cleared, total_ct)
        if bc then boss_txt = "⚔ CLEARED"
        elseif bu then boss_txt = "⚔ READY"
        else
          local need = math.ceil(math.max(total_ct, 1) * 0.8)
          boss_txt = string.format("%d/%d ⚔", cleared_ct, need)
        end
      end
      add(b.row(common.spread_row(
        string.format("  %s · %s", roman, label),
        common.tier_room_bar(cleared_ct, total_ct, 10) .. "  " .. boss_txt, width)),
        TIER_COLORS[tier])
    end
  end

  add(b.sep)
  add(b.row(common.game_footer({ { "Q", "close" } })), "VimmerTeachFoot")
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  local function close_progress()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  vim.keymap.set("n", "q", close_progress, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_progress, { buffer = buf, nowait = true, silent = true })
end

return M
