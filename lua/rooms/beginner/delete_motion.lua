-- Beginner room: d{motion}. Remove an unused param from a function signature.
return {
  id = "beginner_delete_motion",
  tier = "beginner",
  command = "d{motion}",
  title = "Delete by Motion: d + w/W/$/0",
  description = "d is an operator — combine it with any motion: dw deletes a word, dW a big-word, d$ to line end",
  before_example = "fn(a, |unused, b)",
  after_example = "fn(a, |b)",
  usage_tip = "d + motion is the Vim grammar. dw = delete word, dW = delete WORD (no punctuation split), d$ = delete to end.",
  efficiency_hint = "Combine d with a motion (dw) instead of deleting char by char.",
  filetype = "lua",
  cursor_start = { row = 1, col = 26 },
  goal = "Remove the unused `tmp,` parameter from the function signature.",
  start_text = [[
local function copy(src, tmp, dst)
  return dst
end]],
  target_text = [[
local function copy(src, dst)
  return dst
end]],
  base_xp = 50,
  optimal_keystrokes = { "d", "w", "d", "w" },
  optimal_keystrokes_alternates = {
    { "2", "d", "w" },
    { "d", "W" },
  },
}
