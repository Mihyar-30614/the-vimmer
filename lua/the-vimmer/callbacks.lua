-- Simple event hook registry for win/death callbacks configured via setup() opts.
-- Hooks are replaced wholesale on M.set() — no accumulation across calls.
local M = {}

local hooks = {}

-- Replace the entire hook table; any key in `h` whose value is a function is kept.
function M.set(h)
  hooks = {}
  if type(h) ~= "table" then return end
  for k, v in pairs(h) do hooks[k] = v end
end

-- Fire `event` if a handler is registered; swallows errors so hooks never crash the game.
function M.emit(event, payload)
  local fn = hooks[event]
  if type(fn) ~= "function" then return end
  local ok, err = pcall(fn, payload or {})
  if not ok and vim and vim.notify then
    vim.notify("the-vimmer hook '" .. tostring(event) .. "': " .. tostring(err), vim.log.levels.ERROR)
  end
end

return M
