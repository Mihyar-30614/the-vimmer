-- Ninja room: cgn + . (change next match + dot repeat). Modern search-and-replace without :%s.
return {
  id = "ninja_cgn",
  tier = "ninja",
  command = "cgn + .",
  title = "Change Next Match: cgn + .",
  description = "cgn changes the next search match. Combine with . to repeat across every occurrence — no :s needed.",
  before_example = "|old old old",
  after_example = "new new new",
  usage_tip = "cgn = c + gn (gn selects next match). After cgn + <word> + Esc, dot repeats the whole operation on the next match automatically.",
  start_text = "old old old",
  target_text = "new new new",
  base_xp = 120,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "n", "e", "w", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "/", "o", "l", "d", "\r", "c", "g", "n", "n", "e", "w", "\27", ".", "." },
  },
}
