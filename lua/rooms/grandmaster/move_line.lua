-- Grandmaster: relocate a line with :m (move to address).
return {
  id = "grandmaster_move_line",
  tier = "grandmaster",
  command = ":3m0",
  title = "Move Lines: :m",
  description = ":<range>m<addr> moves lines to after <addr>. :3m0 moves line 3 to the top.",
  before_example = "second / third / first",
  after_example = "first / second / third",
  usage_tip = ":m (alias :move) relocates lines by address; 0 means before line 1.",
  efficiency_hint = ":3m0 lifts the third line to the top in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Move the third line to the top with :m.",
  start_text = [[
second
third
first]],
  target_text = [[
first
second
third]],
  base_xp = 90,
  time_limit = 70,
  optimal_keystrokes = { ":", "3", "m", "0", "\r" },
}
