return {
  id = "ninja_complex_motions",
  tier = "ninja",
  command = "gg / G / { / }",
  title = "File Motions: gg, G, {, }",
  description = "Jump to file start (gg), file end (G), prev blank-separated block ({), next (})",
  before_example = "|paragraph one\n\nparagraph two",
  after_example = "paragraph one\n\n|paragraph two",
  usage_tip = "G goes to end of file instantly. { and } jump between paragraphs in prose or code.",
  start_text = "paragraph one\n\nparagraph two\n\nparagraph three",
  target_text = "paragraph one\n\nparagraph two\n\nparagraph three",
  base_xp = 90,
  optimal_keystrokes = { "}", "}" },
}
