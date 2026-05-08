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

local function validate_alternates(alts)
  if alts == nil then return true end
  if type(alts) ~= "table" then return false end
  for _, seq in ipairs(alts) do
    if type(seq) ~= "table" or #seq < 1 then return false end
    for _, k in ipairs(seq) do
      if type(k) ~= "string" then return false end
    end
  end
  return true
end

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
      if not validate_alternates(phase.optimal_keystrokes_alternates) then return false end
    end
    return true
  end
  for _, field in ipairs(REQUIRED_FIELDS) do
    if room[field] == nil then return false end
  end
  if not validate_alternates(room.optimal_keystrokes_alternates) then return false end
  return true
end

--- Primary optimal_keystrokes plus optional parallel sequences (positional matching).
function M.acceptable_key_sequences(ctx)
  local seqs = {}
  local primary = ctx.optimal_keystrokes
  if type(primary) == "table" and #primary > 0 then
    seqs[#seqs + 1] = primary
  end
  for _, alt in ipairs(ctx.optimal_keystrokes_alternates or {}) do
    if type(alt) == "table" and #alt > 0 then
      seqs[#seqs + 1] = alt
    end
  end
  return seqs
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

local function collect_runtime_room_paths(tier)
  local paths = {}
  local seen = {}
  if vim and vim.api and vim.api.nvim_get_runtime_file then
    local pat = "the-vimmer/rooms/" .. tier .. "/*.lua"
    local ok, files = pcall(vim.api.nvim_get_runtime_file, pat, true)
    if ok and type(files) == "table" then
      for _, fp in ipairs(files) do
        if not seen[fp] then
          seen[fp] = true
          paths[#paths + 1] = fp
        end
      end
    end
  end
  return paths
end

function M.load_tier(tier)
  local builtin_dir = rooms_dir() .. "/" .. tier
  local files = list_lua_files(builtin_dir)
  for _, fp in ipairs(collect_runtime_room_paths(tier)) do
    files[#files + 1] = fp
  end

  local result = {}
  local seen_ids = {}

  for _, filepath in ipairs(files) do
    local ok, room = pcall(dofile, filepath)
    if ok and type(room) == "table" and M.validate(room) then
      if seen_ids[room.id] then
        if vim and vim.notify then
          vim.notify(
            "the-vimmer: skipping duplicate room id '" .. room.id .. "' in " .. filepath,
            vim.log.levels.WARN)
        end
      else
        seen_ids[room.id] = true
        result[#result + 1] = room
      end
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
