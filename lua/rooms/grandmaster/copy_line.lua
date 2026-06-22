-- Grandmaster: duplicate a line with :t (copy to address).
return {
  id = "grandmaster_copy_line",
  tier = "grandmaster",
  command = ":1t$",
  title = "Copy Lines: :t",
  description = ":<range>t<addr> copies lines to after <addr>. :1t$ duplicates line 1 to the end.",
  before_example = "header / body",
  after_example = "header / body / header",
  usage_tip = ":t (alias :copy) duplicates lines anywhere by address.",
  efficiency_hint = ":1t$ copies the first line to the end in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Copy the first line to the end of the buffer with :t.",
  start_text = [[
header
body]],
  target_text = [[
header
body
header]],
  base_xp = 90,
  time_limit = 70,
  optimal_keystrokes = { ":", "1", "t", "$", "\r" },
}
