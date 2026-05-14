-- Ninja room: :'<,'>norm. Run a normal-mode sequence on every line in a visual selection.
return {
  id = "ninja_norm_range",
  tier = "ninja",
  command = ":'<,'>norm <cmd>",
  title = "Apply Normal to Selection: :norm",
  description = "Run a normal-mode sequence on every line in a visual selection.",
  usage_tip = "V<motion> then :norm A;<CR> appends a char to many lines at once. The macro alternative for one-shot edits.",
  before_example = "a = 1|\nb = 2",
  after_example = "a = 1;|\nb = 2;",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Append `;` to all four lines using `:'<,'>norm A;`.",
  start_text = [[
local a = 1
local b = 2
local c = 3
local d = 4]],
  target_text = [[
local a = 1;
local b = 2;
local c = 3;
local d = 4;]],
  base_xp = 130,
  optimal_keystrokes = { "V", "G", ":", "n", "o", "r", "m", " ", "A", ";", "\r" },
  optimal_keystrokes_alternates = {
    { ":", "%", "n", "o", "r", "m", " ", "A", ";", "\r" },
    { "A", ";", "\27", "j", ".", "j", ".", "j", "." },
  },
}
