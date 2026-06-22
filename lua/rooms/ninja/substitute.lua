-- Ninja room: :%s. Rename multiple occurrences with one ex command.
return {
  id = "ninja_substitute",
  tier = "ninja",
  command = ":%s/old/new/g",
  title = "Global Substitute",
  description = ":%s/pattern/replacement/g replaces all occurrences in the file.",
  usage_tip = "% means whole file. g flag means all occurrences per line. Omit g for first only.",
  efficiency_hint = ":%s/old/new/g replaces every match in the file.",
  before_example = "hello world|",
  after_example = "goodbye world|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Replace every `bug` with `ok` (5 occurrences).",
  start_text = [[
local a = "bug"
local b = "bug"
local c = "x"
local d = "bug bug"
local e = "bug"]],
  target_text = [[
local a = "ok"
local b = "ok"
local c = "x"
local d = "ok ok"
local e = "ok"]],
  base_xp = 120,
  optimal_keystrokes = { ":", "%", "s", "/", "b", "u", "g", "/", "o", "k", "/", "g", "\r" },
}
