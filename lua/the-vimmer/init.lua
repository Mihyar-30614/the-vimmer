local M = {}

--- @param opts? table optional `{ hooks = { win = fn, death = fn }, ... }` passed to commands.register
function M.setup(opts)
  opts = opts or {}
  require("the-vimmer.highlights").setup()
  require("the-vimmer.commands").register(opts)
end

return M
