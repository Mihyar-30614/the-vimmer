-- Beginner room: x/dd/yy/p mix. Delete a duplicated line, remove one stray char.
return {
  id = "beginner_delete_yank",
  tier = "beginner",
  command = "x / dd / yy / p",
  title = "Delete & Paste: x, dd, yy, p",
  description = "Delete char (x), delete line (dd), yank line (yy), paste (p)",
  before_example = "a = 1\na = 1|\nb = 2",
  after_example = "a = 1|\nb = 2",
  usage_tip = "dd deletes the whole line into a register. Nothing is truly deleted in Vim.",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  goal = "Delete the duplicated line 2, then remove the stray `;` at the end of line 1.",
  start_text = [[
local a = 1;
local a = 1
local b = 2]],
  target_text = [[
local a = 1
local b = 2]],
  base_xp = 60,
  optimal_keystrokes = { "d", "d", "k", "$", "x" },
}
