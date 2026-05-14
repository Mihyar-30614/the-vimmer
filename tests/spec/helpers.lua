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
      glob = function(pattern, nosuf, list)
        local files = {}
        local handle = io.popen('ls ' .. pattern .. ' 2>/dev/null')
        if handle then
          for line in handle:lines() do files[#files+1] = line end
          handle:close()
        end
        return list and files or table.concat(files, "\n")
      end,
      strdisplaywidth = function(s) return #(s or "") end,
      strchars = function(s) return #(s or "") end,
      strcharpart = function(s, start, len)
        s = s or ""
        if len == nil then return s:sub(start + 1) end
        return s:sub(start + 1, start + len)
      end,
    },
    tbl_deep_extend = function(_, base, override)
      local result = {}
      for k, v in pairs(base) do result[k] = v end
      for k, v in pairs(override) do result[k] = v end
      return result
    end,
    log = { levels = { WARN = 2, INFO = 3, ERROR = 4 } },
    notify = function() end,
    trim = function(s)
      return (s or ""):match("^%s*(.-)%s*$")
    end,
    split = function(s, sep, opts)
      opts = opts or {}
      local plain = opts.plain
      local out = {}
      if s == nil or s == "" then return out end
      local i = 1
      while true do
        local a, b
        if plain then
          a, b = s:find(sep, i, true)
        else
          a, b = s:find(sep, i)
        end
        if not a then
          out[#out + 1] = s:sub(i)
          break
        end
        out[#out + 1] = s:sub(i, a - 1)
        i = b + 1
      end
      return out
    end,
  }
end
