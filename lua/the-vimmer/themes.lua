-- Color themes for the-vimmer.
--
-- A *theme* is a flat table of friendly color roles (xp, hp_high, boss, ...)
-- holding hex strings. `build_groups` turns a resolved role table into the
-- concrete Vimmer* highlight-group specs that `highlights.setup` applies.
--
-- This module is pure data + table juggling and is safe to require headlessly.
-- The only Neovim dependency is `default_reader` (used by the "auto" theme),
-- which is guarded and only called from inside setup at runtime.
local M = {}

-- Dracula-derived defaults. This reproduces the original hardcoded look exactly.
local DRACULA = {
  title            = "#ffffff",
  xp               = "#f1fa8c",
  command          = "#f1fa8c",
  example          = "#8be9fd",
  tier_beginner    = "#8be9fd",
  tier_warrior     = "#ffb86c",
  tier_ninja       = "#ff79c6",
  tier_grandmaster = "#bd93f9",
  cleared          = "#50fa7b",
  locked           = "#6272a4",
  hp_high          = "#50fa7b",
  hp_mid           = "#ffb86c",
  hp_low           = "#ff5555",
  win_bg           = "#50fa7b",
  win_fg           = "#282a36",
  death            = "#ff5555",
  timer_ok         = "#50fa7b",
  timer_warn       = "#ffb86c",
  timer_danger     = "#ff5555",
  boss             = "#ff79c6",
  phase_bg         = "#44475a",
  phase_fg         = "#ff79c6",
  damage_bg        = "#5c1010",
  damage_fg        = "#ff8080",
  crit_bg          = "#5c4a00",
  crit_fg          = "#ffd700",
  teach_tip        = "#bcc4ea",
  teach_foot       = "#6272a4",
  panel_bg         = "#383a59",
  section          = "#bd93f9",
  menu_sel_bg      = "#44475a",
  menu_sel_fg      = "#f8f8f2",
  badge            = "#ffb86c",
}

-- Wong/Okabe deuteranopia-safe overrides. Applied on top of any chosen theme,
-- replacing only the roles whose meaning depends on red/green discrimination.
local CB_OVERLAY = {
  hp_high      = "#56b4e9",
  hp_mid       = "#f0e442",
  hp_low       = "#e69f00",
  damage_bg    = "#3a2400",
  damage_fg    = "#e69f00",
  win_bg       = "#56b4e9",
  death        = "#d55e00",
  timer_ok     = "#56b4e9",
  timer_danger = "#d55e00",
  xp           = "#f0e442",
  cleared      = "#56b4e9",
}

-- For the "auto" theme: friendly role -> standard colorscheme group to sample
-- the foreground color from. Roles absent here keep their dracula fallback.
local AUTO_SAMPLE = {
  title            = "Title",
  xp               = "Function",
  command          = "Function",
  example          = "String",
  tier_beginner    = "Identifier",
  tier_warrior     = "Constant",
  tier_ninja       = "Statement",
  tier_grandmaster = "Type",
  cleared          = "String",
  locked           = "Comment",
  teach_foot       = "Comment",
  hp_high          = "String",
  hp_mid           = "WarningMsg",
  hp_low           = "ErrorMsg",
  death            = "ErrorMsg",
  timer_ok         = "String",
  timer_warn       = "WarningMsg",
  timer_danger     = "ErrorMsg",
  boss             = "Statement",
  damage_fg        = "ErrorMsg",
  crit_fg          = "WarningMsg",
}

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function merge(base, override)
  local out = copy(base)
  if type(override) == "table" then
    for k, v in pairs(override) do out[k] = v end
  end
  return out
end

-- Read a foreground color from a live highlight group as "#rrggbb", or nil.
-- Works across Neovim 0.9+ (nvim_get_hl) and 0.8 (nvim_get_hl_by_name).
function M.default_reader(group)
  local fg
  local ok, hl = pcall(function()
    if vim.api.nvim_get_hl then
      return vim.api.nvim_get_hl(0, { name = group, link = false })
    end
  end)
  if ok and type(hl) == "table" then fg = hl.fg end
  if type(fg) ~= "number" then
    local ok2, hl2 = pcall(vim.api.nvim_get_hl_by_name, group, true)
    if ok2 and type(hl2) == "table" then fg = hl2.foreground end
  end
  if type(fg) ~= "number" then return nil end
  return string.format("#%06x", fg)
end

-- Build an "auto" palette: dracula with any colors the active colorscheme
-- exposes substituted in. `reader` is injectable for testing.
function M.resolve_auto(reader)
  reader = reader or M.default_reader
  local c = copy(DRACULA)
  for role, group in pairs(AUTO_SAMPLE) do
    local hex = reader(group)
    if hex then c[role] = hex end
  end
  return c
end

-- Resolve config into a flat role->hex table.
-- opts = { theme = "dracula"|"auto"|<table>, colorblind = bool, reader = fn }
function M.colors(opts)
  opts = opts or {}
  local theme = opts.theme or "dracula"
  local c
  if theme == "auto" then
    c = M.resolve_auto(opts.reader)
  elseif type(theme) == "table" then
    c = merge(DRACULA, theme)
  else
    c = copy(DRACULA)
  end
  if opts.colorblind then
    c = merge(c, CB_OVERLAY)
  end
  return c
end

-- Turn a resolved role table into concrete Vimmer* highlight-group specs.
function M.build_groups(c)
  return {
    VimmerTitle           = { bold = true, fg = c.title },
    VimmerTierBeginner    = { bold = true, fg = c.tier_beginner },
    VimmerTierWarrior     = { bold = true, fg = c.tier_warrior },
    VimmerTierNinja       = { bold = true, fg = c.tier_ninja },
    VimmerTierGrandmaster = { bold = true, fg = c.tier_grandmaster },
    VimmerCleared         = { fg = c.cleared },
    VimmerLocked          = { fg = c.locked },
    VimmerSelected        = { bold = true, bg = c.menu_sel_bg, fg = c.menu_sel_fg },
    VimmerPanel           = { bold = true, bg = c.panel_bg, fg = c.title },
    VimmerSection         = { bold = true, fg = c.section },
    VimmerBadge           = { bold = true, fg = c.badge },
    VimmerXP              = { bold = true, fg = c.xp },
    VimmerHP_high         = { fg = c.hp_high },
    VimmerHP_mid          = { fg = c.hp_mid },
    VimmerHP_low          = { fg = c.hp_low },
    VimmerWin             = { bg = c.win_bg, fg = c.win_fg },
    VimmerDeath           = { bold = true, fg = c.death },
    VimmerCommand         = { bold = true, fg = c.command },
    VimmerExample         = { fg = c.example },
    VimmerTimerOk         = { bold = true, fg = c.timer_ok },
    VimmerTimerWarn       = { bold = true, fg = c.timer_warn },
    VimmerTimerDanger     = { bold = true, fg = c.timer_danger },
    VimmerBoss            = { bold = true, fg = c.boss },
    VimmerPhase           = { bold = true, bg = c.phase_bg, fg = c.phase_fg },
    VimmerDamage          = { bg = c.damage_bg, fg = c.damage_fg },
    VimmerCrit            = { bg = c.crit_bg, fg = c.crit_fg },
    VimmerTeachTip        = { fg = c.teach_tip },
    VimmerTeachFoot       = { fg = c.teach_foot },
  }
end

return M
