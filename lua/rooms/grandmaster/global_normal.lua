-- Grandmaster: run a normal-mode edit on every matching line with :g//normal.
return {
  id = "grandmaster_global_normal",
  tier = "grandmaster",
  command = ":g/TODO/normal A!",
  title = "Global + Normal",
  description = ":g/pat/normal <keys> runs normal-mode keys on every matching line.",
  before_example = "TODO fix",
  after_example = "TODO fix!",
  usage_tip = "Combine :g with :normal to batch the same edit across matches.",
  efficiency_hint = ":g/TODO/normal A! appends to every matching line in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Append ! to every line containing TODO using :g + normal.",
  start_text = [[
keep this
TODO fix
keep that
TODO test]],
  target_text = [[
keep this
TODO fix!
keep that
TODO test!]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = {
    ":", "g", "/", "T", "O", "D", "O", "/", "n", "o", "r", "m", "a", "l", " ", "A", "!", "\r",
  },
}
