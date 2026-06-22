-- Grandmaster: filter the whole buffer through an external command with :%!.
return {
  id = "grandmaster_filter",
  tier = "grandmaster",
  command = ":%!sort",
  title = "External Filter: :!",
  description = ":<range>!cmd pipes lines through a shell command and replaces them with its output.",
  before_example = "charlie / alpha / bravo",
  after_example = "alpha / bravo / charlie",
  usage_tip = ":%!sort, :%!uniq, :%!column — pipe the buffer through any filter.",
  efficiency_hint = ":%!sort filters the whole buffer through sort in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Sort all lines by piping the buffer through sort.",
  start_text = [[
charlie
alpha
bravo]],
  target_text = [[
alpha
bravo
charlie]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = { ":", "%", "!", "s", "o", "r", "t", "\r" },
}
