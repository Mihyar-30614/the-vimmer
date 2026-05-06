return {
  id = "ninja_advanced_macros",
  tier = "ninja",
  command = "macro + text objects + repeat",
  title = "Advanced Macros",
  description = "Combine macros with text objects for powerful repeatable bulk edits",
  before_example = 'var foo = "hello"\nvar bar = "world"',
  after_example = 'const foo = "hello"\nconst bar = "world"',
  usage_tip = 'Record: qa ciw const <Esc> j q. Then @a on next line. One macro replaces any word.',
  start_text = 'var foo = "hello"\nvar bar = "world"',
  target_text = 'const foo = "hello"\nconst bar = "world"',
  base_xp = 120,
  optimal_keystrokes = { "q", "a", "c", "i", "w", "c", "o", "n", "s", "t", "\27", "j", "q", "@", "a" },
}
