-- Ninja room: :g/pattern/d (global command). Player deletes all comment lines in one shot.
return {
  id = "ninja_global_delete",
  tier = "ninja",
  command = ":g/pattern/d",
  title = "Global Command: :g/pattern/d",
  description = "Execute an ex command on every line matching a pattern. :g/#/d deletes all lines containing #",
  before_example = "keep\n# comment",
  after_example = "keep",
  usage_tip = ":g/pat/d = delete matching lines. :g/pat/normal <cmd> runs any normal command. :v/pat/d keeps only matching lines.",
  start_text = "keep\n# comment\nkeep\n# another\nkeep",
  target_text = "keep\nkeep\nkeep",
  base_xp = 110,
  optimal_keystrokes = { ":", "g", "/", "#", "/", "d", "\r" },
}
