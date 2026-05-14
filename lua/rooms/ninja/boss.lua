-- Ninja boss: 3-phase gauntlet. Phase 1 = named register yank/paste, Phase 2 = di" text object, Phase 3 = macro+ciw.
return {
  id = "ninja_boss",
  tier = "ninja",
  is_boss = true,
  command = "registers + text-objects + macros",
  title = "BOSS: The Void",
  description = "Three-phase trial. Registers, text objects, macro composition.",
  usage_tip = "Yank into named registers, delete with text objects, record complex macros.",
  base_xp = 600,
  time_limit = 270,
  phases = {
    {
      tip = "Phase 1: Yank line 1 into register a, replace line 3 with it",
      start_text = "alpha\nbeta\n[replace me]",
      target_text = "alpha\nbeta\nalpha",
      optimal_keystrokes = { '"', "a", "y", "y", "2", "j", "d", "d", '"', "a", "p" },
    },
    {
      tip = "Phase 2: Use di\" to strip quotes from each assignment",
      start_text = 'x = "foo"\ny = "bar"\nz = "baz"',
      target_text = "x = \"\"\ny = \"\"\nz = \"\"",
      optimal_keystrokes = { "d", "i", '"', "j", ".", "j", "." },
    },
    {
      tip = "Phase 3: Macro + text object to change var to const on all lines",
      start_text = "var a = 1\nvar b = 2\nvar c = 3\nvar d = 4",
      target_text = "const a = 1\nconst b = 2\nconst c = 3\nconst d = 4",
      optimal_keystrokes = { "q", "a", "c", "i", "w", "c", "o", "n", "s", "t", "\27", "j", "q", "3", "@", "a" },
    },
  },
}
