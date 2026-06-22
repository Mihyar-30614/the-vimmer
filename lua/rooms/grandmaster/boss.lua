-- Grandmaster boss: 3-phase trial. Capture-sub, global-normal, copy/move reshape.
return {
  id = "grandmaster_boss",
  tier = "grandmaster",
  is_boss = true,
  command = "captures + :g/normal + :t/:m",
  title = "BOSS: The Ex Machina",
  description = "Three-phase trial of ex-command mastery: captures, global edits, line surgery.",
  usage_tip = "Reformat with capture groups, batch-edit with :g/normal, reshape with :m and :t.",
  base_xp = 950,
  time_limit = 360,
  phases = {
    {
      tip = "Phase 1: Reformat 'Last, First' into 'First Last' on every line",
      filetype = "text",
      cursor_start = { row = 1, col = 1 },
      goal = "Turn 'Last, First' into 'First Last' on every line with capture groups.",
      start_text = [[
Smith, John
Doe, Jane]],
      target_text = [[
John Smith
Jane Doe]],
      optimal_keystrokes = {
        ":", "%", "s", "/", "\\", "(", "\\", "w", "\\", "+", "\\", ")", ",", " ",
        "\\", "(", "\\", "w", "\\", "+", "\\", ")", "/", "\\", "2", " ", "\\", "1", "/", "\r",
      },
    },
    {
      tip = "Phase 2: Append '();' to every line beginning with fn",
      filetype = "text",
      cursor_start = { row = 1, col = 1 },
      goal = "Append '();' to each line starting with fn using :g + normal.",
      start_text = [[
keep
fn alpha
fn beta]],
      target_text = [[
keep
fn alpha();
fn beta();]],
      optimal_keystrokes = {
        ":", "g", "/", "^", "f", "n", "/", "n", "o", "r", "m", "a", "l", " ",
        "A", "(", ")", ";", "\r",
      },
    },
    {
      tip = "Phase 3: Move line 2 to the top, then copy the new top line to the end",
      filetype = "text",
      cursor_start = { row = 1, col = 1 },
      goal = "Move line 2 to the top with :m, then copy the top line to the end with :t.",
      start_text = [[
mid
top]],
      target_text = [[
top
mid
top]],
      optimal_keystrokes = {
        ":", "2", "m", "0", "\r", ":", "1", "t", "$", "\r",
      },
    },
  },
}
