-- Warrior room: >> / << (indent / dedent line). Pins shiftwidth=2 expandtab=true via bo
-- so the indent inserts exactly two spaces regardless of the player's global config.
return {
  id = "warrior_indent",
  tier = "warrior",
  command = ">> / <<",
  title = "Indent: >>, <<",
  description = ">> indents the current line by one shiftwidth; << dedents",
  before_example = "|return 1",
  after_example = "  |return 1",
  usage_tip = "Repeat with . or use ranges: V}>  indents a paragraph.",
  start_text = "fn foo():\nreturn 1\nreturn 2",
  target_text = "fn foo():\n  return 1\n  return 2",
  bo = { shiftwidth = 2, expandtab = true },
  base_xp = 75,
  optimal_keystrokes = { "j", ">", ">", "j", ">", ">" },
}
