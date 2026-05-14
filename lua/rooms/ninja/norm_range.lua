-- Ninja room: :'<,'>norm (apply a normal-mode sequence to every line in a selection).
-- Workflow: V (visual line), G (extend to last line), : (auto-prefills '<,'>), then "norm A;<CR>".
-- :norm appends an implicit <Esc> after A;, committing the insert.
return {
  id = "ninja_norm_range",
  tier = "ninja",
  command = ":'<,'>norm <cmd>",
  title = "Apply Normal to Selection: :norm",
  description = "Run a normal-mode sequence on every line in a visual selection",
  before_example = "alpha\nbeta",
  after_example = "alpha;\nbeta;",
  usage_tip = "V<motion> then :norm A;<CR> appends a char to many lines at once.",
  start_text = "red\ngreen\nblue\nyellow",
  target_text = "red;\ngreen;\nblue;\nyellow;",
  base_xp = 110,
  time_limit = 55,
  optimal_keystrokes = { "V", "G", ":", "n", "o", "r", "m", " ", "A", ";", "\r" },
}
