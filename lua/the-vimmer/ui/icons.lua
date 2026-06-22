-- Consistent icon glyphs for the-vimmer UI.
-- Default "unicode" uses widely-supported symbols; "ascii" is a plain-text fallback.
local M = {}

local SETS = {
  unicode = {
    hud      = "⚔",
    hp       = "♥",
    timer    = "⏱",
    streak   = "🔥",
    keys     = "⌨",
    target   = "◎",
    edit     = "✎",
    phase    = "◆",
    boss     = "⚔",
    star     = "★",
    lock     = "🔒",
    check    = "✓",
    cursor   = "▶",
    ready    = "○",
    heart    = "♥",
    freeze   = "❄",
    xp       = "✦",
    warn     = "⚠",
  },
  ascii = {
    hud      = ">",
    hp       = "HP",
    timer    = "T",
    streak   = "*",
    keys     = "K",
    target   = "T",
    edit     = "E",
    phase    = "P",
    boss     = "B",
    star     = "*",
    lock     = "X",
    check    = "+",
    cursor   = ">",
    ready    = "o",
    heart    = "H",
    freeze   = "F",
    xp       = "+",
    warn     = "!",
  },
}

function M.mode()
  local ok, root = pcall(require, "the-vimmer")
  if ok and root and type(root.config) == "table" and root.config.icons then
    return root.config.icons
  end
  return "unicode"
end

function M.get(name)
  local set = SETS[M.mode()] or SETS.unicode
  return set[name] or "?"
end

return M
