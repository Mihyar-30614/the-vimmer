-- Warrior room: gU / gu. Upcase SQL keywords scattered across a query.
return {
  id = "warrior_case_ops",
  tier = "warrior",
  command = "gU{motion} / gu{motion} / guu",
  title = "Case Operators: gU, gu",
  description = "gU uppercases, gu lowercases. Combine with any motion or double for whole line: gUU / guu.",
  usage_tip = "guu = lowercase line, gUU = uppercase line. gUw = uppercase next word. g~ toggles case.",
  efficiency_hint = "Use gU{motion} (gUw) to change case over a whole word.",
  before_example = "|select",
  after_example = "|SELECT",
  filetype = "sql",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Uppercase the SQL keywords `select`, `from`, `where`.",
  start_text = [[
select id, name
from users
where active = true]],
  target_text = [[
SELECT id, name
FROM users
WHERE active = true]],
  base_xp = 85,
  optimal_keystrokes = { "g", "U", "w", "j", "0", "g", "U", "w", "j", "0", "g", "U", "w" },
  optimal_keystrokes_alternates = {
    { "g", "U", "i", "w", "j", "0", "g", "U", "i", "w", "j", "0", "g", "U", "i", "w" },
    { "v", "e", "U", "j", "0", "v", "e", "U", "j", "0", "v", "e", "U" },
  },
}
