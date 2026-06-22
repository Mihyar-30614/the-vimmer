-- Ninja room: macros + text objects. Verified via cgn + . since macros fail under headless feedkeys.
return {
  id = "ninja_advanced_macros",
  tier = "ninja",
  command = "qa ciw ... q + @a (or cgn + .)",
  title = "Advanced Macros",
  description = "Combine macros with text objects for powerful repeatable bulk edits.",
  usage_tip = "Record: qa ciw new <Esc> n q. Then @a repeats. The cgn+. pattern achieves the same without recording.",
  efficiency_hint = "cgn + . (or a macro) repeats an edit across all matches.",
  before_example = "let foo|\nlet bar",
  after_example = "const foo|\nconst bar",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 100,
  goal = "Replace the placeholder `let` with `const` across all 4 variable declarations.",
  start_text = [[
let foo = "hello"
let bar = "world"
let baz = "from"
let qux = "vim"]],
  target_text = [[
const foo = "hello"
const bar = "world"
const baz = "from"
const qux = "vim"]],
  base_xp = 155,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "c", "o", "n", "s", "t", "\27", ".", ".", "." },
  optimal_keystrokes_alternates = {
    { ":", "%", "s", "/", "l", "e", "t", "/", "c", "o", "n", "s", "t", "/", "g", "\r" },
    { ":", "%", "n", "o", "r", "m", " ", "c", "i", "w", "c", "o", "n", "s", "t", "\r" },
  },
}
