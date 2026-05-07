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

local function flash(buf, group, duration, callback)
  local n = api.nvim_buf_line_count(buf)
  for i = 0, n - 1 do
    api.nvim_buf_add_highlight(buf, _flash_ns, group, i, 0, -1)
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, _flash_ns, 0, -1)
    end
    if callback then callback() end
  end, duration or 100)
end

local function multi_flash(buf, steps, callback)
  local function run(i)
    if i > #steps then
      if callback then callback() end
      return
    end
    local group, duration = steps[i][1], steps[i][2]
    if group and api.nvim_buf_is_valid(buf) then
      local n = api.nvim_buf_line_count(buf)
      for row = 0, n - 1 do
        api.nvim_buf_add_highlight(buf, _flash_ns, group, row, 0, -1)
      end
    end
    vim.defer_fn(function()
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_clear_namespace(buf, _flash_ns, 0, -1)
      end
      run(i + 1)
    end, duration)
  end
  run(1)
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
  local tier_prereq = { warrior = "complete boss first", ninja = "complete boss first" }
  local tiers = { "beginner", "warrior", "ninja" }

  add(b.top)
  add(b.row(string.format("  THE VIMMER                     XP:%-5d %s",
    progress_data.total_xp, bar)), "VimmerTitle")
  add(b.sep)

  for ti, tier in ipairs(tiers) do
    local all_tier_rooms = rooms_by_tier[tier] or {}
    local tier_rooms = {}
    local boss_room = nil
    for _, room in ipairs(all_tier_rooms) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms+1] = room end
    end

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
      if boss_room then
        local boss_cleared = progress_data.cleared[boss_room.id]
        local boss_unlocked = progress.is_boss_unlocked(tier, progress_data.cleared, #tier_rooms)
        if boss_cleared then
          add(b.row("   ✓ ⚔  " .. boss_room.title:sub(1, 42)), "VimmerCleared")
        elseif boss_unlocked then
          add(b.row("   ► ⚔  " .. boss_room.title:sub(1, 42)), "VimmerBoss")
          selectable[#selectable+1] = { line = #lines, room = boss_room }
        else
          add(b.row("     ⚔  " .. boss_room.title:sub(1, 42) .. "  [80% first]"), "VimmerLocked")
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
  if room.is_boss then
    add(b.row("  ⚔ BOSS: " .. room.command:gsub("\n", " ↵ ")), "VimmerBoss")
    add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      add(b.row(string.format("  PHASE %d: %s", i, phase.tip or "")), "VimmerCommand")
      add(b.row("  BEFORE: " .. phase.start_text:gsub("\n", " ↵ ")), "VimmerLocked")
      add(b.row("  AFTER:  " .. phase.target_text:gsub("\n", " ↵ ")), "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
  else
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
  end
  add(b.sep)
  add(b.row("  <Enter> to begin   <q> back"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  if not room.is_boss then
    for _, li in ipairs({ 4, 5 }) do
      local row = lines[li + 1]
      if row then
        local pipe = row:find("|", 1, true)
        if pipe then
          api.nvim_buf_add_highlight(buf, 0, "VimmerExample", li, pipe - 1, pipe)
        end
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
local _timer_handle = nil

function M._show_phase_banner(win, phase_num, callback)
  local label = string.format("  ── PHASE %d ──  ", phase_num)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, { label })
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  local win_width = api.nvim_win_get_width(win)
  local col = math.max(0, math.floor((win_width - #label) / 2))
  local banner_win = api.nvim_open_win(buf, false, {
    relative = "win", win = win,
    row = 2, col = col,
    width = #label, height = 1,
    style = "minimal", border = "none",
  })
  api.nvim_buf_add_highlight(buf, 0, "VimmerPhase", 0, 0, -1)
  vim.defer_fn(function()
    if api.nvim_win_is_valid(banner_win) then
      api.nvim_win_close(banner_win, true)
    end
    callback()
  end, 800)
end

function M.open_play(room, game_state, on_win, on_death)
  M._close_play()
  local hl = require("the-vimmer.highlights")
  local initial_time = room.time_limit
  local HUD_W = 20
  local _hud_ns = api.nvim_create_namespace("the-vimmer-hud")

  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")

  local hud_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(hud_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(hud_buf, "modifiable", false)

  vim.cmd("tabnew")
  _play_tab = api.nvim_get_current_tabpage()
  local left_win = api.nvim_get_current_win()

  vim.cmd("botright vsplit")
  local hud_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(hud_win, hud_buf)
  api.nvim_win_set_width(hud_win, HUD_W)
  vim.wo[hud_win].winfixwidth    = true
  vim.wo[hud_win].number         = false
  vim.wo[hud_win].relativenumber = false
  vim.wo[hud_win].signcolumn     = "no"
  vim.wo[hud_win].wrap           = false
  vim.wo[hud_win].cursorline     = false
  vim.wo[hud_win].statusline     = " "
  vim.wo[hud_win].winbar         = "%#VimmerTitle# ── STATUS ──%*"

  api.nvim_set_current_win(left_win)
  local top_win = left_win
  api.nvim_win_set_buf(top_win, target_buf)

  vim.cmd("belowright split")
  local play_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(play_win, play_buf)
  api.nvim_set_current_win(play_win)

  vim.wo[top_win].winbar  = "%#VimmerCleared# ── TARGET ──%*"
  vim.wo[play_win].winbar = "%#VimmerTierWarrior# ── EDIT HERE ──%*"

  local pu_icons_map = { hp_restore = "♥", freeze_timer = "❄", double_xp = "★" }

  local function update_hud()
    if not api.nvim_buf_is_valid(hud_buf) then return end
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    local hp_grp = hl.hp_group(game_state.hp)

    local lines = { "", " HP", " " .. hp_bar, string.format(" %d / 100", game_state.hp), "" }
    local hls = {
      { hp_grp, 2, 1, -1 },
      { hp_grp, 3, 1, -1 },
    }

    if game_state.timer_remaining then
      local mins = math.floor(game_state.timer_remaining / 60)
      local secs = game_state.timer_remaining % 60
      local t_grp = hl.timer_group(game_state.timer_remaining, initial_time)
      lines[#lines+1] = string.format(" ⏱  %d:%02d", mins, secs)
      hls[#hls+1] = { t_grp, #lines - 1, 1, -1 }
      lines[#lines+1] = ""
    end

    lines[#lines+1] = string.format(" Streak  %d", game_state.streak)

    if game_state.combo_mult > 1 then
      lines[#lines+1] = string.format(" Combo  x%d", game_state.combo_mult)
      hls[#hls+1] = { "VimmerPhase", #lines - 1, 1, -1 }
    end

    local pu_str = ""
    for _, pu in ipairs(game_state.power_ups) do
      pu_str = pu_str .. (pu_icons_map[pu.type] or "?")
    end
    if pu_str ~= "" then
      lines[#lines+1] = ""
      lines[#lines+1] = " " .. pu_str
    end

    lines[#lines+1] = ""
    lines[#lines+1] = " " .. string.rep("─", HUD_W - 2)
    lines[#lines+1] = ""

    local cmd = " " .. room.command
    local max_w = HUD_W - 1
    while #cmd > max_w do
      lines[#lines+1] = cmd:sub(1, max_w)
      cmd = " " .. cmd:sub(max_w + 1)
    end
    lines[#lines+1] = cmd

    api.nvim_buf_set_option(hud_buf, "modifiable", true)
    api.nvim_buf_set_lines(hud_buf, 0, -1, false, lines)
    api.nvim_buf_clear_namespace(hud_buf, _hud_ns, 0, -1)
    for _, h in ipairs(hls) do
      api.nvim_buf_add_highlight(hud_buf, _hud_ns, h[1], h[2], h[3], h[4])
    end
    api.nvim_buf_set_option(hud_buf, "modifiable", false)
  end

  local function start_timer()
    if not game_state.timer_remaining then return end
    _timer_handle = vim.loop.new_timer()
    _timer_handle:start(1000, 1000, vim.schedule_wrap(function()
      if game_state.state ~= "playing" then
        if _timer_handle then _timer_handle:stop() end
        return
      end
      local dead = game_state:tick_timer()
      update_hud()
      if dead then
        if _timer_handle then _timer_handle:stop() end
        flash(play_buf, "VimmerDeath", on_death)
      end
    end))
  end

  local function start_phase(phase_data)
    local target_lines = vim.split(phase_data.target_text, "\n")

    api.nvim_buf_set_option(target_buf, "modifiable", true)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
    api.nvim_buf_set_option(target_buf, "modifiable", false)

    api.nvim_buf_set_lines(play_buf, 0, -1, false, vim.split(phase_data.start_text, "\n"))

    local ns = api.nvim_create_namespace("the-vimmer-keys-" .. tostring(game_state.boss_phase))
    _play_ns = ns

    vim.on_key(function(key)
      if not api.nvim_win_is_valid(play_win) then
        vim.on_key(nil, ns); return
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
        if _play_ns ~= ns then return end
        local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
        local target = table.concat(target_lines, "\n")
        if vim.trim(current) == vim.trim(target) then
          vim.on_key(nil, ns)
          _play_ns = nil
          vim.cmd("stopinsert")
          local is_last = not room.is_boss or game_state.boss_phase >= game_state.boss_total_phases
          if is_last then
            flash(play_buf, "VimmerWin", function() on_win() end)
          else
            flash(play_buf, "VimmerWin", function()
              game_state:advance_boss_phase()
              local next_phase = game_state.boss_phase
              M._show_phase_banner(play_win, next_phase, function()
                start_phase(room.phases[next_phase])
              end)
            end)
          end
        end
      end)
    end, ns)

    vim.keymap.set("n", "<Tab>", function()
      if game_state:activate_freeze(5) then update_hud() end
    end, { buffer = play_buf, nowait = true, silent = true })
  end

  update_hud()
  local first_phase = room.is_boss and room.phases[1] or room
  start_phase(first_phase)
  start_timer()
end

function M._close_play()
  if _play_ns then
    vim.on_key(nil, _play_ns)
    _play_ns = nil
  end
  if _timer_handle then
    _timer_handle:stop()
    _timer_handle:close()
    _timer_handle = nil
  end
  if _play_tab and api.nvim_tabpage_is_valid(_play_tab) then
    pcall(function()
      local tab = _play_tab
      _play_tab = nil
      vim.cmd(api.nvim_tabpage_get_number(tab) .. "tabclose")
    end)
  end
end

function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue, opts)
  opts = opts or {}
  local is_boss = opts.is_boss
  local fast_clear = opts.fast_clear
  local on_powerup = opts.on_powerup

  local width = 60
  local b = make_border(width)
  local all_lines = {}
  local hls = {}

  local function add(content, group)
    all_lines[#all_lines+1] = content
    if group then hls[#hls+1] = { group, #all_lines - 1, 0, -1 } end
  end

  add(b.top)
  if is_boss then
    add(b.row("  ⚔ BOSS CLEARED!"), "VimmerBoss")
  else
    add(b.row("  ROOM CLEARED!"), "VimmerWin")
  end
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

  local powerup_section_start = nil
  if fast_clear and on_powerup then
    add(b.sep)
    add(b.row("  ⚡ FAST CLEAR! Choose a power-up:"), "VimmerXP")
    powerup_section_start = #all_lines + 1
    add(b.row("    ♥  +30 HP next room"))
    add(b.row("    ❄  Freeze timer 5s"))
    add(b.row("    ★  Double XP next room"))
  end

  add(b.sep)
  local footer_line = #all_lines + 1
  if fast_clear and on_powerup then
    add(b.row("  j/k choose   <Enter> pick"))
  else
    add(b.row("  <Enter> next room   <q> map"))
  end
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
      if fast_clear and on_powerup and powerup_section_start then
        local pu_types = { "hp_restore", "freeze_timer", "double_xp" }
        local sel_ns = api.nvim_create_namespace("the-vimmer-pu-sel")
        local cur = 1
        local function update_pu_sel()
          api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
          local line = powerup_section_start + cur - 2
          api.nvim_buf_add_highlight(buf, sel_ns, "VimmerSelected", line, 0, -1)
        end
        update_pu_sel()
        vim.keymap.set("n", "j", function()
          cur = math.min(cur + 1, 3); update_pu_sel()
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "k", function()
          cur = math.max(cur - 1, 1); update_pu_sel()
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "<CR>", function()
          on_powerup(pu_types[cur])
          api.nvim_buf_set_option(buf, "modifiable", true)
          api.nvim_buf_set_lines(buf, footer_line - 1, footer_line, false,
            { b.row("  <Enter> next room   <q> map") })
          api.nvim_buf_set_option(buf, "modifiable", false)
          api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
          vim.keymap.del("n", "j", { buffer = buf })
          vim.keymap.del("n", "k", { buffer = buf })
          vim.keymap.set("n", "<CR>", function()
            api.nvim_win_close(win, true); on_continue(false)
          end, { buffer = buf, nowait = true, silent = true })
          vim.keymap.set("n", "q", function()
            api.nvim_win_close(win, true); on_continue(true)
          end, { buffer = buf, nowait = true, silent = true })
        end, { buffer = buf, nowait = true, silent = true })
      else
        vim.keymap.set("n", "<CR>", function()
          api.nvim_win_close(win, true); on_continue(false)
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "q", function()
          api.nvim_win_close(win, true); on_continue(true)
        end, { buffer = buf, nowait = true, silent = true })
      end
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
