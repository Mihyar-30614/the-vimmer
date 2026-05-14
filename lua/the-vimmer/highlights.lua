-- All Vimmer highlight group definitions and derived helper functions.
-- hp_group / timer_group / combo_group map numeric game state → a highlight group name.
-- build_diff_line handles multi-byte-safe layout for the teach-screen before→after row.
-- visible_len counts Unicode codepoints (not bytes) to correctly measure display width.
local M = {}

-- Map HP value to one of three highlight groups (green / orange / red).
function M.hp_group(hp)
  if hp > 60 then return "VimmerHP_high"
  elseif hp > 30 then return "VimmerHP_mid"
  else return "VimmerHP_low" end
end

-- Map remaining/total time to a colour: >50% green, >25% orange, else red.
function M.timer_group(remaining, total)
  if not total or total == 0 then return "VimmerTimerOk" end
  local pct = remaining / total
  if pct > 0.5 then return "VimmerTimerOk"
  elseif pct > 0.25 then return "VimmerTimerWarn"
  else return "VimmerTimerDanger" end
end

-- Count Unicode codepoints by walking UTF-8 byte lengths (1/2/3/4-byte sequences).
local function visible_len(s)
  local len = 0
  local i = 1
  while i <= #s do
    local b = s:byte(i)
    if b < 0x80 then i = i + 1
    elseif b < 0xe0 then i = i + 2
    elseif b < 0xf0 then i = i + 3
    else i = i + 4 end
    len = len + 1
  end
  return len
end

-- Build a "before → after" display line for the teach screen.
-- Returns a single-element table when it fits on one line, two elements when it must wrap.
-- | in room data renders as ▌ (cursor indicator); \n renders as ↵.
function M.build_diff_line(before_ex, after_ex, max_w)
  local before_disp = before_ex:gsub("\n", " ↵ "):gsub("|", "▌")
  local after_disp = after_ex:gsub("\n", " ↵ "):gsub("|", "▌")
  local combined = before_disp .. "  →  " .. after_disp
  if visible_len(combined) <= max_w then
    return { combined }
  end
  return { before_disp, "→  " .. after_disp }
end

-- Return a highlight group for the combo counter, or nil when combo is below 5.
function M.combo_group(combo)
  if combo >= 20 then return "VimmerComboCrit"
  elseif combo >= 10 then return "VimmerComboFire"
  elseif combo >= 5 then return "VimmerPhase"
  else return nil end
end

function M.setup()
  local hl = vim.api.nvim_set_hl
  hl(0, "VimmerTitle",        { bold = true, fg = "#ffffff" })
  hl(0, "VimmerTierBeginner", { bold = true, fg = "#8be9fd" })
  hl(0, "VimmerTierWarrior",  { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTierNinja",    { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerCleared",      { fg = "#50fa7b" })
  hl(0, "VimmerLocked",       { fg = "#6272a4" })
  hl(0, "VimmerSelected",     { bold = true, reverse = true })
  hl(0, "VimmerXP",           { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerHP_high",      { fg = "#50fa7b" })
  hl(0, "VimmerHP_mid",       { fg = "#ffb86c" })
  hl(0, "VimmerHP_low",       { fg = "#ff5555" })
  hl(0, "VimmerWin",          { bg = "#50fa7b", fg = "#282a36" })
  hl(0, "VimmerDeath",        { bold = true, fg = "#ff5555" })
  hl(0, "VimmerCommand",      { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerExample",      { fg = "#8be9fd" })
  hl(0, "VimmerTimerOk",      { bold = true, fg = "#50fa7b" })
  hl(0, "VimmerTimerWarn",    { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTimerDanger",  { bold = true, fg = "#ff5555" })
  hl(0, "VimmerBoss",         { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerPhase",        { bold = true, bg = "#44475a", fg = "#ff79c6" })
  hl(0, "VimmerDamage",       { bg = "#5c1010", fg = "#ff8080" })
  hl(0, "VimmerRegen",        { bg = "#0d3b1a", fg = "#80ff99" })
  hl(0, "VimmerCrit",         { bg = "#5c4a00", fg = "#ffd700" })
  hl(0, "VimmerComboFire",    { bold = true,    fg = "#ff8c00" })
  hl(0, "VimmerComboCrit",    { bold = true,    fg = "#ff00cc" })
  hl(0, "VimmerTeachTip",     { fg = "#bcc4ea" })
  hl(0, "VimmerTeachFoot",    { fg = "#6272a4" })
end

return M
