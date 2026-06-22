-- Warrior room: f/t. Jump to a punctuation mark on a line, edit the word that follows.
return {
  id = "warrior_f_motion",
  tier = "warrior",
  command = "f<char> / t<char>",
  title = "Find Char: f, t",
  description = "Jump to next occurrence of a char (f lands ON it, t lands BEFORE it).",
  usage_tip = "f: jumps to the colon. Use ; to repeat the jump forward, , to go back.",
  efficiency_hint = "f<char> jumps straight to a character on the line.",
  before_example = "ok|, ok, ok, fail",
  after_example = "ok, ok, ok, |pass",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 50,
  goal = "Replace the value `fail` with `pass`.",
  start_text = [[
local results = {
  "ok", "ok", "ok", "fail",
}]],
  target_text = [[
local results = {
  "ok", "ok", "ok", "pass",
}]],
  base_xp = 80,
  optimal_keystrokes = { "f", "f", "c", "w", "p", "a", "s", "s", "\27" },
  optimal_keystrokes_alternates = {
    { "f", ",", "f", ",", "f", ",", "f", "f", "c", "i", "w", "p", "a", "s", "s", "\27" },
  },
}
