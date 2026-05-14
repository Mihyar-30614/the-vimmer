-- Warrior room: ci"/ci(. Replace string contents and an arg list.
return {
  id = "warrior_ci_combo",
  tier = "warrior",
  command = "ci\" / ci( / ci[",
  title = "Change Inside Combo",
  description = "ci<delim> changes everything inside the given delimiter pair",
  before_example = 'log("old", a, b)|',
  after_example = 'log("new", x, y)|',
  usage_tip = 'ci" changes inside double quotes. ci( changes inside parens.',
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 60,
  goal = "Replace the log tag `old` with `new`, then replace the arg list `old, a, b` with `new, x, y`.",
  start_text = [[
local function emit()
  log("old", a, b)
end]],
  target_text = [[
local function emit()
  log("new", x, y)
end]],
  base_xp = 80,
  optimal_keystrokes = { "f", "o", "c", "i", "\"", "n", "e", "w", "\27", "f", "a", "c", "i", "(", "\"", "n", "e", "w", "\"", ",", " ", "x", ",", " ", "y", "\27" },
  optimal_keystrokes_alternates = {
    { "f", "\"", "c", "i", "\"", "n", "e", "w", "\27", "c", "i", "(", "\"", "n", "e", "w", "\"", ",", " ", "x", ",", " ", "y", "\27" },
  },
}
