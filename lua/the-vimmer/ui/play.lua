local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float = require("the-vimmer.ui.float")
local anim = require("the-vimmer.ui.anim")
local icons = require("the-vimmer.ui.icons")

-- Module-level play state. Only one play session can be active at a time.
local _play_ns = nil
local _play_tab = nil
local _timer_handle = nil

-- Shared full-buffer flash sequences (group, duration_ms per step).
local WIN_FLASH = { { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 } }
local DEATH_FLASH = { { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 } }

local function show_phase_banner(win, phase_num, total, callback)
  local label = common.game_section(string.format("PHASE %d / %d", phase_num, total), 28)
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
  end, 900)
end

-- Apply plugin-isolation settings to a scratch buffer used for room play.
-- Sets buftype, disables common plugin behaviors, and detaches LSP clients.
local function apply_buffer_hygiene(buf)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_option(buf, "undolevels", 1000)

  -- Pin a deterministic indent regime so room solutions don't depend on the
  -- user's ambient config. `autoindent` copies the previous line's literal
  -- indent on `o`/`O`/<CR>; clearing `indentexpr` and the C/smart-indent flags
  -- stops filetype indent scripts from computing a different (config-dependent)
  -- indent. Without this, e.g. `o` produces no indent under `filetype indent
  -- off`, so a perfectly-played insert room can never match its target_text.
  api.nvim_buf_set_option(buf, "autoindent", true)
  api.nvim_buf_set_option(buf, "smartindent", false)
  api.nvim_buf_set_option(buf, "cindent", false)
  api.nvim_buf_set_option(buf, "indentexpr", "")
  api.nvim_buf_set_option(buf, "expandtab", true)
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
  local HUD_W = 28
  local _hud_ns = api.nvim_create_namespace("the-vimmer-hud")
  local hud_feedback_line = nil
  -- HP shown in the HUD lags the real value so a hit drains the bar smoothly.
  local display_hp = game_state.hp
  local hp_anim = nil

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
  vim.wo[hud_win].winbar         = "%#VimmerPanel# " .. icons.get("hud") .. "  COMBAT HUD%*"

  api.nvim_set_current_win(left_win)
  local top_win = left_win
  api.nvim_win_set_buf(top_win, target_buf)

  vim.cmd("belowright split")
  local play_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(play_win, play_buf)
  api.nvim_set_current_win(play_win)

  vim.wo[top_win].winbar  = "%#VimmerPanel# " .. icons.get("target") .. "  TARGET%*"
  vim.wo[play_win].winbar = "%#VimmerPanel# " .. icons.get("edit") .. "  EDIT%*"

  local pu_icons_map = {
    hp_restore = icons.get("heart"),
    freeze_timer = icons.get("freeze"),
    double_xp = icons.get("xp"),
  }

  local hud_icons = {
    hp = icons.get("hp"), timer = icons.get("timer"),
    streak = icons.get("streak"), keys = icons.get("keys"),
    phase = icons.get("phase"), warn = icons.get("warn"),
  }

  local function update_hud()
    if not api.nvim_buf_is_valid(hud_buf) then return end

    local rooms_mod = require("the-vimmer.rooms")
    local current_phase = room.is_boss and (room.phases[game_state.boss_phase] or {}) or room
    local goal_view = rooms_mod.phase_view(current_phase).goal

    local pu_str = ""
    for _, pu in ipairs(game_state.power_ups) do
      pu_str = pu_str .. (pu_icons_map[pu.type] or "?")
    end

    local timer_low = false
    if game_state.timer_remaining and initial_time then
      timer_low = game_state.timer_remaining <= math.max(5, math.floor(initial_time * 0.15))
    end

    local lines, hls = common.build_play_hud({
      width = HUD_W,
      icons = hud_icons,
      display_hp = display_hp,
      hp_bar = common.bracket_bar(display_hp, 100, 10, "█", "░"),
      hp_group = hl.hp_group(display_hp),
      feedback = hud_feedback_line,
      timer_remaining = game_state.timer_remaining,
      initial_time = initial_time,
      timer_bar = initial_time and common.bracket_bar(
        game_state.timer_remaining or 0, initial_time, 8, "█", "░") or nil,
      timer_group = initial_time and hl.timer_group(
        game_state.timer_remaining, initial_time) or nil,
      timer_low = timer_low,
      streak = game_state.streak,
      keys_used = game_state.keystrokes_used,
      keys_budget = game_state.keystrokes_budget,
      boss_phase = room.is_boss and game_state.boss_phase or nil,
      boss_total = room.is_boss and game_state.boss_total_phases or nil,
      power_up_str = pu_str ~= "" and pu_str or nil,
      command = room.command,
      goal = goal_view,
    })

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
      if dead then display_hp = game_state.hp end
      update_hud()
      if dead then
        if _timer_handle then _timer_handle:stop() end
        vim.cmd("stopinsert")
        float.multi_flash(play_buf, DEATH_FLASH, on_death)
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

    local wo = view.wo or room.wo
    if type(wo) == "table" then
      for k, v in pairs(wo) do
        vim.wo[play_win][k] = v
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

    vim.on_key(function(key, typed)
      if not api.nvim_win_is_valid(play_win) then
        vim.on_key(nil, ns); return
      end
      if api.nvim_get_current_win() ~= play_win then return end

      -- `key` is post-mapping (a mapping can expand to many keys the user never
      -- pressed); `typed` is the raw input. Record/score by `typed`. Empty
      -- `typed` means the key came from a mapping/feedkeys, not the user — skip.
      key = (typed ~= nil and typed ~= "") and typed or key
      if typed == "" then return end

      local hp_before = game_state.hp
      game_state:register_key(key)
      local lost_hp = game_state.hp < hp_before

      if lost_hp then
        if hp_anim then hp_anim.cancel(); hp_anim = nil end
        if game_state.hp <= 0 then
          display_hp = game_state.hp
        else
          local from = display_hp
          hp_anim = anim.count_up({
            from = from, to = game_state.hp, duration_ms = 280, fps = 30,
            on_value = function(v) display_hp = v; update_hud() end,
          })
        end
        hud_pulse_feedback(string.format(
          "-%d HP (%s)", hp_before - game_state.hp, common.format_key(key)))
        float.flash(play_buf, "VimmerDamage", 80)
      end
      update_hud()

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.cmd("stopinsert")
        vim.schedule(function()
          float.multi_flash(play_buf, DEATH_FLASH, on_death)
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
            float.multi_flash(play_buf, WIN_FLASH, on_win)
          else
            float.multi_flash(play_buf, WIN_FLASH, function()
              game_state:advance_boss_phase()
              local next_phase = game_state.boss_phase
              show_phase_banner(play_win, next_phase, game_state.boss_total_phases, function()
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
