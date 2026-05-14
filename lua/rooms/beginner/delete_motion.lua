-- Beginner room: d{motion} (operator + motion grammar). Player deletes a leading junk word with dW.
return {
  id = "beginner_delete_motion",
  tier = "beginner",
  command = "d{motion}",
  title = "Delete by Motion: d + w/W/$/0",
  description = "d is an operator — combine it with any motion: dw deletes a word, dW a big-word, d$ to line end",
  before_example = "|JUNK rest of line",
  after_example = "rest of line",
  usage_tip = "d + motion is the Vim grammar. dw = delete word, dW = delete WORD (no punctuation split), d$ = delete to end.",
  start_text = "JUNK rest of line",
  target_text = "rest of line",
  base_xp = 50,
  optimal_keystrokes = { "d", "W" },
  optimal_keystrokes_alternates = {
    { "d", "a", "W" },
  },
}
