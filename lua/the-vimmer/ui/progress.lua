local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local progress = require("the-vimmer.progress")

function M.open_progress(progress_data, rooms_by_tier)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}
  progress_data.streak = progress_data.streak or 0

  local width = common.pick_float_width(float.FLOAT_PROGRESS_W)
  local b = common.make_border(width)
  local bar = common.xp_bar(progress_data.total_xp, 8)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end

  local tiers = { "beginner", "warrior", "ninja" }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA" }
  local tier_colors = {
    beginner = "VimmerTierBeginner",
    warrior = "VimmerTierWarrior",
    ninja = "VimmerTierNinja",
  }
  local tier_prereq = { warrior = "beat beginner boss", ninja = "beat warrior boss" }

  add(b.top)
  add(b.row("  THE VIMMER — PROGRESS"), "VimmerTitle")
  add(b.sep)

  do
    local left = "  Total XP"
    local right = string.format("%d  %s", progress_data.total_xp, bar)
    local gap = width - 2 - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right)
    if gap < 1 then gap = 1 end
    add(b.row(left .. string.rep(" ", gap) .. right), "VimmerXP")
  end

  add(b.row(string.format("  Run streak: %d", progress_data.streak)), "VimmerTierWarrior")

  do
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    if weak_id then
      local wr = require("the-vimmer.rooms").get_room(weak_id)
      if wr then
        local t = wr.title
        if #t > 54 then t = t:sub(1, 51) .. "..." end
        add(b.row("  Suggested drill: " .. t), "VimmerLocked")
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
      add(b.sep)
      add(b.row("  Mutators unlocked: " .. table.concat(names, ", ")), "VimmerTeachFoot")
    end
  end

  local cleared_total, room_total = 0, 0
  for _, tier in ipairs(tiers) do
    for _, r in ipairs(rooms_by_tier[tier] or {}) do
      if not r.is_boss then
        room_total = room_total + 1
        if progress_data.cleared[r.id] then cleared_total = cleared_total + 1 end
      end
    end
  end

  add(b.sep)
  add(b.row(string.format("  Regular rooms: %d / %d cleared", cleared_total, room_total)), "VimmerTitle")
  add(b.sep)

  for _, tier in ipairs(tiers) do
    local all_tier = rooms_by_tier[tier] or {}
    local tier_rooms = {}
    local boss_room = nil
    for _, room in ipairs(all_tier) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms + 1] = room end
    end

    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      add(b.row(string.format(
        "  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      local cleared_ct = 0
      local total_ct = #tier_rooms
      for _, room in ipairs(tier_rooms) do
        if progress_data.cleared[room.id] then cleared_ct = cleared_ct + 1 end
      end
      local mini = common.tier_room_bar(cleared_ct, total_ct, 10)
      local boss_txt = "—"
      if boss_room then
        local bc = progress_data.cleared[boss_room.id]
        local bu = progress.is_boss_unlocked(tier, progress_data.cleared, total_ct)
        if bc then boss_txt = "boss cleared"
        elseif bu then boss_txt = "boss ready"
        else
          local need = math.ceil(math.max(total_ct, 1) * 0.8)
          boss_txt = string.format("%d/%d for boss", need, total_ct)
        end
      end
      add(b.row(string.format(
        "  [%s]  %d/%d  %s   %s",
        tier_labels[tier], cleared_ct, total_ct, mini, boss_txt)),
        tier_colors[tier])
    end
  end

  add(b.sep)
  add(b.row("  <q> or <Esc> close"), "VimmerTeachFoot")
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
