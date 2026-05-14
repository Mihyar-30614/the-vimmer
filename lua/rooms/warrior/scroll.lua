-- Warrior room: zz/zt/zb. After a big jump, recenter the view, then edit.
return {
  id = "warrior_scroll",
  tier = "warrior",
  command = "zz / zt / zb",
  title = "Center View: zz, zt, zb",
  description = "zz centers cursor line; zt puts it at top; zb at bottom.",
  usage_tip = "Great after a big jump (G, /search, gg). zz feels like re-anchoring.",
  before_example = "...|line 8...",
  after_example = "...|FIXED...",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Jump to line 8 (`bug here`), recenter, then replace it with `FIXED`.",
  start_text = [[
header line
note one
note two
note three
note four
note five
note six
bug here
note eight
note nine]],
  target_text = [[
header line
note one
note two
note three
note four
note five
note six
FIXED
note eight
note nine]],
  base_xp = 80,
  optimal_keystrokes = { "8", "G", "z", "z", "c", "c", "F", "I", "X", "E", "D", "\27" },
  optimal_keystrokes_alternates = {
    { "/", "b", "u", "g", "\r", "z", "z", "c", "c", "F", "I", "X", "E", "D", "\27" },
    { "8", "G", "z", "t", "S", "F", "I", "X", "E", "D", "\27" },
  },
}
