local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local anim   = require("the-vimmer.ui.anim")

function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue, opts)
  opts = opts or {}
  local is_boss = opts.is_boss
  local fast_clear = opts.fast_clear
  local on_powerup = opts.on_powerup

  local width = common.pick_float_width(float.FLOAT_RESULTS_W)
  local b = common.make_border(width)
  local optimal_inner = math.max(32, width - 4)
  local all_lines = {}
  local hls = {}

  local function add(content, group)
    all_lines[#all_lines+1] = content
    if group then hls[#hls+1] = { group, #all_lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row(common.game_section(is_boss and "BOSS VICTORY" or "VICTORY", width)),
    is_boss and "VimmerBoss" or "VimmerWin")
  add(b.row(""))
  local burst_line_idx = #all_lines  -- 1-based; animated sparkle row
  if opts.first_clear then
    add(b.row("  First clear — new muscle memory unlocked."), "VimmerCleared")
  end
  if opts.is_daily then
    add(b.row("  Daily challenge run"), "VimmerXP")
  end
  do
    local ml = common.mutator_summary_line(opts.active_mutators or {})
    if ml then add(b.row(ml), "VimmerTimerWarn") end
  end
  add(b.sep)
  local function xp_row(v)
    return b.row(string.format("  XP  +%-4d   %s", v,
      common.bracket_bar(v, math.max(xp_earned, 1), 8, "▓", "░")))
  end
  add(xp_row(xp_earned), "VimmerXP")
  local xp_line_idx = #all_lines  -- 1-based; counts up 0 -> xp_earned
  if opts.run_stats and opts.run_stats.flawless then
    add(b.row("  Flawless sequence — +15% XP baked in."), "VimmerCleared")
  end
  add(b.row(string.format("  HP  %s  %d/100",
    common.bracket_bar(hp_remaining, 100, 10, "█", "░"), hp_remaining)), "VimmerTitle")
  add(b.row(string.format("  STREAK  🔥 x%d", streak)), "VimmerTierWarrior")
  do
    local phrase = common.streak_milestone_phrase(streak)
    if phrase then add(b.row("  " .. phrase), "VimmerXP") end
  end

  local rs = opts.run_stats
  if rs then
    local used = rs.keystrokes_used or 0
    local over = rs.keystrokes_over_budget or 0
    local budget = rs.keystrokes_budget or 0
    local mult = rs.efficiency_mult or 1
    local show_keys = used > 0
    local show_time = rs.seconds ~= nil and rs.seconds > 0
    if show_keys or show_time then
      add(b.sep)
      if show_keys then
        add(b.row(string.format(
          "  Keystrokes: %d used  ·  budget %d  ·  %d over",
          used, budget, over)), "VimmerTitle")
        add(b.row(string.format(
          "  Efficiency multiplier: x%.2f", mult)), "VimmerXP")
      end
      if show_time then
        local t = common.fmt_run_seconds(rs.seconds)
        if rs.new_personal_best then
          if rs.beaten_seconds then
            add(b.row(string.format(
              "  Personal best: %s (was %s)",
              t, common.fmt_run_seconds(rs.beaten_seconds))), "VimmerXP")
          else
            add(b.row(string.format("  Personal best: %s", t)), "VimmerXP")
          end
        elseif rs.prev_best_seconds then
          add(b.row(string.format(
            "  Time: %s  ·  room best %s",
            t, common.fmt_run_seconds(rs.prev_best_seconds))), "VimmerTitle")
        else
          add(b.row(string.format("  Time: %s", t)), "VimmerTitle")
        end
      end
    end
  end

  local diff = opts.run_stats
  local log = diff and diff.keystroke_log
  if log and #log > 0 and diff.optimal_tokens and diff.optimal_count then
    add(b.sep)
    -- "Your keys (N): ..." wrapped at optimal_inner.
    local your_parts = {}
    for _, k in ipairs(log) do your_parts[#your_parts + 1] = common.format_key(k) end
    add(b.row(string.format("  Your keys (%d):", #log)), "VimmerTitle")
    for _, ln in ipairs(common.wrap_keys(your_parts, optimal_inner)) do
      add(b.row(ln), "VimmerCommand")
    end
    -- "Optimal (M): ..." token form.
    local opt_parts = {}
    for _, k in ipairs(diff.optimal_tokens) do
      opt_parts[#opt_parts + 1] = common.format_key(k)
    end
    add(b.row(string.format("  Optimal (%d):", diff.optimal_count)), "VimmerTitle")
    for _, ln in ipairs(common.wrap_keys(opt_parts, optimal_inner)) do
      add(b.row(ln), "VimmerXP")
    end
    -- Delta + hint.
    local over = #log - diff.optimal_count
    if over > 0 then
      add(b.row(string.format("  Delta: +%d keys over optimal", over)), "VimmerDamage")
      local hint = diff.efficiency_hint
        or string.format("%d keys over optimal — see sequence above", over)
      add(b.row("  Hint: " .. hint), "VimmerXP")
    else
      add(b.row("  Matched the efficient path."), "VimmerCleared")
    end
  elseif opts.room then
    -- Fallback: no key log available, show optimal only (no regression).
    add(b.sep)
    add(b.row("  Optimal sequence:"), "VimmerTitle")
    for _, ln in ipairs(common.build_optimal_lines(opts.room, optimal_inner)) do
      add(b.row(ln), "VimmerCommand")
    end
  end

  if unlocked_tier then
    local tier_name = unlocked_tier:lower()
    local tier_grp = ({ warrior = "VimmerTierWarrior", ninja = "VimmerTierNinja", grandmaster = "VimmerTierGrandmaster" })[tier_name]
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
    add(b.row(common.game_footer({ { "J/K", "choose" }, { "ENTER", "pick" } })))
  else
    add(b.row(common.game_footer({ { "ENTER", "next" }, { "Q", "map" } })), "VimmerTeachFoot")
  end
  add(b.bot)

  local empty = {}
  for _ = 1, #all_lines do empty[#empty+1] = "" end
  local buf, win = float.open_float(empty, width)

  local revealed = 0

  local function reveal_next()
    if not api.nvim_buf_is_valid(buf) then return end
    revealed = revealed + 1
    -- The XP line is revealed at +0, then counts up to its real value.
    local animate_xp = revealed == xp_line_idx and xp_earned > 0
    local text = animate_xp and xp_row(0) or all_lines[revealed]
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, revealed - 1, revealed, false, { text })
    api.nvim_buf_set_option(buf, "modifiable", false)
    for _, h in ipairs(hls) do
      if h[2] == revealed - 1 then
        api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
      end
    end
    if animate_xp then
      anim.count_up({
        from = 0, to = xp_earned, duration_ms = 600, fps = 30,
        on_value = function(v)
          if not api.nvim_buf_is_valid(buf) then return end
          api.nvim_buf_set_option(buf, "modifiable", true)
          pcall(api.nvim_buf_set_lines, buf, xp_line_idx - 1, xp_line_idx, false, { xp_row(v) })
          api.nvim_buf_set_option(buf, "modifiable", false)
          api.nvim_buf_add_highlight(buf, 0, "VimmerXP", xp_line_idx - 1, 0, -1)
        end,
      })
    end
    if revealed == burst_line_idx then
      local frames = anim.burst_frames(6, 20)
      anim.play_frames(buf, burst_line_idx - 1, frames,
        function(f) return b.row("  " .. f) end, 70,
        function()
          if not api.nvim_buf_is_valid(buf) then return end
          api.nvim_buf_set_option(buf, "modifiable", true)
          pcall(api.nvim_buf_set_lines, buf, burst_line_idx - 1, burst_line_idx, false, { b.row("") })
          api.nvim_buf_set_option(buf, "modifiable", false)
        end)
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
            { b.row(common.game_footer({ { "ENTER", "next" }, { "Q", "map" } })) })
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

return M
