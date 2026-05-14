-- Ninja room: :sort (sort buffer lines). Player types :sort<CR>.
return {
  id = "ninja_sort",
  tier = "ninja",
  command = ":sort",
  title = "Sort Lines: :sort",
  description = "Sort lines in the buffer alphabetically (or numerically with n flag)",
  before_example = "banana\napple\ncherry",
  after_example = "apple\nbanana\ncherry",
  usage_tip = ":sort sorts whole file; visual+:sort sorts the selection. :sort! reverses. :sort u removes dupes.",
  start_text = "echo\nalpha\ndelta\nbravo\ncharlie",
  target_text = "alpha\nbravo\ncharlie\ndelta\necho",
  base_xp = 100,
  time_limit = 45,
  optimal_keystrokes = { ":", "s", "o", "r", "t", "\r" },
}
