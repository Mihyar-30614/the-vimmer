-- Warrior room: * + cgn + .. Star-search the word under cursor, then replace each.
return {
  id = "warrior_star_search",
  tier = "warrior",
  command = "* / cgn / .",
  title = "Search Under Cursor: * with cgn",
  description = "* searches forward for the word under cursor. cgn changes the next match. . repeats.",
  usage_tip = "* is faster than /word<CR>. cgn + . is the canonical rename pattern.",
  before_example = "|TODO line 1\nTODO line 2",
  after_example = "|DONE line 1\nDONE line 2",
  filetype = "lua",
  cursor_start = { row = 1, col = 4 },
  time_limit = 60,
  goal = "Rename all `TODO` (3 occurrences) to `DONE`.",
  start_text = [[
-- TODO: fetch data
local x = 1
-- TODO: validate
local y = 2
-- TODO: persist]],
  target_text = [[
-- DONE: fetch data
local x = 1
-- DONE: validate
local y = 2
-- DONE: persist]],
  base_xp = 100,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "D", "O", "N", "E", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "*", "N", "c", "i", "w", "D", "O", "N", "E", "\27", "n", ".", "n", "." },
  },
}
