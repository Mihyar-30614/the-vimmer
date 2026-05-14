-- Ninja room: "ay/"ap (named register workflow). Player yanks to register a then pastes it elsewhere.
return {
  id = "ninja_registers2",
  tier = "ninja",
  command = "\"ay / \"ap",
  title = "Named Register Workflow",
  description = "Yank into a named register with \"<reg>yy, paste with \"<reg>p",
  before_example = '"ayy → stores line. "ap → pastes it.',
  after_example = "first line copied to end",
  usage_tip = '"ayy yanks into register a. "ap pastes from register a. Registers a-z are yours.',
  start_text = "alpha\nbeta\n[replace me]",
  target_text = "alpha\nbeta\nalpha",
  base_xp = 115,
  time_limit = 75,
  optimal_keystrokes = { '"', "a", "y", "y", "2", "j", "d", "d", '"', "a", "p" },
}
