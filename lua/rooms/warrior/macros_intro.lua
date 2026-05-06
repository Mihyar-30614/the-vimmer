return {
  id = "warrior_macros",
  tier = "warrior",
  command = "q<reg> to record, @<reg> to replay",
  title = "Macros: q, @",
  description = "Record a macro into a register (qa), stop (q), replay it (@a)",
  before_example = "line one\nline two\nline three",
  after_example = "- line one\n- line two\n- line three",
  usage_tip = "qa records into register a. Do edits. q stops. @a replays. 2@a repeats twice.",
  start_text = "line one\nline two\nline three",
  target_text = "- line one\n- line two\n- line three",
  base_xp = 90,
  optimal_keystrokes = { "q", "a", "I", "-", " ", "\27", "j", "q", "2", "@", "a" },
}
