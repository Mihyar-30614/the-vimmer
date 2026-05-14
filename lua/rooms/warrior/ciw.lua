-- Warrior room: ciw / cgn. Rename a parameter across a small function body.
return {
  id = "warrior_ciw",
  tier = "warrior",
  command = "ciw / cgn",
  title = "Rename Param: ciw, cgn",
  description = "ciw deletes word under cursor and enters insert mode. cgn changes the next search match. . repeats.",
  before_example = "the |wrong word here",
  after_example = "the |right word here",
  usage_tip = "ciw works anywhere on the word. Pair with * to seed a search, then cgn + . to repeat the rename.",
  filetype = "typescript",
  cursor_start = { row = 1, col = 20 },
  time_limit = 60,
  goal = "Rename param `userId` to `accountId` (3 occurrences).",
  start_text = [[
function fetchUser(userId) {
  const cache = userCache.get(userId);
  if (!cache) return loadUser(userId);
  return cache;
}]],
  target_text = [[
function fetchUser(accountId) {
  const cache = userCache.get(accountId);
  if (!cache) return loadUser(accountId);
  return cache;
}]],
  base_xp = 90,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "a", "c", "c", "o", "u", "n", "t", "I", "d", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "c", "i", "w", "a", "c", "c", "o", "u", "n", "t", "I", "d", "\27", "n", ".", "n", "." },
  },
}
