-- Ninja room: :sort. Sort an unsorted import block alphabetically.
return {
  id = "ninja_sort",
  tier = "ninja",
  command = ":sort",
  title = "Sort Lines: :sort",
  description = "Sort lines in the buffer alphabetically (or numerically with n flag).",
  usage_tip = ":sort sorts whole file; visual+:sort sorts the selection. :sort! reverses. :sort u removes dupes.",
  before_example = "c\na\nb",
  after_example = "a\nb\nc",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 60,
  goal = "Sort the 5 require lines alphabetically (line 1 and line 7 stay put).",
  start_text = [[
-- imports
local zip = require("zip")
local fs  = require("fs")
local log = require("log")
local cfg = require("cfg")
local sys = require("sys")
-- end imports]],
  target_text = [[
-- imports
local cfg = require("cfg")
local fs  = require("fs")
local log = require("log")
local sys = require("sys")
local zip = require("zip")
-- end imports]],
  base_xp = 125,
  optimal_keystrokes = { "V", "4", "j", ":", "s", "o", "r", "t", "\r" },
  optimal_keystrokes_alternates = {
    { ":", "2", ",", "6", "s", "o", "r", "t", "\r" },
  },
}
