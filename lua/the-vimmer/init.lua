local M = {}

function M.setup(opts)
  opts = opts or {}
  require("the-vimmer.highlights").setup()
  require("the-vimmer.commands").register()
end

return M
