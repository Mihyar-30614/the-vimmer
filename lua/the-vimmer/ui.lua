local M = {}
local api = vim.api
local progress = require("the-vimmer.progress")

local function pad_row(content, width)
  local visible = content:gsub("[\xc2-\xdf][\x80-\xbf]", "_")
    :gsub("[\xe0-\xef][\x80-\xbf][\x80-\xbf]", "_")
    :gsub("[\xf0-\xf7][\x80-\xbf][\x80-\xbf][\x80-\xbf]", "_")
  local pad = width - 2 - #visible
  if pad < 0 then pad = 0 end
  return "║" .. content .. string.rep(" ", pad) .. "║"
end

local function make_border(width)
  return {
    top = "╔" .. string.rep("═", width - 2) .. "╗",
    sep = "╠" .. string.rep("═", width - 2) .. "╣",
    bot = "╚" .. string.rep("═", width - 2) .. "╝",
    row = function(content) return pad_row(content, width) end,
  }
end

local function xp_bar(xp, bar_width)
  local max_xp = 1000
  local filled = math.min(math.floor((xp / max_xp) * bar_width), bar_width)
  return string.rep("▓", filled) .. string.rep("░", bar_width - filled)
end

local _flash_ns = api.nvim_create_namespace("the-vimmer-flash")

local function apply_hl(buf, highlights)
  for _, h in ipairs(highlights) do
    api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
  end
end

local function flash(buf, group, callback)
  local n = api.nvim_buf_line_count(buf)
  for i = 0, n - 1 do
    api.nvim_buf_add_highlight(buf, _flash_ns, group, i, 0, -1)
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, _flash_ns, 0, -1)
    end
    callback()
  end, 100)
end

local function open_float(lines, width)
  local height = #lines
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = row, col = col,
    width = width, height = height,
    style = "minimal", border = "none",
  })
  return buf, win
end

