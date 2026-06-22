-- Grandmaster (nav): open a fold, then edit. foldmethod=indent via wo.
-- No `goal`: folds don't change text, so the reachability harness skips it.
return {
  id = "grandmaster_folds",
  tier = "grandmaster",
  command = "zR / za / zj",
  title = "Folds: Navigate & Edit",
  description = "Indent folds collapse blocks. zR opens all, za toggles one, zj jumps to the next fold.",
  before_example = "config = { ... }  (folded)",
  after_example = "timeout = 9  (opened & edited)",
  usage_tip = "zR opens every fold, zM closes them, za toggles the fold under the cursor.",
  efficiency_hint = "zR opens all folds at once instead of toggling each with za.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  wo = { foldmethod = "indent", foldenable = true, foldlevel = 0 },
  start_text = [[
config = {
    timeout = 5
}]],
  target_text = [[
config = {
    timeout = 9
}]],
  base_xp = 85,
  time_limit = 75,
  optimal_keystrokes = { "z", "R", "j", "$", "r", "9" },
}
