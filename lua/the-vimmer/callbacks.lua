local M = {}

local hooks = {}

function M.set(h)
  hooks = {}
  if type(h) ~= "table" then return end
  for k, v in pairs(h) do hooks[k] = v end
end

function M.emit(event, payload)
  local fn = hooks[event]
  if type(fn) ~= "function" then return end
  local ok, err = pcall(fn, payload or {})
  if not ok and vim and vim.notify then
    vim.notify("the-vimmer hook '" .. tostring(event) .. "': " .. tostring(err), vim.log.levels.ERROR)
  end
end

return M
