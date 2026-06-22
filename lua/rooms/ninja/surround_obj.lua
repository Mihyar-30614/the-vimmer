-- Ninja room: di" / da( / ci{. Delete inside quotes, delete around parens, change inside braces.
return {
  id = "ninja_surround_obj",
  tier = "ninja",
  command = "di\" / da( / ci{",
  title = "Text Object Deletion",
  description = "di<x> deletes inside delimiter. da<x> deletes including the delimiter itself.",
  usage_tip = "di\" deletes inside quotes leaving them. da\" deletes quotes too. ci\" changes inside.",
  efficiency_hint = "Act inside or around pairs with di, da, ci plus the delimiter.",
  before_example = 'tag("old")|',
  after_example = 'tag("")|',
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 85,
  goal = "Clear the `\"old\"` string content, remove the `(opts)` group entirely, change `{a}` body to `{b}`.",
  start_text = [[
local x = tag("old") and call(opts) and conf({ a })]],
  target_text = [[
local x = tag("") and call and conf({ b })]],
  base_xp = 125,
  optimal_keystrokes = { "f", "\"", "d", "i", "\"", "f", "(", "d", "a", "(", "f", "{", "c", "i", "{", " ", "b", " ", "\27" },
}
