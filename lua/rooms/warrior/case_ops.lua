-- Warrior room: gU/gu (case operators). Player lowercases an accidental ALL-CAPS line with guu.
return {
  id = "warrior_case_ops",
  tier = "warrior",
  command = "gU{motion} / gu{motion}",
  title = "Case Operators: gU, gu",
  description = "gU uppercases, gu lowercases. Combine with any motion or double for whole line: gUU / guu",
  before_example = "|ALL CAPS MISTAKE",
  after_example = "|all caps mistake",
  usage_tip = "guu = lowercase line, gUU = uppercase line. gUw = uppercase next word. g~ toggles case.",
  start_text = "ALL CAPS MISTAKE",
  target_text = "all caps mistake",
  base_xp = 70,
  optimal_keystrokes = { "g", "u", "u" },
  optimal_keystrokes_alternates = {
    { "g", "u", "$" },
    { "g", "~", "~" },
  },
}
