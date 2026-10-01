-- Native window geometry + end-to-end learning/reward regression checks.
-- Run with isolated XDG dirs: nvim --headless -u NONE -l tests/ui_runtime.lua
vim.opt.rtp:prepend(vim.fn.getcwd())
local api = vim.api
local root = require("the-vimmer")
local rooms = require("the-vimmer.rooms")
local progress = require("the-vimmer.progress")
local ui = require("the-vimmer.ui")
local by_tier = {}
for _, tier in ipairs(rooms.all_tiers()) do by_tier[tier] = rooms.load_tier(tier) end
local checks = 0
local function check(ok, msg) assert(ok, msg); checks = checks + 1 end
local function close_floats()
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) and api.nvim_win_get_config(win).relative ~= "" then api.nvim_win_close(win, true) end
  end
end
local function press(key)
  local map = vim.fn.maparg(key, "n", false, true)
  check(type(map.callback) == "function", "missing immediate control " .. key)
  map.callback()
end
local function text(buf) return table.concat(api.nvim_buf_get_lines(buf or 0, 0, -1, false), "\n") end
local function fit_panels()
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_config(win).relative ~= "" then
      check(api.nvim_win_get_height(win) <= vim.o.lines - 2, "panel exceeds terminal height")
      for _, line in ipairs(api.nvim_buf_get_lines(api.nvim_win_get_buf(win), 0, -1, false)) do
        check(vim.fn.strdisplaywidth(line) <= api.nvim_win_get_width(win), "panel row overflow: " .. line)
      end
    end
  end
end
local function footer_visible()
  for _, win in ipairs(api.nvim_list_wins()) do
    local cfg = api.nvim_win_get_config(win)
    if cfg.relative ~= "" and (cfg.focusable == false or api.nvim_buf_line_count(api.nvim_win_get_buf(win)) <= api.nvim_win_get_height(win)) then
      if text(api.nvim_win_get_buf(win)):find("%[Q%]") then return true end
    end
  end
end
local function resize(cols, lines)
  vim.o.columns, vim.o.lines = cols, lines
  api.nvim_exec_autocmds("VimResized", {})
