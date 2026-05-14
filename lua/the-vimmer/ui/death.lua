local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
-- NOTE: do NOT top-level-require "the-vimmer.ui" — circular load.

function M.open_death(room, on_retry, on_map, death_opts)
  death_opts = death_opts or {}
  local width = common.pick_float_width(float.FLOAT_DEATH_W)
  local b = common.make_border(width)
  local death_optimal_inner = math.max(28, width - 4)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("        YOU DIED"), "VimmerDeath")
  add(b.sep)
  if death_opts.timed_out then
    add(b.row("  Time ran out"), "VimmerTimerDanger")
  else
    add(b.row("  HP reached zero"), "VimmerDeath")
  end
  local over_budget = death_opts.over_budget_count or 0
  if over_budget > 0 then
    add(b.row(string.format("  Over-budget keys: %d", over_budget)), "VimmerLocked")
  end
  add(b.row("  Streak lost"))
  add(b.sep)
  add(b.row("  Optimal sequence:"), "VimmerTitle")
  for _, ln in ipairs(common.build_optimal_lines(room, death_optimal_inner)) do
    add(b.row(ln), "VimmerCommand")
  end
  add(b.sep)
  add(b.row("  <Enter> retry   <r> replay keys   <q> map"))
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_retry()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "r", function()
    require("the-vimmer.ui").open_key_replay(room, { phase_index = room.is_boss and 1 or nil })
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
    on_map()
  end, { buffer = buf, nowait = true, silent = true })
end

return M
