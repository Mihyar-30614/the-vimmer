-- Grandmaster: relocate every matching line to the end with :g//m$.
return {
  id = "grandmaster_global_move",
  tier = "grandmaster",
  command = ":g/^#/m$",
  title = "Global + Move",
  description = ":g/pat/m$ moves each matching line to the bottom, preserving order.",
  before_example = "# note (moves down)",
  after_example = "code (stays up)",
  usage_tip = "Pair :g with :m (or :t) to relocate or duplicate matching lines.",
  efficiency_hint = ":g/^#/m$ sweeps all comment lines to the end in one pass.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Move every line starting with # to the end, keeping their order.",
  start_text = [[
# header one
code a
# header two
code b]],
  target_text = [[
code a
code b
# header one
# header two]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = {
    ":", "g", "/", "^", "#", "/", "m", "$", "\r",
  },
}
