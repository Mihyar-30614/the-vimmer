-- Warrior room: dt<char> / df<char> (delete to/find char). Player clears args inside parens with dt).
return {
  id = "warrior_delete_to",
  tier = "warrior",
  command = "dt<char> / df<char>",
  title = "Delete To Char: dt, df",
  description = "dt<char> deletes up to (not including) a char. df<char> deletes up to and including it.",
  before_example = "print(|JUNK)",
  after_example = "print()",
  usage_tip = "dt) deletes everything before the closing paren. ct) does the same but leaves you in insert mode.",
  start_text = "print(JUNK)",
  target_text = "print()",
  base_xp = 75,
  optimal_keystrokes = { "f", "J", "d", "t", ")" },
  optimal_keystrokes_alternates = {
    { "f", "(", "l", "d", "t", ")" },
  },
}
