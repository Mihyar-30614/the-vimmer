-- Ninja room: macro at scale. Macros fail under headless feedkeys, so reachability uses :norm.
-- The room still teaches macros via title/description.
return {
  id = "ninja_global_macro",
  tier = "ninja",
  command = "qa ... q + N@a (or :norm)",
  title = "Macro at Scale",
  description = "Record a macro into register a, then apply it to many lines with N@a.",
  usage_tip = "qa starts recording into 'a'. Do your edit. q stops. 7@a replays 7 times. Or use :'<,'>norm for a one-shot equivalent.",
  before_example = "a = 1|\nb = 2",
  after_example = "a = 1;|\nb = 2;",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 90,
  goal = "Append `;` to all 7 assignments in one batch.",
  start_text = [[
local a = 1
local b = 2
local c = 3
local d = 4
local e = 5
local f = 6
local g = 7]],
  target_text = [[
local a = 1;
local b = 2;
local c = 3;
local d = 4;
local e = 5;
local f = 6;
local g = 7;]],
  base_xp = 150,
  optimal_keystrokes = { ":", "%", "n", "o", "r", "m", " ", "A", ";", "\r" },
  optimal_keystrokes_alternates = {
    { "V", "G", ":", "n", "o", "r", "m", " ", "A", ";", "\r" },
    { "A", ";", "\27", "j", ".", "j", ".", "j", ".", "j", ".", "j", ".", "j", "." },
  },
}