function M.open_map(progress_data, rooms_by_tier, on_select)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}

  local width = 60
  local b = make_border(width)
  local bar = xp_bar(progress_data.total_xp, 6)
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
  local tier_prereq = { warrior = "complete 80% of beginner", ninja = "complete 80% of warrior" }
  local tiers = { "beginner", "warrior", "ninja" }

  add(b.top)
  add(b.row(string.format("  THE VIMMER                     XP:%-5d %s",
    progress_data.total_xp, bar)), "VimmerTitle")
  add(b.sep)

  for ti, tier in ipairs(tiers) do
    local tier_rooms = rooms_by_tier[tier] or {}
    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      add(b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      add(b.row(string.format("  [%s]", tier_labels[tier])), tier_colors[tier])
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, 46))
        if cleared then
          add(b.row(label), "VimmerCleared")
        else
          add(b.row(label))
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
    end
    if ti < #tiers then add(b.row("")) end
  end

  add(b.sep)
  add(b.row("  <Enter> play   j/k navigate   <q> quit"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  local _sel_ns = api.nvim_create_namespace("the-vimmer-sel")
  local cur_idx = 1

  local function update_selection()
    api.nvim_buf_clear_namespace(buf, _sel_ns, 0, -1)
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
    cur_idx = math.min(cur_idx + 1, #selectable)
    update_selection()
  end)

  map_key("k", function()
    cur_idx = math.max(cur_idx - 1, 1)
    update_selection()
  end)

  map_key("<CR>", function()
    if selectable[cur_idx] then
      local room = selectable[cur_idx].room
      api.nvim_win_close(win, true)
      on_select(room)
    end
  end)

  map_key("q", function()
    api.nvim_win_close(win, true)
  end)
end

function M.open_teach(room, on_begin)
  local width = 60
  local b = make_border(width)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("  COMMAND: " .. room.command:gsub("\n", " ↵ ")), "VimmerCommand")
  add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
  add(b.sep)
  add(b.row("  BEFORE:  " .. room.before_example:gsub("\n", " ↵ ")), "VimmerLocked")
  add(b.row("  AFTER:   " .. room.after_example:gsub("\n", " ↵ ")), "VimmerCleared")
  add(b.row(""))
  local tip = room.usage_tip
  while #tip > 56 do
    local cut = tip:sub(1, 56):match("^(.+) ")
    add(b.row("  " .. (cut or tip:sub(1, 56))))
    tip = tip:sub(#(cut or tip:sub(1, 56)) + 2)
  end
  if #tip > 0 then add(b.row("  " .. tip)) end
  add(b.sep)
  add(b.row("  <Enter> to begin   <q> back"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  -- highlight | cursor markers in BEFORE (line 4) and AFTER (line 5), 0-indexed
  for _, li in ipairs({ 4, 5 }) do
    local row = lines[li + 1]
    if row then
      local pipe = row:find("|", 1, true)
      if pipe then
        api.nvim_buf_add_highlight(buf, 0, "VimmerExample", li, pipe - 1, pipe)
      end
    end
  end

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_begin()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true, silent = true })
end

local _play_ns = nil
local _play_tab = nil

function M.open_play(room, game_state, on_win, on_death)
  M._close_play()  -- clean up any previous session
  local target_lines = vim.split(room.target_text, "\n")
  local start_lines = vim.split(room.start_text, "\n")

  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
  api.nvim_buf_set_option(target_buf, "modifiable", false)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(play_buf, 0, -1, false, start_lines)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")

  vim.cmd("tabnew")
  _play_tab = api.nvim_get_current_tabpage()
  local top_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(top_win, target_buf)

  vim.cmd("belowright split")
  local play_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(play_win, play_buf)
  api.nvim_set_current_win(play_win)

  vim.wo[top_win].winbar  = "%#VimmerCleared# ── TARGET ──%*"
  vim.wo[play_win].winbar = "%#VimmerTierWarrior# ── EDIT HERE ──%*"

  local function update_hud()
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    local hp_grp = require("the-vimmer.highlights").hp_group(game_state.hp)
    vim.wo[play_win].statusline = string.format(
      " %%#%s#HP [%s] %d%%*  |  Streak %d  |  %s",
      hp_grp, hp_bar, game_state.hp, game_state.streak, room.command
    )
  end

  update_hud()

  _play_ns = api.nvim_create_namespace("the-vimmer-keys")
  local ns = _play_ns  -- capture local copy

  vim.on_key(function(key)
    if not api.nvim_win_is_valid(play_win) then
      vim.on_key(nil, ns)
      return
    end
    if api.nvim_get_current_win() ~= play_win then return end

    game_state:register_key(key)
    update_hud()

    if game_state:is_dead() then
      vim.on_key(nil, ns)
      vim.schedule(function() flash(play_buf, "VimmerDeath", on_death) end)
      return
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(play_buf) then return end
      local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
      local target = table.concat(target_lines, "\n")
      if vim.trim(current) == vim.trim(target) then
        vim.on_key(nil, ns)
        flash(play_buf, "VimmerWin", function() on_win(game_state.hp) end)
      end
    end)
  end, ns)
end

function M._close_play()
  if _play_ns then
    vim.on_key(nil, _play_ns)
    _play_ns = nil
  end
  if _play_tab and api.nvim_tabpage_is_valid(_play_tab) then
    pcall(function()
      local tab = _play_tab
      _play_tab = nil
      vim.cmd(api.nvim_tabpage_get_number(tab) .. "tabclose")
    end)
  end
end

function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue)
  local width = 60
  local b = make_border(width)
  local all_lines = {}
  local hls = {}

  local function add(content, group)
    all_lines[#all_lines+1] = content
    if group then hls[#hls+1] = { group, #all_lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("  ROOM CLEARED!"), "VimmerWin")
  add(b.sep)
  add(b.row(string.format("  XP Earned:     +%d", xp_earned)), "VimmerXP")
  add(b.row(string.format("  HP Remaining:  %d / 100", hp_remaining)), "VimmerTitle")
  add(b.row(string.format("  Streak:        %d", streak)), "VimmerTierWarrior")

  if unlocked_tier then
    local tier_name = unlocked_tier:lower()
    local tier_grp = ({ warrior = "VimmerTierWarrior", ninja = "VimmerTierNinja" })[tier_name]
      or "VimmerTierBeginner"
    add(b.sep)
    add(b.row("  NEW TIER UNLOCKED:"), "VimmerTitle")
    add(b.row("  " .. unlocked_tier), tier_grp)
  end

  add(b.sep)
  add(b.row("  <Enter> next room   <q> map"))
  add(b.bot)

  local empty = {}
  for _ = 1, #all_lines do empty[#empty+1] = "" end
  local buf, win = open_float(empty, width)

  local revealed = 0

  local function reveal_next()
    if not api.nvim_buf_is_valid(buf) then return end
    revealed = revealed + 1
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, revealed - 1, revealed, false, { all_lines[revealed] })
    api.nvim_buf_set_option(buf, "modifiable", false)
    for _, h in ipairs(hls) do
      if h[2] == revealed - 1 then
        api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
      end
    end
    if revealed < #all_lines then
      vim.defer_fn(reveal_next, 80)
    else
      vim.keymap.set("n", "<CR>", function()
        api.nvim_win_close(win, true)
        on_continue(false)
      end, { buffer = buf, nowait = true, silent = true })
      vim.keymap.set("n", "q", function()
        api.nvim_win_close(win, true)
        on_continue(true)
      end, { buffer = buf, nowait = true, silent = true })
    end
  end

  vim.defer_fn(reveal_next, 80)
end

function M.open_death(room, on_retry, on_map)
  local width = 40
  local b = make_border(width)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("        YOU DIED"), "VimmerDeath")
  add(b.sep)
  add(b.row("  HP reached zero"))
  add(b.row("  Streak lost"))
  add(b.sep)
  add(b.row("  <Enter> retry   <q> map"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_retry()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
    on_map()
  end, { buffer = buf, nowait = true, silent = true })
end

return M
