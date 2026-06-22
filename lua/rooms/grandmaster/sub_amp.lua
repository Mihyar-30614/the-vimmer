-- Grandmaster: wrap every number using & (the whole match) in the replacement.
return {
  id = "grandmaster_sub_amp",
  tier = "grandmaster",
  command = ":%s/\\d\\+/[&]/g",
  title = "Substitute: Whole-Match &",
  description = "& in the replacement stands for the entire matched text.",
  before_example = "x = 10",
  after_example = "x = [10]",
  usage_tip = "Use & (or \\0) to reuse the whole match without a capture group.",
  efficiency_hint = "& reuses the whole match — no capture group needed to wrap it.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Wrap every number in square brackets using &.",
  start_text = [[
x = 10
y = 250]],
  target_text = [=[
x = [10]
y = [250]]=],
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = {
    ":", "%", "s", "/", "\\", "d", "\\", "+", "/", "[", "&", "]", "/", "g", "\r",
  },
}
