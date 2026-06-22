-- Grandmaster: apply normal-mode keys to a line range with :%norm.
return {
  id = "grandmaster_norm_range",
  tier = "grandmaster",
  command = ":%norm $x",
  title = "Range :normal",
  description = ":<range>norm <keys> runs the same normal-mode keys on each line in the range.",
  before_example = "alpha,",
  after_example = "alpha",
  usage_tip = ":%norm runs any normal command (here $x deletes the last char) per line.",
  efficiency_hint = ":%norm $x strips the trailing char from every line at once.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Delete the trailing comma from every line using :%norm.",
  start_text = [[
alpha,
beta,
gamma,]],
  target_text = [[
alpha
beta
gamma]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = { ":", "%", "n", "o", "r", "m", " ", "$", "x", "\r" },
}
