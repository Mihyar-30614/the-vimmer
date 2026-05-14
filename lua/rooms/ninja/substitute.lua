-- Ninja room: :%s/old/new/g (global substitute). Player replaces all occurrences with a single ex command.
return {
  id = "ninja_substitute",
  tier = "ninja",
  command = ":%s/old/new/g",
  title = "Global Substitute",
  description = ":%s/pattern/replacement/g replaces all occurrences in the file",
  before_example = ":%s/hello/goodbye/g",
  after_example = "goodbye world …",
  usage_tip = "% means whole file. g flag means all occurrences per line. Omit g for first only.",
  start_text = "hello world\nhello vim\nhello neovim",
  target_text = "goodbye world\ngoodbye vim\ngoodbye neovim",
  base_xp = 105,
  time_limit = 55,
  optimal_keystrokes = { ":", "%", "s", "/", "h", "e", "l", "l", "o", "/", "g", "o", "o", "d", "b", "y", "e", "/", "g", "\r" },
}
