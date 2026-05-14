-- Warrior boss: 3-phase gauntlet. Phase 1 = f-motion delete, Phase 2 = visual block insert, Phase 3 = macro replay.
-- Unlocks ninja tier on clear.
return {
  id = "warrior_boss",
  tier = "warrior",
  is_boss = true,
  command = "f/t + visual block + macros",
  title = "BOSS: The Siege",
  description = "Three-phase trial. Search, visual block, and macros.",
  usage_tip = "Chain f-motion, visual block, then record and replay a macro.",
  base_xp = 450,
  time_limit = 225,
  phases = {
    {
      tip = "Phase 1: Use f-motion to reach each colon and delete it",
      start_text = "key1: val1\nkey2: val2\nkey3: val3",
      target_text = "key1 val1\nkey2 val2\nkey3 val3",
      optimal_keystrokes = { "f", ":", "x", "j", ";", "x", "j", ";", "x" },
    },
    {
      tip = "Phase 2: Visual block — add '# ' prefix to all 5 lines",
      start_text = "line one\nline two\nline three\nline four\nline five",
      target_text = "# line one\n# line two\n# line three\n# line four\n# line five",
      optimal_keystrokes = { "\22", "4", "j", "I", "#", " ", "\27" },
    },
    {
      tip = "Phase 3: Record macro qa, apply to remaining lines with 3@a",
      start_text = "foo\nfoo\nfoo\nfoo",
      target_text = "bar\nbar\nbar\nbar",
      optimal_keystrokes = { "q", "a", "c", "i", "w", "b", "a", "r", "\27", "j", "q", "3", "@", "a" },
    },
  },
}
