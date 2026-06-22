-- Warrior room: cw + .. Rename three prefixed fields by changing the first, then repeating.
return {
  id = "warrior_change_chain",
  tier = "warrior",
  command = "cw / .",
  title = "Change and Repeat",
  description = "cw changes a word. . repeats the last change at the cursor position.",
  usage_tip = "cw replaces from cursor to end of word. . repeats it on the next match.",
  efficiency_hint = "cgn then . repeats your change at the next match.",
  before_example = "tmp_a = 1\ntmp_b = 2|",
  after_example = "final_a = 1\nfinal_b = 2|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Rename three `tmp_` field prefixes to `final_`.",
  start_text = [[
local record = {
  tmp_id = 1,
  tmp_name = "x",
  tmp_value = 0,
}]],
  target_text = [[
local record = {
  final_id = 1,
  final_name = "x",
  final_value = 0,
}]],
  base_xp = 95,
  optimal_keystrokes = { "/", "t", "m", "p", "\r", "c", "g", "n", "f", "i", "n", "a", "l", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "j", "f", "t", "c", "t", "_", "f", "i", "n", "a", "l", "\27", "j", "0", "f", "t", ".", "j", "0", "f", "t", "." },
  },
}
