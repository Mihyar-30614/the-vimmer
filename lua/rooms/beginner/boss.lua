-- Beginner boss: 3-phase gauntlet on real Lua snippets.
return {
  id = "beginner_boss",
  tier = "beginner",
  is_boss = true,
  command = "hjkl + insert + delete",
  title = "BOSS: The Gauntlet",
  description = "Three-phase trial. All beginner skills tested.",
  usage_tip = "Use everything you have learned: navigate, insert, delete.",
  base_xp = 300,
  time_limit = 180,
  phases = {
    {
      tip = "Phase 1: Delete the three debug prints",
      filetype = "lua",
      cursor_start = { row = 2, col = 1 },
      goal = "Delete the three `print` lines in one command.",
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
      optimal_keystrokes = { "3", "d", "d" },
    },
    {
      tip = "Phase 2: Append `;` to every line",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Append `;` to every line.",
      start_text = [[
local a = 1
local b = 2
local c = 3
local d = 4]],
      target_text = [[
local a = 1;
local b = 2;
local c = 3;
local d = 4;]],
      optimal_keystrokes = { "A", ";", "\27", "j", "A", ";", "\27", "j", "A", ";", "\27", "j", "A", ";", "\27" },
    },
    {
      tip = "Phase 3: Fix the three typos",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Fix three typos: each line has a stray `q`. Replace each with the right letter.",
      start_text = [[
local qount = 0
local nqme = "x"
local pqrt = 80]],
      target_text = [[
local count = 0
local name = "x"
local port = 80]],
      optimal_keystrokes = { "f", "q", "r", "c", "j", "0", "f", "q", "r", "a", "j", "0", "f", "q", "r", "o" },
    },
  },
}
