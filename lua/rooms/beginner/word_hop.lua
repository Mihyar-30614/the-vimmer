-- Beginner room: w/b/e combined. Rename two occurrences of a word in one line.
return {
  id = "beginner_word_hop",
  tier = "beginner",
  command = "w / b / e",
  title = "Word Motions: w, b, e",
  description = "w = next word, b = back word, e = end of word",
  before_example = "the |old fox the |old dog",
  after_example = "the |new fox the |new dog",
  usage_tip = "w hops forward one word. 2w hops two words. b reverses.",
  efficiency_hint = "Hop by words with w/b/e instead of single-char motions.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 55,
  goal = "Change both `old` words to `new`.",
  start_text = [[
the old fox jumps over the old dog]],
  target_text = [[
the new fox jumps over the new dog]],
  base_xp = 45,
  optimal_keystrokes = { "w", "c", "w", "n", "e", "w", "\27", "5", "w", "c", "w", "n", "e", "w", "\27" },
  optimal_keystrokes_alternates = {
    { "w", "c", "w", "n", "e", "w", "\27", "w", "w", "w", "w", "w", "c", "w", "n", "e", "w", "\27" },
  },
}
