local M = {}

function M.hp_group(hp)
  if hp > 60 then return "VimmerHP_high"
  elseif hp > 30 then return "VimmerHP_mid"
  else return "VimmerHP_low" end
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
end

return M
