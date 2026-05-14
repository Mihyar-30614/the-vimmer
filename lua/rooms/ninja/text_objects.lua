-- Ninja room: di(/da[/ci{ (text objects). Player deletes "wrong_arg" inside parentheses with di(.
return {
  id = "ninja_text_objects",
  tier = "ninja",
  command = "di( / da[ / ci{",
  title = "Text Objects: di(, da[, ci{",
  description = "Operate on text inside or around delimiters without moving cursor first",
  before_example = "call(wrong_arg)",
  after_example = "call()",
  usage_tip = "i = inner (excludes delimiters), a = around (includes them). Works with d/c/y.",
  start_text = "call(wrong_arg)",
  target_text = "call()",
  base_xp = 100,
  optimal_keystrokes = { "f", "(", "d", "i", "(" },
}
