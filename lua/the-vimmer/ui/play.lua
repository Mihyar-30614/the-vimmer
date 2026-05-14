local M = {}
local api = vim.api
local float = require("the-vimmer.ui.float")

-- Module-level play state. Only one play session can be active at a time.
local _play_ns = nil
local _play_tab = nil
local _timer_handle = nil

local function show_phase_banner(win, phase_num, callback)
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

-- Apply plugin-isolation settings to a scratch buffer used for room play.
-- Sets buftype, disables common plugin behaviors, and detaches LSP clients.
local function apply_buffer_hygiene(buf)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_option(buf, "undolevels", 1000)
  for _, flag in ipairs({
    "minipairs_disable",
    "autopairs_disable",
    "copilot_enabled",
    "copilot_disable",
    "ai_enabled",
  }) do
    pcall(api.nvim_buf_set_var, buf, flag, flag == "copilot_enabled" and 0 or 1)
  end
  if vim.lsp and vim.lsp.get_clients then
    local ok, clients = pcall(vim.lsp.get_clients, { bufnr = buf })
    if ok and type(clients) == "table" then
      for _, client in ipairs(clients) do
        pcall(vim.lsp.buf_detach_client, buf, client.id)
      end
    end
  end
end

function M.open_play(room, game_state, on_win, on_death)
  M._close_play()
  local hl = require("the-vimmer.highlights")
  local initial_time = room.time_limit
  local HUD_W = 24
  local _hud_ns = api.nvim_create_namespace("the-vimmer-hud")
  local hud_feedback_line = nil

  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")
  apply_buffer_hygiene(target_buf)

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")
  apply_buffer_hygiene(play_buf)

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

    if hud_feedback_line then
      lines[#lines + 1] = " " .. hud_feedback_line
      hls[#hls + 1] = { "VimmerDeath", #lines - 1, 1, -1 }
      lines[#lines + 1] = ""
    end

    if game_state.timer_remaining then
      local mins = math.floor(game_state.timer_remaining / 60)
      local secs = game_state.timer_remaining % 60
      local t_grp = hl.timer_group(game_state.timer_remaining, initial_time)
      lines[#lines+1] = string.format(" ⏱  %d:%02d", mins, secs)
      hls[#hls+1] = { t_grp, #lines - 1, 1, -1 }
      if initial_time and game_state.timer_remaining <= math.max(5, math.floor(initial_time * 0.15)) then
        lines[#lines+1] = " HURRY — time low!"
        hls[#hls+1] = { "VimmerTimerDanger", #lines - 1, 1, -1 }
      end
      lines[#lines+1] = ""
    end

    lines[#lines+1] = string.format(" Streak  %d", game_state.streak)

    do
      local used = game_state.keystrokes_used or 0
      local budget = game_state.keystrokes_budget or 0
      local over = used > budget
      lines[#lines+1] = string.format(" Keys %d / %d", used, budget)
      hls[#hls+1] = { over and "VimmerDamage" or "VimmerTitle", #lines - 1, 1, -1 }
      if over then
        lines[#lines+1] = " OVER BUDGET — HP draining"
        hls[#hls+1] = { "VimmerTimerDanger", #lines - 1, 1, -1 }
      end
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

  local function hud_pulse_feedback(msg)
    hud_feedback_line = msg
    update_hud()
    local saved = msg
    vim.defer_fn(function()
      if hud_feedback_line == saved then
        hud_feedback_line = nil
        update_hud()
      end
    end, 950)
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
        vim.cmd("stopinsert")
        float.multi_flash(play_buf, {
          { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
        }, on_death)
      end
    end))
  end

  local function start_phase(phase_data)
    local rooms = require("the-vimmer.rooms")
    local view = rooms.phase_view(phase_data)
    local target_lines = vim.split(view.target_text, "\n")

    api.nvim_buf_set_option(target_buf, "modifiable", true)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
    api.nvim_buf_set_option(target_buf, "modifiable", false)

    api.nvim_buf_set_lines(play_buf, 0, -1, false, vim.split(view.start_text, "\n"))

    local bo = view.bo or room.bo
    if type(bo) == "table" then
      for k, v in pairs(bo) do
        vim.bo[play_buf][k] = v
      end
    end

    if view.filetype ~= "" then
      vim.bo[play_buf].filetype = view.filetype
      vim.bo[target_buf].filetype = view.filetype
      vim.schedule(function()
        if api.nvim_buf_is_valid(play_buf) then apply_buffer_hygiene(play_buf) end
        if api.nvim_buf_is_valid(target_buf) then apply_buffer_hygiene(target_buf) end
      end)
    end

    pcall(api.nvim_win_set_cursor, play_win, { view.cursor_start.row, view.cursor_start.col - 1 })

    local ns = api.nvim_create_namespace("the-vimmer-keys-" .. tostring(game_state.boss_phase))
    _play_ns = ns

    vim.on_key(function(key)
      if not api.nvim_win_is_valid(play_win) then
        vim.on_key(nil, ns); return
      end
      if api.nvim_get_current_win() ~= play_win then return end

      local hp_before = game_state.hp
      game_state:register_key(key)
      local lost_hp = game_state.hp < hp_before
      update_hud()

      if lost_hp then
        hud_pulse_feedback(string.format(
          "-%d HP  (over budget)", hp_before - game_state.hp))
        float.flash(play_buf, "VimmerDamage", 80)
      end

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.cmd("stopinsert")
        vim.schedule(function()
          float.multi_flash(play_buf, {
            { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
          }, on_death)
        end)
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
            float.multi_flash(play_buf, {
              { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 }
            }, on_win)
          else
            float.multi_flash(play_buf, {
              { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 }
            }, function()
              game_state:advance_boss_phase()
              local next_phase = game_state.boss_phase
              show_phase_banner(play_win, next_phase, function()
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

return M
