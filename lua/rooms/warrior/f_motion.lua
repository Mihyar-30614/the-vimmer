-- Warrior room: f/t (find-char jump). Navigation-only — player jumps to a colon in the line.
return {
  id = "warrior_f_motion",
  tier = "warrior",
  command = "f<char> / t<char>",
  title = "Find Char: f, t",
  description = "Jump to next occurrence of a char (f lands ON it, t lands BEFORE it)",
  before_example = "|jump to the colon: right here",
  after_example = "jump to the colon|: right here",
  usage_tip = "f: jumps to the colon. Use ; to repeat the jump forward, , to go back.",
  start_text = "jump to the colon: right here",
  target_text = "jump to the colon: right here",
  base_xp = 70,
  optimal_keystrokes = { "f", ":" },
}
