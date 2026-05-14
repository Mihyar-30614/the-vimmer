-- Beginner room: count prefix. Delete a 3-line debug block in one command.
return {
  id = "beginner_counts",
  tier = "beginner",
  command = "N<motion> / Ndd",
  title = "Numeric Prefixes",
  description = "Any motion or operator can be prefixed with a count: 3w, 2dd, 5x",
  before_example = "keep|\ndrop\ndrop\ndrop\nkeep",
  after_example = "keep|\nkeep",
  usage_tip = "4w jumps 4 words. 2dd deletes 2 lines. d$ deletes to end of line.",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 40,
  goal = "Delete the three `print` debug lines in one command.",
  start_text = [[
local function run()
  print("a")
  print("b")
  print("c")
  return true
end]],
  target_text = [[
local function run()
  return true
end]],
  base_xp = 50,
  optimal_keystrokes = { "3", "d", "d" },
}
