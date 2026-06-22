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

-- Resolve the active theme + colorblind config and apply every Vimmer*
-- highlight group. Color data lives in the-vimmer.themes; this only wires
-- the user's config into it. Default config reproduces the original look.
function M.setup()
  local themes = require("the-vimmer.themes")
  local cfg = {}
  local ok, root = pcall(require, "the-vimmer")
  if ok and root and type(root.config) == "table" then cfg = root.config end

  local colors = themes.colors({
    theme = cfg.theme,
    colorblind = cfg.colorblind == true,
  })
  for group, spec in pairs(themes.build_groups(colors)) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

return M
