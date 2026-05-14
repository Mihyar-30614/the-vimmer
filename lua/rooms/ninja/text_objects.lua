-- Ninja room: text objects. Operate inside three different delimiter pairs.
return {
  id = "ninja_text_objects",
  tier = "ninja",
  command = "di( / da[ / ci{",
  title = "Text Objects: di(, da[, ci{",
  description = "Operate on text inside or around delimiters without moving cursor first.",
  usage_tip = "i = inner (excludes delimiters), a = around (includes them). Works with d/c/y.",
  before_example = "fn(|args)",
  after_example = "fn(|)",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 90,
  goal = "Clear args inside `()`, remove the `[bad]` index entirely, and replace `{old}` body with `{new}`.",
  start_text = [[
local result = compute(a, b, c)
local item = list[bad]
local cfg = { old }]],
  target_text = [[
local result = compute()
local item = list
local cfg = { new }]],
  base_xp = 130,
  optimal_keystrokes = { "f", "(", "d", "i", "(", "j", "0", "f", "[", "d", "a", "[", "j", "0", "f", "{", "c", "i", "{", " ", "n", "e", "w", " ", "\27" },
}
