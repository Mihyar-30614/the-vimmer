-- Ninja room: multi-register workflow. Swap two lines via two named registers.
return {
  id = "ninja_registers2",
  tier = "ninja",
  command = "\"ay / \"by / \"ap / \"bp",
  title = "Named Register Workflow",
  description = "Yank into a named register with \"<reg>yy, paste with \"<reg>p.",
  usage_tip = '"ayy yanks into register a. "ap pastes from register a. Registers a-z are yours.',
  before_example = "alpha|\nbeta",
  after_example = "beta|\nalpha",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 100,
  goal = "Swap line 1 and line 3 using registers `a` and `b`.",
  start_text = [[
local first = 1
local middle = 2
local last = 3]],
  target_text = [[
local last = 3
local middle = 2
local first = 1]],
  base_xp = 140,
  optimal_keystrokes = { "\"", "a", "y", "y", "j", "j", "\"", "b", "y", "y", "d", "d", "g", "g", "d", "d", "\"", "b", "P", "G", "\"", "a", "p" },
}
