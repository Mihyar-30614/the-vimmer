local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float = require("the-vimmer.ui.float")
local anim = require("the-vimmer.ui.anim")
local icons = require("the-vimmer.ui.icons")

-- A victory leads with what improved. Detailed key analysis is a separate view.
function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue, opts)
  opts = opts or {}
  local rs = opts.run_stats or {}
  local width = common.pick_float_width(float.FLOAT_RESULTS_W)
  local buf, win
  local selected, display_xp = 1, xp_earned
  local counter
  local selected_line
  local choices = { "hp_restore", "freeze_timer", "double_xp" }
  local choose = opts.fast_clear and opts.on_powerup ~= nil
  local function build()
    local b = common.make_border(width)
    local lines, hls = {}, {}
    local function add(text, group)
      lines[#lines + 1] = text
      if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
    end
    local function prose(text, group)
      common.add_wrapped_prefixed(add, b.row, "  ", text, width, group)
    end
    add(b.top)
    add(b.row(common.game_section(opts.practice and "PRACTICE COMPLETE" or (opts.is_boss and "BOSS VICTORY" or "VICTORY"), width)), "VimmerWin")
    add(b.sep)
    if opts.room then prose(common.clean_title(opts.room.title), "VimmerTitle") end
    local used = rs.keystrokes_used or 0
    local saved = opts.prev_best_keys and opts.prev_best_keys - used or 0
    if opts.practice then
      prose("You have room to experiment. Try a ranked run when you feel ready.", "VimmerTeachTip")
    elseif saved > 0 then
      prose(string.format("New key best: %d fewer keys than your previous best!", saved), "VimmerCleared")
    elseif rs.optimal_count and used <= rs.optimal_count then
      prose("Efficient path cleared. Every key counted.", "VimmerCleared")
    elseif opts.first_clear then
      prose("New skill unlocked in your muscle memory.", "VimmerCleared")
    else
      prose("Another room cleared. Keep building your rhythm.", "VimmerCleared")
    end
    if (opts.mastery_count or 0) >= 3 and not opts.practice then
      prose("MASTERED: three or more efficient clears", "VimmerBadge")
    end
    if rs.new_personal_best and not opts.practice then
      prose("Personal best: " .. common.fmt_run_seconds(rs.seconds or 0), "VimmerXP")
    end
    add(b.sep)
    if not opts.practice then
      prose(string.format("+%d XP   %s x%d", display_xp, icons.get("streak"), streak), "VimmerXP")
      local total = opts.total_xp or xp_earned
      prose(string.format("LV %d  %s  %d XP to next level", common.game_level(total), common.xp_bar(total, 8), 120 - total % 120), "VimmerXP")
      if common.game_level(total) > common.game_level(opts.previous_xp or total) then prose("LEVEL UP!", "VimmerBadge") end
    end
    prose(string.format("%d keys used  /  %d efficient   HP %d/100", used, rs.optimal_count or rs.keystrokes_budget or 0, hp_remaining), "VimmerTeachTip")
    if rs.optimal_count and used > rs.optimal_count then
      prose(rs.efficiency_hint or "Press D to compare your keys with the efficient path.", "VimmerTeachTip")
    end
    if opts.is_daily then prose("Daily challenge cleared", "VimmerBadge") end
    if unlocked_tier then prose("NEW PATH OPEN: " .. unlocked_tier, "VimmerBoss") end
    if choose then
      add(b.sep)
      prose("Fast clear! Choose a reward for your next room.", "VimmerBadge")
      for i, title in ipairs({ "Reserve potion: +30 HP after damage", "Freeze: +5 seconds with Tab", "Double XP on your next clear" }) do
        add(b.row(common.game_menu_row(selected == i, tostring(i), title, width - 10)), selected == i and "VimmerSelected" or "VimmerTeachTip")
        if selected == i then selected_line = #lines end
      end
    end
    add(b.sep)
    add(b.row(common.game_footer({ { "RET", choose and "pick" or (opts.practice and "again" or "next") }, { "D", "keys" }, { "Q", "map" } })), "VimmerTeachFoot")
    add(b.bot)
    return lines, hls
  end
  local function render()
    if not buf or not api.nvim_buf_is_valid(buf) then return end
    local lines, hls = build()
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    api.nvim_buf_clear_namespace(buf, 0, 0, -1)
    float.resize_float(buf, width)
    float.apply_hl(buf, hls)
    if choose and selected_line then float.ensure_visible(win, selected_line) end
  end
  local lines, hls = build()
  buf, win = float.open_float(lines, width, { on_resize = function()
    width = common.pick_float_width(float.FLOAT_RESULTS_W); render()
  end })
  float.apply_hl(buf, hls)
  if choose and selected_line then float.ensure_visible(win, selected_line) end
  local function settle()
    if counter then counter.cancel(); counter = nil end
    display_xp = xp_earned
    render()
  end
  local finished = false
  local function continue(go_map)
    if finished then return end
    finished = true
    if counter then counter.cancel() end
    if choose and not go_map then opts.on_powerup(choices[selected]) end
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    on_continue(go_map)
  end
  local function bind(key, fn) vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true }) end
  bind("<CR>", function() continue(false) end)
  bind("q", function() continue(true) end)
  bind("<Esc>", function() continue(true) end)
  bind("<Space>", settle)
  if choose then
    bind("j", function() selected = math.min(3, selected + 1); render() end)
    bind("k", function() selected = math.max(1, selected - 1); render() end)
    for i = 1, 3 do bind(tostring(i), function() selected = i; continue(false) end) end
  end
  bind("d", function()
    settle()
    local dw = common.pick_float_width(78)
    local b = common.make_border(dw)
    local detail = { b.top, b.row(common.game_section("KEY ANALYSIS", dw)), b.sep }
    local function add(text)
      for _, ln in ipairs(common.wrap_teach_text(text, math.max(4, dw - 6))) do detail[#detail + 1] = b.row("  " .. ln) end
    end
    add(string.format("Key budget %d / %d over budget / efficiency x%.2f", rs.keystrokes_budget or 0, rs.keystrokes_over_budget or 0, rs.efficiency_mult or 1))
    if rs.seconds then add("Time: " .. common.fmt_run_seconds(rs.seconds)) end
    if rs.keystroke_log then
      add("Your keys:")
      local parts = {}
      for _, key in ipairs(rs.keystroke_log) do parts[#parts + 1] = common.format_key(key) end
      add(table.concat(parts, " "))
    end
    add("Efficient path:")
    local optimal_room = rs.optimal_tokens and { optimal_keystrokes = rs.optimal_tokens } or opts.room or {}
    for _, ln in ipairs(common.build_optimal_lines(optimal_room, math.max(4, dw - 4))) do add(vim.trim(ln)) end
    detail[#detail + 1] = b.sep
    detail[#detail + 1] = b.row("  [J/K] scroll  [Q/ESC] close")
    detail[#detail + 1] = b.bot
    local db, dwin = float.open_float(detail, dw)
    vim.keymap.set("n", "q", function() if api.nvim_win_is_valid(dwin) then api.nvim_win_close(dwin, true) end end, { buffer = db, silent = true })
  end)
  -- Animate only the reward number; every action remains available.
  if xp_earned > 0 and not opts.practice and not common.reduced_motion() then
    display_xp = 0
    render()
    counter = anim.count_up({ from = 0, to = xp_earned, duration_ms = 350, on_value = function(value)
      if finished then return end
      display_xp = value; render()
    end })
  end
  return buf, win
end

return M
