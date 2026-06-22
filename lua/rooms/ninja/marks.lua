-- Ninja room: ma / `a. Set a mark, edit elsewhere, return via the mark and edit again.
return {
  id = "ninja_marks",
  tier = "ninja",
  command = "m<a> / '<a> / `<a>",
  title = "Marks: Long-Range Jumps",
  description = "Set a mark with ma. Jump back to it with 'a (line) or `a (exact position).",
  usage_tip = "ma sets mark 'a' at cursor. `a jumps to that exact position from anywhere in the file.",
  efficiency_hint = "Set a mark with ma, then leap back with `a anytime.",
  before_example = "...|line 2 mark...\n...\n...line 6 edit...",
  after_example = "(both lines edited)",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 75,
  goal = "Mark line 2, jump to line 6 and append `;`, return to mark and uppercase line 2.",
  start_text = [[
-- module header
local CONFIG = load()
local x = 1
local y = 2
local z = 3
local result = run(CONFIG)
return result]],
  target_text = [[
-- module header
LOCAL CONFIG = LOAD()
local x = 1
local y = 2
local z = 3
local result = run(CONFIG);
return result]],
  base_xp = 130,
  optimal_keystrokes = { "m", "a", "6", "G", "A", ";", "\27", "`", "a", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "m", "a", "/", "r", "u", "n", "\r", "A", ";", "\27", "'", "a", "g", "U", "U" },
  },
}
