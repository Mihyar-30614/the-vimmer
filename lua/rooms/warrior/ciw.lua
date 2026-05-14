-- Warrior room: ciw/caw (change inner/around word). Player jumps to "wrong" and replaces it with "right".
return {
  id = "warrior_ciw",
  tier = "warrior",
  command = "ciw / caw",
  title = "Change Inner Word: ciw, caw",
  description = "Change the word under cursor. ciw = inner word, caw = word + surrounding space",
  before_example = "the wrong word here",
  after_example = "the right word here",
  usage_tip = "ciw deletes the word under cursor and puts you in insert mode. No manual selecting.",
  start_text = "the wrong word here",
  target_text = "the right word here",
  base_xp = 70,
  optimal_keystrokes = { "w", "c", "i", "w", "r", "i", "g", "h", "t", "\27" },
  optimal_keystrokes_alternates = {
    { "w", "c", "a", "w", "r", "i", "g", "h", "t", " ", "\27" },
  },
}
