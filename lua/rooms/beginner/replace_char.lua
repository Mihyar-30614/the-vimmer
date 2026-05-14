-- Beginner room: r<char>. Fix three single-character typos.
return {
  id = "beginner_replace_char",
  tier = "beginner",
  command = "r<char>",
  title = "Replace Char: r",
  description = "Replace the character under the cursor without entering insert mode",
  before_example = "x = |9",
  after_example = "x = |0",
  usage_tip = "r replaces exactly one char and stays in normal mode. Faster than i + char + Esc for single fixes.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Fix three typos: `9` -> `0`, `q` -> `o`, `Z` -> `S`.",
  start_text = [[
local count = 9
local name = "qff"
local mode = "Zet"]],
  target_text = [[
local count = 0
local name = "off"
local mode = "Set"]],
  base_xp = 50,
  optimal_keystrokes = { "$", "r", "0", "j", "r", "o", "j", "r", "S" },
}
