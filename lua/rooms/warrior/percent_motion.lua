-- Warrior room: %. Jump matching brackets to delete a wrapper function call.
return {
  id = "warrior_percent",
  tier = "warrior",
  command = "%",
  title = "Jump to Match: %",
  description = "Jump between matching bracket pairs: (), [], {}.",
  usage_tip = "% jumps to the matching bracket. Essential for navigating nested code.",
  efficiency_hint = "% jumps between matching brackets instantly.",
  before_example = "wrap(|foo(x))",
  after_example = "foo(x)|",
  filetype = "lua",
  cursor_start = { row = 2, col = 14 },
  time_limit = 55,
  goal = "Strip the `wrap(...)` wrapper, leaving just `foo(x)`.",
  start_text = [[
local function call()
  return wrap(foo(x))
end]],
  target_text = [[
local function call()
  return foo(x)
end]],
  base_xp = 95,
  optimal_keystrokes = { "%", "x", "F", "w", "d", "f", "(" },
  optimal_keystrokes_alternates = {
    { "F", "p", "l", "%", "x", "F", "w", "d", "f", "(" },
  },
}
