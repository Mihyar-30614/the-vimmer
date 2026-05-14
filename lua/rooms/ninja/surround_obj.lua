-- Ninja room: di"/da(/ci{ (text object deletion). Player deletes inside quoted strings using text objects.
return {
  id = "ninja_surround_obj",
  tier = "ninja",
  command = "di\" / da( / ci{",
  title = "Text Object Deletion",
  description = "di<x> deletes inside delimiter. da<x> deletes including the delimiter itself.",
  before_example = 'fn(compute("|hello", (x+1)))',
  after_example = 'fn(compute("|hello", ()))',
  usage_tip = 'di" deletes inside quotes leaving them. da" deletes quotes too. ci" changes inside.',
  start_text = 'fn(compute("hello", (x + 1)))',
  target_text = 'fn(compute("hello", ()))',
  base_xp = 120,
  time_limit = 60,
  optimal_keystrokes = { "2", "f", "(", "d", "i", "(" },
}
