return {
  id = "beginner_boss",
  tier = "beginner",
  is_boss = true,
  command = "hjkl + insert + delete",
  title = "BOSS: The Gauntlet",
  description = "Three-phase trial. All beginner skills tested.",
  usage_tip = "Use everything you have learned: navigate, insert, delete.",
  base_xp = 300,
  time_limit = 120,
  phases = {
    {
      tip = "Phase 1: Delete the X lines",
      start_text = "keep\nX\nkeep\nX\nkeep\nX\nkeep",
      target_text = "keep\n\nkeep\n\nkeep\n\nkeep",
      optimal_keystrokes = { "j", "d", "d" },
    },
    {
      tip = "Phase 2: Append ! to every line",
      start_text = "alpha\nbeta\ngamma\ndelta",
      target_text = "alpha!\nbeta!\ngamma!\ndelta!",
      optimal_keystrokes = { "A", "!", "\27", "j" },
    },
    {
      tip = "Phase 3: Reorder lines to match target",
      start_text = "third\nfirst\nsecond",
      target_text = "first\nsecond\nthird",
      optimal_keystrokes = { "d", "d", "p", "j", "k", "G", "p" },
    },
  },
}
