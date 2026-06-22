-- Warrior room: dt/df. Delete trailing args up to the close paren.
return {
  id = "warrior_delete_to",
  tier = "warrior",
  command = "dt<char> / df<char>",
  title = "Delete To Char: dt, df",
  description = "dt<char> deletes up to (not including) a char. df<char> deletes up to and including it.",
  usage_tip = "dt) deletes everything before the close paren. ct) does the same but leaves you in insert mode.",
  efficiency_hint = "dt<char> deletes up to a char; df<char> includes it.",
  before_example = "call(a, |b, junk)",
  after_example = "call(a, |b)",
  filetype = "lua",
  cursor_start = { row = 2, col = 11 },
  time_limit = 55,
  goal = "Delete the `, debug, trace` arguments before the close paren.",
  start_text = [[
local function send(msg)
  emit(msg, debug, trace)
end]],
  target_text = [[
local function send(msg)
  emit(msg)
end]],
  base_xp = 85,
  optimal_keystrokes = { "d", "t", ")" },
  optimal_keystrokes_alternates = {
    { "v", "t", ")", "d" },
  },
}
