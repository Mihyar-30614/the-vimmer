-- Beginner room: gg / G (file boundaries). Navigation-only — pressing G is enough.
return {
  id = "beginner_file_boundaries",
  tier = "beginner",
  command = "gg / G",
  title = "File Boundaries: gg, G",
  description = "gg jumps to the first line; G jumps to the last line",
  before_example = "|line 1\nline 5",
  after_example = "line 1\n|line 5",
  usage_tip = "G = last line. 5G = line 5. gg = first line. Faster than counting j.",
  start_text = "first line\nfiller\nfiller\nfiller\nlast line",
  target_text = "first line\nfiller\nfiller\nfiller\nlast line",
  base_xp = 45,
  optimal_keystrokes = { "G" },
}
