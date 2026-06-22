local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local progress = require("the-vimmer.progress")

local TIER_COLORS = {
  beginner    = "VimmerTierBeginner",
  warrior     = "VimmerTierWarrior",
  ninja       = "VimmerTierNinja",
  grandmaster = "VimmerTierGrandmaster",
}
local TIER_LABELS = {
  beginner = "BEGINNER", warrior = "WARRIOR",
  ninja = "NINJA", grandmaster = "GRANDMASTER",
}
local TIER_ROMAN = {
  beginner = "I", warrior = "II", ninja = "III", grandmaster = "IV",
}
local TIER_PREREQ = {
  warrior = "beat beginner boss",
  ninja = "beat warrior boss",
  grandmaster = "beat ninja boss",
}
local TIERS = { "beginner", "warrior", "ninja", "grandmaster" }

local function split_tier_rooms(all_tier_rooms)
  local tier_rooms, boss_room = {}, nil
  for _, room in ipairs(all_tier_rooms or {}) do
    if room.is_boss then boss_room = room
    else tier_rooms[#tier_rooms + 1] = room end
  end
  return tier_rooms, boss_room
end

local function count_cleared(tier_rooms, cleared)
  local n = 0
  for _, room in ipairs(tier_rooms) do
    if cleared[room.id] then n = n + 1 end
  end
  return n
end

local function global_room_counts(rooms_by_tier, cleared)
  local cleared_total, room_total = 0, 0
  for _, tier in ipairs(TIERS) do
    local tier_rooms = select(1, split_tier_rooms(rooms_by_tier[tier]))
    room_total = room_total + #tier_rooms
    cleared_total = cleared_total + count_cleared(tier_rooms, cleared)
  end
  return cleared_total, room_total
end

local function boss_hint_game(boss_room, boss_cleared, boss_unlocked, cleared_ct, total_ct)
  if not boss_room then return "" end
  if boss_cleared then return "⚔ CLEARED" end
  if boss_unlocked then return "⚔ READY" end
  local need = math.ceil(math.max(total_ct, 1) * 0.8)
  return string.format("%d/%d ⚔", cleared_ct, need)
end

function M.open_map(progress_data, rooms_by_tier, on_select)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.streak = progress_data.streak or 0
  progress_data.cleared = progress_data.cleared or {}

  local width = common.pick_float_width(float.FLOAT_MAP_W)
  local b = common.make_border(width)
  local room_title_max = math.max(22, width - 18)
  local boss_title_max = math.max(18, width - 22)
  local lines = {}
  local hls = {}
  local selectable = {}

  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end

  local cleared_total, room_total = global_room_counts(
    rooms_by_tier, progress_data.cleared)

  add(b.top)
  add(common.spread_row("⚔  WORLD MAP  ⚔",
    string.format("LV %02d", common.game_level(progress_data.total_xp)), width),
    "VimmerPanel")
  add(b.row(common.game_hud_row(
    width, progress_data.total_xp, progress_data.streak, cleared_total, room_total)),
    "VimmerXP")
  add(b.sep)

  do
    local rooms_mod = require("the-vimmer.rooms")
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    local weak_room = weak_id and rooms_mod.get_room(weak_id)
    if weak_room then
      add(b.row(common.game_section("QUICK PLAY", width)), "VimmerSection")
      add(b.row(common.game_menu_row(false, "★", weak_room.title, room_title_max)),
        "VimmerBadge")
      selectable[#selectable + 1] = {
        line = #lines,
        room = weak_room,
        icon = "★",
        title = weak_room.title,
        title_max = room_title_max,
        hl = "VimmerBadge",
      }
      add(b.sep)
    end
  end

  for _, tier in ipairs(TIERS) do
    local tier_rooms, boss_room = split_tier_rooms(rooms_by_tier[tier])
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared)
    local roman = TIER_ROMAN[tier]
    local label = TIER_LABELS[tier]

    if not unlocked then
      add(b.row(common.game_section(
        string.format("🔒 %s · %s", roman, label), width)), "VimmerLocked")
      add(b.row(string.format("      %s", TIER_PREREQ[tier] or "locked")),
        "VimmerTeachFoot")
    else
      local cleared_ct = count_cleared(tier_rooms, progress_data.cleared)
      local total_ct = #tier_rooms
      local boss_cleared = boss_room and progress_data.cleared[boss_room.id]
      local boss_unlocked = boss_room and progress.is_boss_unlocked(
        tier, progress_data.cleared, total_ct)
      local hint = boss_hint_game(
        boss_room, boss_cleared, boss_unlocked, cleared_ct, total_ct)

      add(b.row(common.spread_row(
        string.format("── %s · %s ──", roman, label),
        common.tier_room_bar(cleared_ct, total_ct, 8) .. "  " .. hint, width)),
        TIER_COLORS[tier])

      for _, room in ipairs(tier_rooms) do
        if progress_data.cleared[room.id] then
          add(b.row(common.game_menu_row(false, "✓", room.title, room_title_max)),
            "VimmerCleared")
        else
          add(b.row(common.game_menu_row(false, "○", room.title, room_title_max)))
          selectable[#selectable + 1] = {
            line = #lines,
            room = room,
            icon = "○",
            title = room.title,
            title_max = room_title_max,
          }
        end
      end

      if boss_room then
        if boss_cleared then
          add(b.row(common.game_menu_row(false, "✓",
            "BOSS · " .. boss_room.title, boss_title_max)), "VimmerCleared")
        elseif boss_unlocked then
          add(b.row(common.game_menu_row(false, "⚔",
            "BOSS · " .. boss_room.title, boss_title_max)), "VimmerBoss")
          selectable[#selectable + 1] = {
            line = #lines,
            room = boss_room,
            icon = "⚔",
            title = "BOSS · " .. boss_room.title,
            title_max = boss_title_max,
            hl = "VimmerBoss",
          }
        else
          add(b.row(common.game_menu_row(false, "🔒",
            "BOSS · " .. boss_room.title, boss_title_max)), "VimmerLocked")
        end
      end
    end
  end

  add(b.sep)
  add(b.row(common.game_footer({
    { "ENTER", "play" }, { "J/K", "move" }, { "Q", "quit" },
  })), "VimmerTeachFoot")
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  local _sel_ns = api.nvim_create_namespace("the-vimmer-sel")
  local cur_idx = 1

  local function write_menu_row(sel, selected)
    local inner = common.game_menu_row(selected, sel.icon, sel.title, sel.title_max)
    local was = api.nvim_buf_get_option(buf, "modifiable")
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, sel.line - 1, sel.line, false, { b.row(inner) })
    api.nvim_buf_set_option(buf, "modifiable", was)
    if sel.hl and not selected then
      api.nvim_buf_add_highlight(buf, 0, sel.hl, sel.line - 1, 0, -1)
    end
  end

  local function update_selection()
    api.nvim_buf_clear_namespace(buf, _sel_ns, 0, -1)
    if #selectable == 0 then return end
    for i, sel in ipairs(selectable) do
      write_menu_row(sel, i == cur_idx)
    end
    float.apply_hl(buf, hls)
    local sel = selectable[cur_idx]
    if sel then
      api.nvim_buf_add_highlight(buf, _sel_ns, "VimmerSelected", sel.line - 1, 0, -1)
      api.nvim_win_set_cursor(win, { sel.line, 0 })
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
      api.nvim_win_close(win, true)
      on_select(selectable[cur_idx].room)
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
