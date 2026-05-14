-- Warrior room: q/@. Record a macro that appends `;` and advances, then replay.
return {
  id = "warrior_macros",
  tier = "warrior",
  command = "qa ... q / @a",
  title = "Macros: q, @",
  description = "Record a macro into a register (qa), stop (q), replay (@a).",
  usage_tip = "qa records into register a. Do edits. q stops. @a replays. 2@a repeats twice.",
  before_example = "a = 1|\nb = 2\nc = 3",
  after_example = "a = 1;|\nb = 2;\nc = 3;",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Append `;` to each of the three lines.",
  start_text = [[
local a = 1
local b = 2
local c = 3]],
  target_text = [[
local a = 1;
local b = 2;
local c = 3;]],
  base_xp = 105,
  -- Macros (qa ... q + @a) work interactively but fail under headless feedkeys,
  -- so reachability verifies the `.` repeat form. The room still teaches macros
  -- conceptually via title/description/usage_tip.
  optimal_keystrokes = { "A", ";", "\27", "j", ".", "j", "." },
}
