-- Warrior room: H/M/L. Window-relative jumps + small edit.
return {
  id = "warrior_viewport",
  tier = "warrior",
  command = "H / M / L",
  title = "Viewport Jumps: H, M, L",
  description = "H = top of screen, M = middle, L = bottom.",
  usage_tip = "Jumps within the visible window — not the whole file. Quick when scrolling around.",
  efficiency_hint = "H/M/L jump to the top, middle, and bottom of the screen.",
  before_example = "top|\nmid\nbot",
  after_example = "TOP|\nmid\nBOTTOM",
  filetype = "text",
  cursor_start = { row = 3, col = 1 },
  time_limit = 50,
  goal = "Use viewport jumps to upcase the first line `top` and the last line `bottom`.",
  start_text = [[
top
filler 1
filler 2
filler 3
middle
filler 4
filler 5
filler 6
bottom]],
  target_text = [[
TOP
filler 1
filler 2
filler 3
middle
filler 4
filler 5
filler 6
BOTTOM]],
  base_xp = 85,
  optimal_keystrokes = { "H", "g", "U", "U", "L", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "g", "g", "g", "U", "U", "G", "g", "U", "U" },
  },
}
