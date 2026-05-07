local M = {}

local TIERS = { "beginner", "warrior", "ninja" }

local REQUIRED_FIELDS = {
  "id", "tier", "command", "title", "description",
  "before_example", "after_example", "usage_tip",
  "start_text", "target_text", "base_xp", "optimal_keystrokes",
}

local BOSS_REQUIRED = {
  "id", "tier", "command", "title", "description",
  "usage_tip", "base_xp", "phases", "time_limit",
}

function M.validate(room)
  if room.is_boss then
    for _, field in ipairs(BOSS_REQUIRED) do
      if room[field] == nil then return false end
    end
    if type(room.phases) ~= "table" or #room.phases < 1 then return false end
    for _, phase in ipairs(room.phases) do
      if not phase.start_text or not phase.target_text or not phase.optimal_keystrokes then
        return false
      end
    end
    return true
  end
  for _, field in ipairs(REQUIRED_FIELDS) do
    if room[field] == nil then return false end
  end
  return true
end

local function rooms_dir()
  local src = debug.getinfo(1, "S").source:match("^@(.+)")
  return src and src:match("(.+)/the%-vimmer/rooms%.lua$") .. "/rooms" or "lua/rooms"
end

local function list_lua_files(dir)
  if vim and vim.fn then
    local glob = vim.fn.glob(dir .. "/*.lua", false, true)
    return type(glob) == "table" and glob or {}
  end
  local files = {}
  local handle = io.popen('ls "' .. dir .. '"/*.lua 2>/dev/null')
  if handle then
    for line in handle:lines() do files[#files+1] = line end
    handle:close()
  end
  return files
end

function M.load_tier(tier)
  local dir = rooms_dir() .. "/" .. tier
  local files = list_lua_files(dir)
  local result = {}
  for _, filepath in ipairs(files) do
    local ok, room = pcall(dofile, filepath)
    if ok and type(room) == "table" and M.validate(room) then
      result[#result+1] = room
    elseif vim and vim.notify then
      vim.notify("the-vimmer: skipping invalid room: " .. filepath, vim.log.levels.WARN)
    end
  end
  return result
end

function M.get_room(id)
  for _, tier in ipairs(TIERS) do
    for _, room in ipairs(M.load_tier(tier)) do
      if room.id == id then return room end
    end
  end
  return nil
end

function M.all_tiers()
  return TIERS
end

return M
