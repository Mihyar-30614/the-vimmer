-- Set package.path so specs can require("the-vimmer.xxx")
local src = debug.getinfo(1, "S").source:match("^@(.+)/tests/spec/helpers%.lua$")
local root = src or "."
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

-- Stub minimal vim globals when running outside Neovim
if not rawget(_G, "vim") then
  _G.vim = {
    json = require("the-vimmer.json"),
    fn = {
      stdpath = function() return "/tmp" end,
      mkdir = function() end,
    },
    tbl_deep_extend = function(_, base, override)
      local result = {}
      for k, v in pairs(base) do result[k] = v end
      for k, v in pairs(override) do result[k] = v end
      return result
    end,
    log = { levels = { WARN = 2, INFO = 3, ERROR = 4 } },
    notify = function() end,
  }
end
