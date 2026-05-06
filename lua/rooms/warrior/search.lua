return {
  id = "warrior_search",
  tier = "warrior",
  command = "/ and n / N",
  title = "Search: /, n, N",
  description = "Search forward for a pattern (/), jump to next match (n), previous (N)",
  before_example = "|the quick brown fox jumps over the lazy dog",
  after_example = "the quick brown |fox jumps over the lazy dog",
  usage_tip = "/ followed by your search term then Enter. n hops to next match instantly.",
  start_text = "the quick brown fox jumps over the lazy dog",
  target_text = "the quick brown fox jumps over the lazy dog",
  base_xp = 70,
  optimal_keystrokes = { "/", "f", "o", "x", "\13" },
}
