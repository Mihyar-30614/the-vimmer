-- Grandmaster: repeat the last :substitute on another line with &.
return {
  id = "grandmaster_amp_repeat",
  tier = "grandmaster",
  command = ":s/old/new/ then &",
  title = "Repeat Substitute: &",
  description = "& repeats the last :s on the current line. Substitute once, then & elsewhere.",
  before_example = "foo here",
  after_example = "bar here",
  usage_tip = "Run :s once, move to the next line, press & to replay it.",
  efficiency_hint = "Run :s once, then & on the next line repeats it without retyping.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Replace foo with bar on both lines: :s once, then & on the next.",
  start_text = [[
foo here
foo there]],
  target_text = [[
bar here
bar there]],
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = {
    ":", "s", "/", "f", "o", "o", "/", "b", "a", "r", "/", "\r", "j", "&",
  },
}
