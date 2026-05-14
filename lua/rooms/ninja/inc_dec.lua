-- Ninja room: Ctrl-A / Ctrl-X (increment / decrement next number).
-- Optimal uses count-prefix: 4<C-a> bumps the next number by 4. Three lines, one bump each.
return {
  id = "ninja_inc_dec",
  tier = "ninja",
  command = "<C-a> / <C-x>",
  title = "Increment / Decrement: <C-a>, <C-x>",
  description = "Bump the next number on or after the cursor up (<C-a>) or down (<C-x>)",
  before_example = "version |1",
  after_example = "version |2",
  usage_tip = "Prefix a count: 5<C-a> adds 5. Scans forward from cursor on current line.",
  start_text = "build: 1\nstage: 1\ndeploy: 1",
  target_text = "build: 5\nstage: 5\ndeploy: 5",
  base_xp = 100,
  time_limit = 50,
  optimal_keystrokes = { "4", "\x01", "j", "4", "\x01", "j", "4", "\x01" },
}
