-- Plugin entry point. Call M.setup(opts) from your Neovim config.
-- opts.hooks      = { win = fn, death = fn } - lifecycle callbacks (see callbacks.lua).
-- opts.colorblind = true                     - switch to a deuteranopia-safe palette (Wong/Okabe).
local M = {}

M.config = M.config or {}

--- @param opts? table optional `{ hooks = ..., colorblind = bool }`
function M.setup(opts)
  opts = opts or {}
  M.config.colorblind = opts.colorblind == true
  require("the-vimmer.highlights").setup()
  require("the-vimmer.commands").register(opts)
end

return M
