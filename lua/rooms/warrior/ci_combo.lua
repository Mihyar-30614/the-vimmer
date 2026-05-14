-- Warrior room: ci"/ci(/ci[ (change-inside combos). Player changes content inside multiple delimiter pairs.
return {
  id = "warrior_ci_combo",
  tier = "warrior",
  command = "ci\" / ci( / ci[",
  title = "Change Inside Combo",
  description = "ci<delim> changes everything inside the given delimiter pair",
  before_example = 'greet("|World")',
  after_example = 'greet("|Vim")',
  usage_tip = 'ci" changes inside double quotes. ci( changes inside parens. Works on any delimiter.',
  start_text = 'greet("World")\nmath.abs(-42)\ndata["key"]',
  target_text = 'greet("Vim")\nmath.abs(-1)\ndata["val"]',
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = { "c", "i", '"', "V", "i", "m", "\27", "j", "c", "i", "(", "-", "1", "\27", "j", "c", "i", "[", "v", "a", "l", "\27" },
}
