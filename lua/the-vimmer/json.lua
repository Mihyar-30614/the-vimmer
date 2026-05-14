-- Minimal JSON encoder/decoder used as a fallback when vim.json is unavailable.
-- encode: handles nil/bool/number/string/array/object recursively.
-- decode: transforms JSON into Lua table syntax then runs it through loadstring.
--   NOT a full parser — safe only for trusted local save files, not arbitrary input.
local M = {}

-- Recursively encode a Lua value to a JSON string.
local function encode_value(v)
  local t = type(v)
  if t == "nil" then return "null"
  elseif t == "boolean" then return tostring(v)
  elseif t == "number" then return tostring(v)
  elseif t == "string" then
    return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
  elseif t == "table" then
    if #v > 0 then
      local parts = {}
      for _, item in ipairs(v) do parts[#parts+1] = encode_value(item) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, val in pairs(v) do
        parts[#parts+1] = '"' .. tostring(k) .. '":' .. encode_value(val)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

function M.encode(t)
  return encode_value(t)
end

-- Decode a JSON string by rewriting it into Lua table syntax and eval-ing it.
-- Works for the plugin's own save files; will break on JSON with non-string keys or complex escapes.
function M.decode(s)
  local lua_str = s
    :gsub('"([^"]*)"%s*:', '["%1"]=')
    :gsub('null', 'nil')
  local chunk = "return " .. lua_str
  local fn, err = loadstring(chunk)
  if not fn then error("JSON decode error: " .. tostring(err)) end
  return fn()
end

return M
