-- Plugin entry point. Call M.setup(opts) from your Neovim config.
-- opts.hooks      = { win = fn, death = fn } - lifecycle callbacks (see callbacks.lua).
-- opts.colorblind = true                     - switch to a deuteranopia-safe palette (Wong/Okabe).
-- opts.theme      = "dracula" | "auto" | <table>
--                    "dracula" (default) - the built-in look.
--                    "auto"              - derive accent colors from the active colorscheme.
--                    <table>             - friendly role->hex overrides (see the-vimmer.themes).
-- opts.border     = "sharp" | "rounded"
--                    "sharp" (default)   - double-line box corners (╔╗╚╝).
--                    "rounded"           - light arc corners (╭╮╰╯).
-- opts.icons      = "unicode" | "ascii"
--                    "unicode" (default) - symbols/emoji icons in HUD and menus.
--                    "ascii"             - plain-text icon fallback.
local M = {}

M.config = M.config or {}

--- @param opts? table optional `{ hooks = ..., colorblind = bool, theme = ..., border = ... }`
function M.setup(opts)
  opts = opts or {}
  M.config.colorblind = opts.colorblind == true
  M.config.theme = opts.theme or "dracula"
  M.config.border = opts.border or "sharp"
  M.config.icons = opts.icons or "unicode"
  require("the-vimmer.highlights").setup()
  require("the-vimmer.commands").register(opts)
end

return M
