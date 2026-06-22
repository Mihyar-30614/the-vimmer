-- Ninja room: :g. Delete every line matching a pattern with one ex command.
return {
  id = "ninja_global_delete",
  tier = "ninja",
  command = ":g/pattern/d",
  title = "Global Command: :g/pattern/d",
  description = "Execute an ex command on every line matching a pattern. :g/#/d deletes all lines containing #.",
  usage_tip = ":g/pat/d = delete matching lines. :g/pat/normal <cmd> runs any normal command. :v/pat/d keeps only matching lines.",
  efficiency_hint = ":g/pattern/d deletes every matching line at once.",
  before_example = "real\nDEBUG\nreal\nDEBUG",
  after_example = "real\nreal",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Strip every line containing `print` from this function.",
  start_text = [[
local function run()
  print("start")
  local x = 1
  print("step 1")
  local y = 2
  print("step 2")
  return x + y
end]],
  target_text = [[
local function run()
  local x = 1
  local y = 2
  return x + y
end]],
  base_xp = 130,
  optimal_keystrokes = { ":", "g", "/", "p", "r", "i", "n", "t", "/", "d", "\r" },
}
