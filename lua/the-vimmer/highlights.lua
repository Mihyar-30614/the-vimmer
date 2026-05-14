-- All Vimmer highlight group definitions and derived helper functions.
-- hp_group / timer_group map numeric game state → a highlight group name.
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

-- Highlight groups whose meaning depends on red/green; remap under colorblind mode.
local PALETTE_DEFAULT = {
  VimmerHP_high     = { fg = "#50fa7b" },
  VimmerHP_mid      = { fg = "#ffb86c" },
  VimmerHP_low      = { fg = "#ff5555" },
  VimmerDamage      = { bg = "#5c1010", fg = "#ff8080" },
  VimmerWin         = { bg = "#50fa7b", fg = "#282a36" },
  VimmerDeath       = { bold = true, fg = "#ff5555" },
  VimmerTimerOk     = { bold = true, fg = "#50fa7b" },
  VimmerTimerDanger = { bold = true, fg = "#ff5555" },
  VimmerXP          = { bold = true, fg = "#f1fa8c" },
  VimmerCleared     = { fg = "#50fa7b" },
}

-- Wong/Okabe deuteranopia-safe palette for the colorblind opt-in.
local PALETTE_CB = {
  VimmerHP_high     = { fg = "#56b4e9" },
  VimmerHP_mid      = { fg = "#f0e442" },
  VimmerHP_low      = { fg = "#e69f00" },
  VimmerDamage      = { bg = "#3a2400", fg = "#e69f00" },
  VimmerWin         = { bg = "#56b4e9", fg = "#282a36" },
  VimmerDeath       = { bold = true, fg = "#d55e00" },
  VimmerTimerOk     = { bold = true, fg = "#56b4e9" },
  VimmerTimerDanger = { bold = true, fg = "#d55e00" },
  VimmerXP          = { bold = true, fg = "#f0e442" },
  VimmerCleared     = { fg = "#56b4e9" },
}

local function palette()
  local ok, root = pcall(require, "the-vimmer")
  if ok and root and root.config and root.config.colorblind then
    return PALETTE_CB
  end
  return PALETTE_DEFAULT
end

function M.setup()
  local hl = vim.api.nvim_set_hl
  local p = palette()
  hl(0, "VimmerTitle",        { bold = true, fg = "#ffffff" })
  hl(0, "VimmerTierBeginner", { bold = true, fg = "#8be9fd" })
  hl(0, "VimmerTierWarrior",  { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTierNinja",    { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerCleared",      p.VimmerCleared)
  hl(0, "VimmerLocked",       { fg = "#6272a4" })
  hl(0, "VimmerSelected",     { bold = true, reverse = true })
  hl(0, "VimmerXP",           p.VimmerXP)
  hl(0, "VimmerHP_high",      p.VimmerHP_high)
  hl(0, "VimmerHP_mid",       p.VimmerHP_mid)
  hl(0, "VimmerHP_low",       p.VimmerHP_low)
  hl(0, "VimmerWin",          p.VimmerWin)
  hl(0, "VimmerDeath",        p.VimmerDeath)
  hl(0, "VimmerCommand",      { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerExample",      { fg = "#8be9fd" })
  hl(0, "VimmerTimerOk",      p.VimmerTimerOk)
  hl(0, "VimmerTimerWarn",    { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTimerDanger",  p.VimmerTimerDanger)
  hl(0, "VimmerBoss",         { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerPhase",        { bold = true, bg = "#44475a", fg = "#ff79c6" })
  hl(0, "VimmerDamage",       p.VimmerDamage)
  hl(0, "VimmerCrit",         { bg = "#5c4a00", fg = "#ffd700" })
  hl(0, "VimmerTeachTip",     { fg = "#bcc4ea" })
  hl(0, "VimmerTeachFoot",    { fg = "#6272a4" })
end

return M
