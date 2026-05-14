-- Warrior boss: 3-phase siege. Search rename, visual block comment, repeat-edit chain.
return {
  id = "warrior_boss",
  tier = "warrior",
  is_boss = true,
  command = "search + visual block + macros",
  title = "BOSS: The Siege",
  description = "Three-phase trial. Search, visual block, and macros.",
  usage_tip = "Chain * + cgn, then <C-v> + I, then qa ... q + @a (or . repeat).",
  base_xp = 500,
  time_limit = 240,
  phases = {
    {
      tip = "Phase 1: Rename `tmp` everywhere",
      filetype = "lua",
      cursor_start = { row = 1, col = 7 },
      goal = "Rename all 3 occurrences of `tmp` to `out`.",
      start_text = [[
local tmp = compute()
local x = tmp * 2
return tmp + x]],
      target_text = [[
local out = compute()
local x = out * 2
return out + x]],
      optimal_keystrokes = { "*", "N", "c", "g", "n", "o", "u", "t", "\27", ".", "." },
    },
    {
      tip = "Phase 2: Comment out three calls",
      filetype = "javascript",
      cursor_start = { row = 1, col = 1 },
      goal = "Prefix each of the three calls with `// `.",
      start_text = [[
init();
start();
stop();]],
      target_text = [[
// init();
// start();
// stop();]],
      optimal_keystrokes = { "\22", "j", "j", "I", "/", "/", " ", "\27" },
    },
    {
      tip = "Phase 3: Append `;` to every line (try qa A;<Esc>j q + @a, or A;<Esc>j + .)",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Append `;` to all four lines.",
      start_text = [[
local a = 1
local b = 2
local c = 3
local d = 4]],
      target_text = [[
local a = 1;
local b = 2;
local c = 3;
local d = 4;]],
      optimal_keystrokes = { "A", ";", "\27", "j", ".", "j", ".", "j", "." },
    },
  },
}
