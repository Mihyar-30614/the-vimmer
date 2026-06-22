-- Warrior room: <C-v> + I. Insert a comment prefix on multiple lines at once.
return {
  id = "warrior_visual_block",
  tier = "warrior",
  command = "<C-v> + I",
  title = "Visual Block Insert",
  description = "<C-v> selects a vertical block. I inserts at every selected line simultaneously.",
  usage_tip = "<C-v> enters visual block. Select lines with j. I to insert. <Esc> applies to all.",
  efficiency_hint = "Ctrl-v selects a column; I inserts on every line at once.",
  before_example = "a()\nb()\nc()|",
  after_example = "// a()\n// b()\n// c()|",
  filetype = "javascript",
  cursor_start = { row = 1, col = 1 },
  time_limit = 50,
  goal = "Comment out the three function calls by prefixing each with `// `.",
  start_text = [[
fetchUser();
loadCache();
syncQueue();]],
  target_text = [[
// fetchUser();
// loadCache();
// syncQueue();]],
  base_xp = 100,
  optimal_keystrokes = { "\22", "j", "j", "I", "/", "/", " ", "\27" },
  optimal_keystrokes_alternates = {
    { "I", "/", "/", " ", "\27", "j", ".", "j", "." },
  },
}
