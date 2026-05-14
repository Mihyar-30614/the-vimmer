-- Ninja room: <C-o> / <C-i>. Use the jump list to ping-pong between two edit sites.
return {
  id = "ninja_jump_list",
  tier = "ninja",
  command = "<C-o> / <C-i>",
  title = "Jump History: <C-o>, <C-i>",
  description = "<C-o> jumps to older position in the jump list; <C-i> jumps to newer.",
  usage_tip = "Like browser back/forward. <C-i> = Tab; the play tab maps Tab to freeze powerup, so use <C-i> in your real editor.",
  before_example = "header (cursor)\n...\nfooter line",
  after_example = "HEADER\n...\nFOOTER",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 80,
  goal = "Jump to last line, upcase it, then <C-o> back to first line and upcase it too.",
  start_text = [[
local function header() end
local a = 1
local b = 2
local c = 3
local d = 4
local function footer() end]],
  target_text = [[
LOCAL FUNCTION HEADER() END
local a = 1
local b = 2
local c = 3
local d = 4
LOCAL FUNCTION FOOTER() END]],
  base_xp = 135,
  optimal_keystrokes = { "G", "g", "U", "U", "\15", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "G", "g", "U", "U", "g", "g", "g", "U", "U" },
  },
}
