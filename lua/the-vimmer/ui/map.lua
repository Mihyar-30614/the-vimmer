local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local progress = require("the-vimmer.progress")

function M.open_map(progress_data, rooms_by_tier, on_select)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}

  local width = common.pick_float_width(float.FLOAT_MAP_W)
  local b = common.make_border(width)
  local room_title_max = math.max(24, width - 14)
  local boss_title_max = math.max(20, width - 18)
  local boss_locked_title_max = math.max(16, width - 26)
  local bar = common.xp_bar(progress_data.total_xp, 6)
  local lines = {}
  local hls = {}
  local selectable = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  local tier_colors = {
    beginner = "VimmerTierBeginner",
    warrior  = "VimmerTierWarrior",
    ninja    = "VimmerTierNinja",
  }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA" }
  local tier_prereq = { warrior = "complete boss first", ninja = "complete boss first" }
  local tiers = { "beginner", "warrior", "ninja" }

  add(b.top)
  do
    local left = "  THE VIMMER"
    local right = string.format("XP:%-5d %s", progress_data.total_xp, bar)
    local gap = width - 2 - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right)
    if gap < 1 then gap = 1 end
    add(b.row(left .. string.rep(" ", gap) .. right), "VimmerTitle")
  end
  add(b.sep)

  do
    local rooms_mod = require("the-vimmer.rooms")
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    local weak_room = weak_id and rooms_mod.get_room(weak_id)
    if weak_room then
      local wtitle = weak_room.title
      if #wtitle > 46 then wtitle = wtitle:sub(1, 43) .. "..." end
      add(b.row("  ► Drill: " .. wtitle), "VimmerXP")
      selectable[#selectable + 1] = { line = #lines, room = weak_room }
      add(b.row(""))
    end
  end

  for ti, tier in ipairs(tiers) do
    local all_tier_rooms = rooms_by_tier[tier] or {}
    local tier_rooms = {}
    local boss_room = nil
    for _, room in ipairs(all_tier_rooms) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms+1] = room end
    end

    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared)

    if not unlocked then
      add(b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      local cleared_ct = 0
      local total_ct = #tier_rooms
      for _, room in ipairs(tier_rooms) do
        if progress_data.cleared[room.id] then cleared_ct = cleared_ct + 1 end
      end
      local bar_mini = common.tier_room_bar(cleared_ct, total_ct, 8)
      local boss_hint = ""
      if boss_room then
        local boss_cleared = progress_data.cleared[boss_room.id]
        local boss_unlocked = progress.is_boss_unlocked(tier, progress_data.cleared, total_ct)
        if boss_cleared then boss_hint = "  boss OK"
        elseif boss_unlocked then boss_hint = "  boss!"
        else
          local need = math.ceil(math.max(total_ct, 1) * 0.8)
          boss_hint = string.format("  %d/%d for boss", cleared_ct, need)
        end
      end
      add(b.row(string.format("  [%s]  %d/%d  %s%s",
        tier_labels[tier], cleared_ct, total_ct, bar_mini, boss_hint)), tier_colors[tier])
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, room_title_max))
        if cleared then
          add(b.row(label), "VimmerCleared")
        else
          add(b.row(label))
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
      if boss_room then
        local boss_cleared = progress_data.cleared[boss_room.id]
        local boss_unlocked = progress.is_boss_unlocked(tier, progress_data.cleared, #tier_rooms)
        if boss_cleared then
          add(b.row("   ✓ ⚔  " .. boss_room.title:sub(1, boss_title_max)), "VimmerCleared")
        elseif boss_unlocked then
          add(b.row("   ► ⚔  " .. boss_room.title:sub(1, boss_title_max)), "VimmerBoss")
          selectable[#selectable+1] = { line = #lines, room = boss_room }
        else
          add(b.row("     ⚔  " .. boss_room.title:sub(1, boss_locked_title_max) .. "  [80% first]"), "VimmerLocked")
        end
      end
    end
    if ti < #tiers then add(b.row("")) end
  end

  add(b.sep)
  add(b.row("  <Enter> play   j/k navigate   <q> quit"))
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  local _sel_ns = api.nvim_create_namespace("the-vimmer-sel")
  local cur_idx = 1

  local function update_selection()
    api.nvim_buf_clear_namespace(buf, _sel_ns, 0, -1)
    if #selectable == 0 then return end
    if selectable[cur_idx] then
      api.nvim_buf_add_highlight(buf, _sel_ns, "VimmerSelected",
        selectable[cur_idx].line - 1, 0, -1)
      api.nvim_win_set_cursor(win, { selectable[cur_idx].line, 0 })
    end
  end

  update_selection()

  local function map_key(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  map_key("j", function()
    if #selectable == 0 then return end
    cur_idx = math.min(cur_idx + 1, #selectable)
    update_selection()
  end)

  map_key("k", function()
    if #selectable == 0 then return end
    cur_idx = math.max(cur_idx - 1, 1)
    update_selection()
  end)

  map_key("<CR>", function()
    if #selectable == 0 then return end
    if selectable[cur_idx] then
      local room = selectable[cur_idx].room
      api.nvim_win_close(win, true)
      on_select(room)
    end
  end)

  map_key("q", function()
    api.nvim_win_close(win, true)
  end)

  map_key("<Esc>", function()
    api.nvim_win_close(win, true)
  end)
end

return M
