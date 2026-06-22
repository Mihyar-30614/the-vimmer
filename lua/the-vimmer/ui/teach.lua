local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
-- NOTE: do NOT top-level-require "the-vimmer.ui" — circular load.

function M.open_teach(room, flow_opts_or_cb, maybe_cb)
  local flow_opts, on_begin
  if type(flow_opts_or_cb) == "function" then
    on_begin = flow_opts_or_cb
    flow_opts = {}
  else
    flow_opts = flow_opts_or_cb or {}
    on_begin = maybe_cb
  end

  local hl = require("the-vimmer.highlights")
  local width = common.pick_float_width(float.FLOAT_TEACH_W)
  local b = common.make_border(width)
  local lines = {}
  local hls = {}
  local diff_rows = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row(common.game_section(room.is_boss and "BOSS FIGHT" or "MISSION BRIEF", width)),
    "VimmerSection")
  add(b.sep)
  if room.is_boss then
    common.add_wrapped_prefixed(add, b.row, "  ⚔ BOSS: ", room.command:gsub("\n", " ↵ "), width, "VimmerBoss")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      common.add_wrapped_prefixed(add, b.row, string.format("  PHASE %d: ", i), phase.tip or "", width, "VimmerCommand")
      if phase.goal and phase.goal ~= "" then
        common.add_wrapped_prefixed(add, b.row, "  GOAL:   ", phase.goal:gsub("\n", " ↵ "), width, "VimmerXP")
      end
      common.add_wrapped_prefixed(add, b.row, "  BEFORE: ", phase.start_text:gsub("\n", " ↵ "), width, "VimmerLocked")
      common.add_wrapped_prefixed(add, b.row, "  AFTER:  ", phase.target_text:gsub("\n", " ↵ "), width, "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
  else
    common.add_wrapped_prefixed(add, b.row, "  ", room.command:gsub("\n", " ↵ "), width, "VimmerCommand")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    if room.goal and room.goal ~= "" then
      common.add_wrapped_prefixed(add, b.row, "  GOAL: ", room.goal:gsub("\n", " ↵ "), width, "VimmerXP")
    end
    add(b.sep)
    local inner_example_w = width - 4
    local diff_lines = hl.build_diff_line(room.before_example, room.after_example, inner_example_w)
    for _, dl in ipairs(diff_lines) do
      diff_rows[#diff_rows+1] = #lines
      add(b.row("  " .. dl), "VimmerExample")
    end
    add(b.sep)
    common.add_wrapped_prefixed(add, b.row, "  ", room.usage_tip or "", width, "VimmerTeachTip")
  end

  local any_alt = false
  if room.is_boss then
    for _, ph in ipairs(room.phases or {}) do
      local al = ph.optimal_keystrokes_alternates
      if type(al) == "table" and #al > 0 then any_alt = true break end
    end
  elseif room.optimal_keystrokes_alternates and #room.optimal_keystrokes_alternates > 0 then
    any_alt = true
  end
  if any_alt then
    add(b.sep)
    add(b.row("  Multiple valid key paths — scoring accepts alternates."), "VimmerTeachFoot")
  end

  if flow_opts.daily then
    add(b.sep)
    add(b.row("  Daily challenge — mutators unlock from lifetime XP."), "VimmerXP")
  end

  local ms = common.mutator_summary_line(flow_opts.mutators or {})
  if ms then
    add(b.sep)
    add(b.row(ms), "VimmerTimerWarn")
  end

  local pb_line = common.pb_line(flow_opts.pb)
  if pb_line then
    add(b.sep)
    add(b.row(pb_line), "VimmerXP")
  end

  add(b.sep)
  add(b.row(common.game_footer({
    { "ENTER", "begin" }, { "R", "replay" }, { "Q", "close" },
  })), "VimmerTeachFoot")
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  for _, row in ipairs(diff_rows) do
    local line = lines[row + 1]
    local pos = 1
    while pos <= #line do
      local b1 = line:byte(pos)
      if b1 == 0xe2 then
        local b2 = line:byte(pos + 1) or 0
        local b3 = line:byte(pos + 2) or 0
        if b2 == 0x96 and b3 == 0x8c then
          api.nvim_buf_add_highlight(buf, 0, "VimmerCrit", row, pos - 1, pos + 2)
          pos = pos + 3
        elseif b2 == 0x86 and b3 == 0x92 then
          api.nvim_buf_add_highlight(buf, 0, "VimmerXP", row, pos - 1, pos + 2)
          pos = pos + 3
        else
          pos = pos + 1
        end
      else
        pos = pos + 1
      end
    end
  end

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    require("the-vimmer.ui.transition").run("enter_play", on_begin)
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "r", function()
    require("the-vimmer.ui").open_key_replay(room, { phase_index = room.is_boss and 1 or nil })
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true, silent = true })
end

return M
