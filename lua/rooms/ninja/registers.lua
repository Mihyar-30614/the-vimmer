-- Ninja room: "ay / "ap. Yank into a named register, paste at a destination.
return {
  id = "ninja_registers",
  tier = "ninja",
  command = '"<reg>y and "<reg>p',
  title = "Named Registers: \"ay, \"ap",
  description = "Yank into a named register (\"ay) and paste from it (\"ap).",
  usage_tip = '"ay yanks the line into register a. "ap pastes it anywhere. Registers a-z are yours.',
  efficiency_hint = "Use named registers (a, b...) to hold several yanks at once.",
  before_example = "yank this|\n...\npaste here",
  after_example = "yank this\n...\nyank this|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Yank line 1 into register `a`, delete line 4 (clobbers unnamed), then paste from `a` below.",
  start_text = [[
local PORT = 8080
local HOST = "localhost"

local OLD_LINE = "remove me"
-- paste imported config here]],
  target_text = [[
local PORT = 8080
local HOST = "localhost"

-- paste imported config here
local PORT = 8080]],
  base_xp = 130,
  optimal_keystrokes = { "\"", "a", "y", "y", "j", "j", "j", "d", "d", "\"", "a", "p" },
  optimal_keystrokes_alternates = {
    { "\"", "a", "y", "y", "4", "G", "d", "d", "G", "\"", "a", "p" },
  },
}
