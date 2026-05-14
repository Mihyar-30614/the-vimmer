-- Warrior room: * / # (search word under cursor). Navigation-only — player jumps to next occurrence without typing the word.
return {
  id = "warrior_star_search",
  tier = "warrior",
  command = "* / #",
  title = "Search Under Cursor: * and #",
  description = "* searches forward for the word under cursor. # searches backward. No typing required.",
  before_example = "|apple orange apple",
  after_example = "apple orange |apple",
  usage_tip = "* is faster than /word<Enter>. Combine with n/N to jump between matches, or cgn to change each one.",
  start_text = "apple orange apple banana apple",
  target_text = "apple orange apple banana apple",
  base_xp = 60,
  optimal_keystrokes = { "*" },
}
