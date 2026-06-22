-- Beginner room: dd/yy/p. Duplicate a config line, drop a stale one.
return {
  id = "beginner_dd_yp",
  tier = "beginner",
  command = "dd / yy / p",
  title = "Cut, Copy, Paste Lines",
  description = "dd cuts a line, yy copies it, p pastes below cursor",
  before_example = "alpha\n|stale",
  after_example = "alpha\nalpha|",
  usage_tip = "dd on a line deletes it into the register. p pastes it after cursor line.",
  efficiency_hint = "Use yy/dd on whole lines instead of selecting char by char.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 45,
  goal = "Duplicate line 1, then delete the stale third line (`-- old`).",
  start_text = [[
local PORT = 8080
local HOST = "localhost"
-- old
return { PORT = PORT, HOST = HOST }]],
  target_text = [[
local PORT = 8080
local PORT = 8080
local HOST = "localhost"
return { PORT = PORT, HOST = HOST }]],
  base_xp = 55,
  optimal_keystrokes = { "y", "y", "p", "j", "j", "d", "d" },
}
