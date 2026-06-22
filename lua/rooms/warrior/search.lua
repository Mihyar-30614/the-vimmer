-- Warrior room: /, n, N. Search and edit at each match.
return {
  id = "warrior_search",
  tier = "warrior",
  command = "/ / n / N",
  title = "Search: /, n, N",
  description = "Search forward for a pattern (/), jump to next match (n), previous (N).",
  usage_tip = "/ followed by your search term then Enter. n hops to next match.",
  efficiency_hint = "Search with /pattern, then n/N to jump between hits.",
  before_example = "tag = |bug\ntag = bug",
  after_example = "tag = |ok\ntag = ok",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Find each `bug` (3 occurrences) and replace with `ok`.",
  start_text = [[
local a = "bug"
local b = "x"
local c = "bug"
local d = "y"
local e = "bug"]],
  target_text = [[
local a = "ok"
local b = "x"
local c = "ok"
local d = "y"
local e = "ok"]],
  base_xp = 95,
  optimal_keystrokes = { "/", "b", "u", "g", "\r", "c", "g", "n", "o", "k", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "/", "b", "u", "g", "\r", "c", "i", "w", "o", "k", "\27", "n", ".", "n", "." },
  },
}
