-- Ninja room: "ay/"ap basics. Player yanks line 1 to register a, jumps to line 4, pastes and deletes original.
return {
  id = "ninja_registers",
  tier = "ninja",
  command = '"<reg>y and "<reg>p',
  title = "Named Registers: \"ay, \"ap",
  description = 'Yank into a named register ("ay) and paste from it ("ap)',
  before_example = "alpha\nbeta\n\npaste_here",
  after_example = "alpha\nbeta\n\nalpha",
  usage_tip = '"ay yanks the line into register a. "ap pastes it anywhere. Store up to 26 values.',
  start_text = "alpha\nbeta\n\npaste_here",
  target_text = "alpha\nbeta\n\nalpha",
  base_xp = 110,
  optimal_keystrokes = { '"', "a", "y", "y", "j", "j", "j", '"', "a", "p", "d", "d" },
}
