-- Ninja boss: 3-phase Void. Registers + text objects + batch transform.
return {
  id = "ninja_boss",
  tier = "ninja",
  is_boss = true,
  command = "registers + text-objects + macros",
  title = "BOSS: The Void",
  description = "Three-phase trial. Registers, text objects, macro composition.",
  usage_tip = "Yank into named registers, surgically delete with text objects, batch-transform with :norm or cgn+.",
  base_xp = 700,
  time_limit = 300,
  phases = {
    {
      tip = "Phase 1: Yank line 1 to register a, drop line 4 via black hole, paste at end",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Yank line 1 to register a, delete line 4 with \"_dd, paste a at the end.",
      start_text = [[
local config = load_default()
local x = 1
local y = 2
local stale = nil
local z = 3]],
      target_text = [[
local config = load_default()
local x = 1
local y = 2
local z = 3
local config = load_default()]],
      optimal_keystrokes = { "\"", "a", "y", "y", "4", "G", "\"", "_", "d", "d", "G", "\"", "a", "p" },
    },
    {
      tip = "Phase 2: Clear string, drop parens group, change brace body",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Clear \"old\" content, remove (opts) group, change {a} body to {b}.",
      start_text = [[
local x = tag("old") and call(opts) and conf({ a })]],
      target_text = [[
local x = tag("") and call and conf({ b })]],
      optimal_keystrokes = { "f", "\"", "d", "i", "\"", "f", "(", "d", "a", "(", "f", "{", "c", "i", "{", " ", "b", " ", "\27" },
    },
    {
      tip = "Phase 3: Rename `tmp` to `out` across all 5 occurrences",
      filetype = "lua",
      cursor_start = { row = 1, col = 7 },
      goal = "Rename all 5 occurrences of `tmp` to `out`.",
      start_text = [[
local tmp = init()
local x = tmp * 2
local y = tmp + 1
local z = tmp - 3
return tmp]],
      target_text = [[
local out = init()
local x = out * 2
local y = out + 1
local z = out - 3
return out]],
      optimal_keystrokes = { "*", "N", "c", "g", "n", "o", "u", "t", "\27", ".", ".", ".", "." },
    },
  },
}
