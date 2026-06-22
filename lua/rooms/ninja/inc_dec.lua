-- Ninja room: <C-a> / <C-x>. Bump version numbers without retyping them.
return {
  id = "ninja_inc_dec",
  tier = "ninja",
  command = "<C-a> / <C-x>",
  title = "Increment / Decrement: <C-a>, <C-x>",
  description = "Bump the next number on or after the cursor up (<C-a>) or down (<C-x>).",
  usage_tip = "Prefix a count: 5<C-a> adds 5. Scans forward from cursor on current line.",
  efficiency_hint = "Ctrl-a increments a number; prefix a count to add more.",
  before_example = "version = 1|",
  after_example = "version = 2|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Bump MAJOR from 1 to 2, bump MINOR by 5, decrement PATCH from 9 to 7.",
  start_text = [[
local MAJOR = 1
local MINOR = 0
local PATCH = 9]],
  target_text = [[
local MAJOR = 2
local MINOR = 5
local PATCH = 7]],
  base_xp = 130,
  optimal_keystrokes = { "\1", "j", "5", "\1", "j", "2", "\24" },
}
