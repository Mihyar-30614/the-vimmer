-- Ninja room: gg/G/{/}. Jump between paragraphs to make targeted edits.
return {
  id = "ninja_complex_motions",
  tier = "ninja",
  command = "gg / G / { / }",
  title = "File Motions: gg, G, {, }",
  description = "Jump to file start (gg), file end (G), prev blank-separated block ({), next (}).",
  usage_tip = "G goes to end of file instantly. { and } jump between paragraphs in prose or code.",
  efficiency_hint = "{ and } jump by paragraph; gg/G reach the file ends.",
  before_example = "top\n\nmiddle\n\n|end",
  after_example = "TOP\n\nmiddle\n\nEND",
  filetype = "text",
  cursor_start = { row = 5, col = 1 },
  time_limit = 90,
  goal = "Upcase the first line, then jump to last paragraph and upcase its first line.",
  start_text = [[
section alpha

filler one
filler two

section beta

filler three
filler four

section gamma]],
  target_text = [[
SECTION ALPHA

filler one
filler two

section beta

filler three
filler four

SECTION GAMMA]],
  base_xp = 135,
  optimal_keystrokes = { "g", "g", "g", "U", "U", "G", "g", "U", "U" },
}
