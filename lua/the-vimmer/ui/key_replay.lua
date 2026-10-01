local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")

function M.open_key_replay(room, replay_opts)
  replay_opts = replay_opts or {}
  local phase_idx = replay_opts.phase_index
  local keys = {}
  if room.is_boss then
    local ph = room.phases[phase_idx or 1]
    if ph and ph.optimal_keystrokes then
      for _, k in ipairs(ph.optimal_keystrokes) do keys[#keys + 1] = k end
    end
  elseif room.optimal_keystrokes then
    for _, k in ipairs(room.optimal_keystrokes) do keys[#keys + 1] = k end
  end

  local width = common.pick_float_width(54)
  local b = common.make_border(width)
  local lines = {}
  local hls = {}
  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end
  add(b.top)
  add(b.row(common.game_section("KEY REPLAY", width)), "VimmerSection")
  add(b.sep)
  if replay_opts.hint then
    common.add_wrapped_prefixed(add, b.row, "  ", replay_opts.hint, width, "VimmerTeachTip")
    add(b.sep)
  end
  local key_start = #lines
  if #keys == 0 then
    add(b.row("  (no scripted sequence)"), "VimmerLocked")
  else
    for i, k in ipairs(keys) do
      add(b.row(string.format("  %2d  %s", i, common.format_key(k))), "VimmerTitle")
    end
  end
  add(b.sep)
  add(b.row(common.game_footer({ { "Q", "close" } })), "VimmerTeachFoot")
  add(b.bot)

  local buf, win
  buf, win = float.open_float(lines, width, { on_resize = function()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
    if replay_opts.on_close then replay_opts.on_close() end
  end })
  float.apply_hl(buf, hls)
  local ns = api.nvim_create_namespace("the-vimmer-replay")

  local function close_replay()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  vim.keymap.set("n", "q", close_replay, { buffer = buf, nowait = true, silent = true })

  if #keys > 0 and not common.reduced_motion() then
    local i = 1
    local function pulse()
      if not api.nvim_buf_is_valid(buf) then return end
      api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      float.apply_hl(buf, hls)
      if i <= #keys then
        api.nvim_buf_add_highlight(buf, ns, "VimmerCrit", key_start + i - 1, 0, -1)
        float.ensure_visible(win, key_start + i)
        i = i + 1
        vim.defer_fn(pulse, 170)
      end
    end
    vim.defer_fn(pulse, 120)
  end
  return buf, win
end

return M
