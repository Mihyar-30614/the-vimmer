-- Beginner room: gg/G. Drop last-line stub, then tag the header.
return {
  id = "beginner_file_boundaries",
  tier = "beginner",
  command = "gg / G",
  title = "File Boundaries: gg, G",
  description = "gg jumps to the first line; G jumps to the last line",
  before_example = "-- header|",
  after_example = "-- header!|",
  usage_tip = "G = last line. 5G = line 5. gg = first line. Faster than counting j.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Delete the last line `TODO`, then append `!` to the first line.",
  start_text = [[
-- module: ping
local M = {}
function M.ping() return "pong" end
return M
TODO]],
  target_text = [[
-- module: ping!
local M = {}
function M.ping() return "pong" end
return M]],
  base_xp = 45,
  optimal_keystrokes = { "G", "d", "d", "g", "g", "A", "!", "\27" },
}
