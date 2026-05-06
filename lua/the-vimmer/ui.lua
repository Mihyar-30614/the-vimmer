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

  local width = 50
  local b = make_border(width)
  local bar = xp_bar(progress_data.total_xp, 6)
  local lines = {}
  local selectable = {}

  lines[#lines+1] = b.top
  lines[#lines+1] = b.row(string.format("  THE VIMMER           XP:%-5d %s",
    progress_data.total_xp, bar))
  lines[#lines+1] = b.sep

  local tiers = { "beginner", "warrior", "ninja" }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA" }
  local tier_prereq = { warrior = "complete 80% of beginner", ninja = "complete 80% of warrior" }

  for ti, tier in ipairs(tiers) do
    local tier_rooms = rooms_by_tier[tier] or {}
    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      lines[#lines+1] = b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or ""))
    else
      lines[#lines+1] = b.row(string.format("  [%s]", tier_labels[tier]))
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, 36))
        lines[#lines+1] = b.row(label)
        if not cleared then
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
    end
    if ti < #tiers then lines[#lines+1] = b.row("") end
  end

  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  <Enter> play   j/k navigate   <q> quit")
  lines[#lines+1] = b.bot

  local buf, win = open_float(lines, width)
  local cur_idx = 1

  if selectable[1] then
    api.nvim_win_set_cursor(win, { selectable[1].line, 0 })
  end

  local function map_key(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  map_key("j", function()
    cur_idx = math.min(cur_idx + 1, #selectable)
    if selectable[cur_idx] then
      api.nvim_win_set_cursor(win, { selectable[cur_idx].line, 0 })
    end
  end)

  map_key("k", function()
    cur_idx = math.max(cur_idx - 1, 1)
    if selectable[cur_idx] then
      api.nvim_win_set_cursor(win, { selectable[cur_idx].line, 0 })
    end
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
  local width = 50
  local b = make_border(width)
  local lines = {}

  lines[#lines+1] = b.top
  lines[#lines+1] = b.row("  COMMAND: " .. room.command)
  lines[#lines+1] = b.row("  " .. room.description)
  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  BEFORE:  " .. room.before_example)
  lines[#lines+1] = b.row("  AFTER:   " .. room.after_example)
  lines[#lines+1] = b.row("")
  -- wrap usage_tip at 46 chars
  local tip = room.usage_tip
  while #tip > 46 do
    local cut = tip:sub(1, 46):match("^(.+) ")
    lines[#lines+1] = b.row("  " .. (cut or tip:sub(1, 46)))
    tip = tip:sub(#(cut or tip:sub(1, 46)) + 2)
  end
  if #tip > 0 then lines[#lines+1] = b.row("  " .. tip) end
  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  <Enter> to begin   <q> back")
  lines[#lines+1] = b.bot

  local buf, win = open_float(lines, width)

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

  local function update_hud()
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    vim.wo[play_win].statusline = string.format(
      " HP [%s] %d  |  Streak %d  |  %s",
      hp_bar, game_state.hp, game_state.streak, room.command
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
      vim.schedule(function() on_death() end)
      return
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(play_buf) then return end
      local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
      local target = table.concat(target_lines, "\n")
      if vim.trim(current) == vim.trim(target) then
        vim.on_key(nil, ns)
        on_win(game_state.hp)
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

return M
