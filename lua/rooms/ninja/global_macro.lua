-- Ninja room: qa...q + N@a (macro at scale). Player records a macro then applies it to 5 lines with 5@a.
return {
  id = "ninja_global_macro",
  tier = "ninja",
  command = "qa … q + N@a",
  title = "Macro at Scale",
  description = "Record a macro into register a, then apply it to 7 more lines with 7@a",
  before_example = "foo\n|foo\nfoo",
  after_example = "bar\n|bar\nbar",
  usage_tip = "qa starts recording into 'a'. Do your edit. q stops. 7@a replays 7 times.",
  start_text = "foo\nfoo\nfoo\nfoo\nfoo\nfoo\nfoo\nfoo",
  target_text = "bar\nbar\nbar\nbar\nbar\nbar\nbar\nbar",
  base_xp = 110,
  time_limit = 90,
  optimal_keystrokes = { "q", "a", "c", "i", "w", "b", "a", "r", "\27", "j", "q", "7", "@", "a" },
}
