-- Warrior room: v/V. Select a block of lines, delete them.
return {
  id = "warrior_visual",
  tier = "warrior",
  command = "v / V",
  title = "Visual Mode: v, V",
  description = "Select: characters (v), whole lines (V). Then apply an operator.",
  usage_tip = "v enters char-wise visual. V is line-wise. Extend with motion keys, then d/c/y.",
  efficiency_hint = "V selects whole lines, then one d deletes them all.",
  before_example = "keep\n|drop\ndrop\nkeep",
  after_example = "keep\n|keep",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 50,
  goal = "Delete the two `unused` local declarations.",
  start_text = [[
local function calc()
  local unused = 1
  local unused_too = 2
  return result
end]],
  target_text = [[
local function calc()
  return result
end]],
  base_xp = 80,
  optimal_keystrokes = { "V", "j", "d" },
  optimal_keystrokes_alternates = {
    { "2", "d", "d" },
  },
}
