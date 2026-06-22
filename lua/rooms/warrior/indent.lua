-- Warrior room: >>/<<. Indent three lines under an if block.
return {
  id = "warrior_indent",
  tier = "warrior",
  command = ">> / <<",
  title = "Indent: >>, <<",
  description = ">> indents the current line by one shiftwidth; << dedents.",
  usage_tip = "Repeat with . or use ranges: V}>  indents a paragraph.",
  efficiency_hint = ">> indents a line; press . to repeat it on the next.",
  before_example = "if x then\nfoo()\nend|",
  after_example = "if x then\n  foo()\nend|",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 60,
  goal = "Indent the three body lines under the `if` by one level.",
  start_text = [[
if ready then
log.info("starting")
run_task()
log.info("done")
end]],
  target_text = [[
if ready then
  log.info("starting")
  run_task()
  log.info("done")
end]],
  base_xp = 80,
  optimal_keystrokes = { ">", ">", "j", ".", "j", "." },
  optimal_keystrokes_alternates = {
    { "V", "2", "j", ">" },
    { "3", ">", ">" },
  },
  bo = { shiftwidth = 2, expandtab = true },
}