end
local run = function()
  for _, mode in ipairs({ "unicode", "ascii" }) do
    root.setup({ icons = mode, reduced_motion = true })
    for _, size in ipairs({ {120,40}, {80,24}, {50,18}, {40,15} }) do
      resize(size[1], size[2])
      ui.open_map(progress.reset_data(), by_tier, function() end)
      check(text():find("CONTINUE"), "no recommended mission")
      check(text():find("Basic Motions"), "first mission is not hjkl")
      fit_panels()
      check(footer_visible(), "map footer is hidden")
      press("a")
      fit_panels()
      check(footer_visible(), "expanded map footer is hidden")
      if mode == "ascii" then
        for _, ch in ipairs({ "🔥", "🔒", "⚔", "▶", "▾", "▸" }) do check(not text():find(ch, 1, true), "ASCII map leaked " .. ch) end
      end
      close_floats()
      ui.open_teach(rooms.get_room("warrior_boss"), function() end)
      fit_panels()
      check(footer_visible(), "lesson footer is hidden")
      close_floats()
      ui.open_results(80, 100, 3, nil, function() end, { room = rooms.get_room("beginner_hjkl"), fast_clear = true, on_powerup = function() end,
        total_xp = 120, previous_xp = 40, run_stats = { keystrokes_used = 4, optimal_count = 4 } })
      fit_panels()
      check(footer_visible(), "results footer is hidden")
      local view = api.nvim_win_call(0, vim.fn.winsaveview)
      local line = api.nvim_win_get_cursor(0)[1]
      check(line >= view.topline + 3 and line < view.topline + api.nvim_win_get_height(0) - 3
        or api.nvim_buf_line_count(0) <= api.nvim_win_get_height(0), "reward selection hidden under frame")
      press("d")
      local detail_win = api.nvim_get_current_win()
      local detail_z = api.nvim_win_get_config(detail_win).zindex
      for _, other in ipairs(api.nvim_list_wins()) do
        if other ~= detail_win and api.nvim_win_get_config(other).relative ~= "" then
          local c = api.nvim_win_get_config(other)
          check(c.zindex < detail_z or c.focusable == false and c.zindex == detail_z + 1, "older panel covers analysis")
        end
      end
      press("q")
      check(type(vim.fn.maparg("<CR>", "n", false, true).callback) == "function", "results delay input")
      close_floats()
      local room = rooms.get_room("beginner_hjkl")
      local g = require("the-vimmer.game").new()
      g:start_room(room); g:begin_play()
      ui.open_play(room, g, function() end, function() end)
      local hud
      for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
        if text(api.nvim_win_get_buf(win)):find("GOAL") or text(api.nvim_win_get_buf(win)):find("MISSION") then hud = win end
      end
      check(hud ~= nil, "no mission HUD")
      local hl = api.nvim_buf_get_lines(api.nvim_win_get_buf(hud), 0, api.nvim_win_get_height(hud), false)
      check(table.concat(hl, "\n"):find("Change"), "mission below visible HUD")
      resize(120,40); resize(40,15); resize(size[1],size[2])
      check(api.nvim_win_is_valid(hud), "HUD lost after resizing")
      ui._close_play()
    end
  end
  root.setup({ reduced_motion = true })
  resize(80,24)
  check(vim.fn.strdisplaywidth(require("the-vimmer.ui.common").pad_row(" 🔥 x3", 20)) == 20, "wide glyph padding")
  local before = progress.reset_data()
  before.total_xp, before.streak = 80, 4
  progress.save(before)
  -- feedkeys deliberately has no raw typed input. Supply the same raw-key
  -- notifications as a terminal, then let Neovim execute the real edits.
  local observers = {}
  local original_on_key = vim.on_key
  vim.on_key = function(callback, ns, ...)
    observers[ns] = callback
    return original_on_key(callback, ns, ...)
  end
  local function edit(keys)
    for key in keys:gmatch(".") do
      for _, observer in pairs(observers) do observer(key, key) end
    end
    api.nvim_feedkeys(keys, "nx", false)
  end
  local commands = require("the-vimmer.commands")
  commands.start_flow(rooms.get_room("beginner_hjkl"))
  press("p")
  edit("j$r5")
  check(vim.wait(500, function() return text():find("PRACTICE COMPLETE") ~= nil end, 10), "practice did not reach results")
  check(vim.deep_equal(before, progress.load()), "practice altered ranked progress")
  press("q"); close_floats()
  local captured
  local actual_play = ui.open_play
  ui.open_play = function(room, state, ...) captured = state; return actual_play(room, state, ...) end
  commands.start_flow(rooms.get_room("beginner_hjkl"))
  press("<CR>")
  edit("j$r5")
  check(vim.wait(500, function() return text():find("VICTORY") ~= nil end, 10), "ranked clear did not reach results")
  check(progress.load().cleared.beginner_hjkl, "ranked clear not saved")
  press("1") -- potion -> next lesson -> next room
  check(text():find("Replace"), "next mission is not the curriculum successor")
  press("<CR>")
  check(#captured.power_ups == 1 and captured.power_ups[1].type == "hp_restore", "reward lost between rooms")
  for _ = 1, captured.keystrokes_budget + 6 do captured:register_key("x") end
  check(captured.hp == 100 and #captured.power_ups == 0, "reserve potion did not restore damage")
  press("<F1>")
  check(vim.wait(200, function() return text():find("KEY REPLAY") ~= nil end, 10), "hint does not open")
  press("<Esc>")
  press("<F2>")
  check(vim.wait(200, function() return text():find("WORLD MAP") ~= nil end, 10), "cannot leave play")
  close_floats()
  ui.open_play = actual_play
  vim.on_key = original_on_key
  root.setup({ reduced_motion = false })
  local callbacks = 0
  ui.open_results(40, 100, 1, nil, function() callbacks = callbacks + 1 end, { total_xp = 40 })
  press("q")
  vim.wait(400, function() return false end, 10)
  check(callbacks == 1, "animation interfered with immediate exit")
end
local ok, err = xpcall(run, debug.traceback)
ui._close_play()
close_floats()
if not ok then print(err); vim.cmd("cquit 1") end
print(string.format("Native UI checks: %d passed", checks))
vim.cmd("qa!")
