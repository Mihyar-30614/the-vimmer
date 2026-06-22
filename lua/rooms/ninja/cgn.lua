-- Ninja room: cgn + .. Repeatable rename across many occurrences without a macro.
return {
  id = "ninja_cgn",
  tier = "ninja",
  command = "cgn + .",
  title = "Change Next Match: cgn + .",
  description = "cgn changes the next search match. Combine with . to repeat across every occurrence — no :s needed.",
  usage_tip = "cgn = c + gn (gn selects next match). After cgn + <word> + Esc, dot repeats the whole operation on the next match.",
  efficiency_hint = "cgn changes the next match; . repeats it down the file.",
  before_example = "foo|\nfoo\nfoo",
  after_example = "bar|\nbar\nbar",
  filetype = "typescript",
  cursor_start = { row = 1, col = 17 },
  time_limit = 80,
  goal = "Rename `id` to `key` everywhere (5 occurrences).",
  start_text = [[
function lookup(id) {
  if (cache.has(id)) return cache.get(id);
  const row = db.find(id);
  cache.set(id, row);
  return row;
}]],
  target_text = [[
function lookup(key) {
  if (cache.has(key)) return cache.get(key);
  const row = db.find(key);
  cache.set(key, row);
  return row;
}]],
  base_xp = 145,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "k", "e", "y", "\27", ".", ".", ".", "." },
}
