# The Vimmer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Neovim Lua plugin that teaches shortcuts through room-based dungeon gameplay, covering beginner to ninja skill levels.

**Architecture:** Pure Lua plugin using Neovim floating windows for UI. Game logic (state machine, XP, HP tracking) is isolated from vim API calls so it can be unit-tested with busted. Room content lives in individual Lua files, making the game easy to extend.

**Tech Stack:** Lua 5.1+ (Neovim LuaJIT), Neovim 0.8+ (`vim.api`, `vim.fn`, `vim.json`, `vim.on_key`), busted (test runner, dev-only)

---

## File Map

| File | Responsibility |
|------|---------------|
| `plugin/the-vimmer.lua` | Auto-load: registers plugin, calls `setup()` |
| `lua/the-vimmer/init.lua` | Public API: `setup()` |
| `lua/the-vimmer/json.lua` | Minimal JSON encode/decode (used in tests without Neovim) |
| `lua/the-vimmer/progress.lua` | XP calculation, unlock logic, JSON persistence |
| `lua/the-vimmer/rooms.lua` | Room file loader, validator, tier listing |
| `lua/the-vimmer/game.lua` | State machine (`idle→teaching→playing→results`), HP, streak |
| `lua/the-vimmer/ui.lua` | All floating windows, split buffers, HUD statusline |
| `lua/the-vimmer/commands.lua` | `:VimmerPlay`, `:VimmerProgress`, `:VimmerReset` — wires everything |
| `lua/rooms/beginner/*.lua` | 7 beginner room definitions |
| `lua/rooms/warrior/*.lua` | 6 warrior room definitions |
| `lua/rooms/ninja/*.lua` | 4 ninja room definitions |
| `tests/.busted` | busted config, sets `ROOT` to `tests/spec` |
| `tests/spec/helpers.lua` | Sets `package.path` and stubs `vim` globals for tests outside Neovim |
| `tests/spec/progress_spec.lua` | Tests: XP calc, unlock logic, save/load/corrupt |
| `tests/spec/rooms_spec.lua` | Tests: room validator, tier loader, get_room |
| `tests/spec/game_spec.lua` | Tests: state machine transitions, HP drain, streak |

---

### Task 1: Project scaffold

**Files:**
- Create: `plugin/the-vimmer.lua`
- Create: `lua/the-vimmer/init.lua`
- Create: `tests/.busted`
- Create: `tests/spec/helpers.lua`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p lua/the-vimmer lua/rooms/beginner lua/rooms/warrior lua/rooms/ninja plugin tests/spec
```

- [ ] **Step 2: Create plugin entry point**

Create `plugin/the-vimmer.lua`:

```lua
if vim.g.loaded_the_vimmer then return end
vim.g.loaded_the_vimmer = 1

require("the-vimmer").setup()
```

- [ ] **Step 3: Create init.lua**

Create `lua/the-vimmer/init.lua`:

```lua
local M = {}

function M.setup(opts)
  opts = opts or {}
  require("the-vimmer.commands").register()
end

return M
```

- [ ] **Step 4: Create busted config**

Create `tests/.busted`:

```lua
return {
  default = {
    ROOT = { "tests/spec" },
    pattern = "_spec",
  },
}
```

- [ ] **Step 5: Create test helper**

Create `tests/spec/helpers.lua`:

```lua
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
```

- [ ] **Step 6: Install busted (dev-only)**

```bash
luarocks install busted
```

Expected: ends with `busted ... is now installed`

- [ ] **Step 7: Verify busted runs with no errors**

```bash
busted tests/spec/ --no-keep-going 2>&1 | head -5
```

Expected: `0 successes / 0 failures / 0 errors`

- [ ] **Step 8: Commit**

```bash
git add plugin/ lua/the-vimmer/init.lua tests/
git commit -m "feat: scaffold project structure and test harness"
```

---

### Task 2: json.lua — minimal JSON for test environment

**Files:**
- Create: `lua/the-vimmer/json.lua`

- [ ] **Step 1: Create json.lua**

Create `lua/the-vimmer/json.lua`:

```lua
local M = {}

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

function M.decode(s)
  local lua_str = s
    :gsub('"([^"]*)"%s*:', '["%1"]=')
    :gsub('%bnull', 'nil')
  local fn, err = load("return " .. lua_str)
  if not fn then error("JSON decode error: " .. tostring(err)) end
  return fn()
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/the-vimmer/json.lua
git commit -m "feat: add minimal JSON module for test environment"
```

---

### Task 3: progress.lua — XP and persistence

**Files:**
- Create: `lua/the-vimmer/progress.lua`
- Create: `tests/spec/progress_spec.lua`

- [ ] **Step 1: Write failing tests**

Create `tests/spec/progress_spec.lua`:

```lua
require("helpers")
local progress = require("the-vimmer.progress")

describe("progress.calculate_xp", function()
  it("returns base_xp when full HP and no streak", function()
    assert.equals(50, progress.calculate_xp(50, 100, 0))
  end)

  it("adds HP bonus proportionally (50 HP = 25% of 50 = 25 bonus)", function()
    assert.equals(75, progress.calculate_xp(50, 50, 0))
  end)

  it("adds 50% streak bonus when streak >= 3", function()
    -- base=50, hp_bonus=50 (100 HP), subtotal=100, streak_bonus=50 → 150
    assert.equals(150, progress.calculate_xp(50, 100, 3))
  end)

  it("no streak bonus when streak < 3", function()
    assert.equals(50, progress.calculate_xp(50, 100, 2))
  end)
end)

describe("progress.is_tier_unlocked", function()
  it("beginner is always unlocked", function()
    assert.is_true(progress.is_tier_unlocked("beginner", {}, 10))
  end)

  it("warrior locked when fewer than 80% beginner cleared", function()
    local cleared = { beginner_1 = true, beginner_2 = true }
    assert.is_false(progress.is_tier_unlocked("warrior", cleared, 10))
  end)

  it("warrior unlocked when 80% or more beginner cleared", function()
    local cleared = {}
    for i = 1, 8 do cleared["beginner_" .. i] = true end
    assert.is_true(progress.is_tier_unlocked("warrior", cleared, 10))
  end)

  it("ninja locked when warrior < 80%", function()
    local cleared = { warrior_1 = true }
    assert.is_false(progress.is_tier_unlocked("ninja", cleared, 6))
  end)

  it("ninja unlocked when warrior >= 80%", function()
    local cleared = {}
    for i = 1, 5 do cleared["warrior_" .. i] = true end
    assert.is_true(progress.is_tier_unlocked("ninja", cleared, 6))
  end)
end)

describe("progress.save and progress.load", function()
  local tmp

  before_each(function()
    tmp = os.tmpname() .. ".json"
  end)

  after_each(function()
    os.remove(tmp)
  end)

  it("round-trips progress data", function()
    local data = { total_xp = 120, cleared = { beginner_hjkl = true }, streak = 2 }
    progress.save(data, tmp)
    local loaded = progress.load(tmp)
    assert.equals(120, loaded.total_xp)
    assert.is_true(loaded.cleared.beginner_hjkl)
    assert.equals(2, loaded.streak)
  end)

  it("returns default state on missing file", function()
    local loaded = progress.load("/nonexistent/path/no.json")
    assert.equals(0, loaded.total_xp)
    assert.same({}, loaded.cleared)
    assert.equals(0, loaded.streak)
  end)

  it("returns default state on corrupt file", function()
    local f = io.open(tmp, "w"); f:write("{{not json}}"); f:close()
    local loaded = progress.load(tmp)
    assert.equals(0, loaded.total_xp)
  end)
end)

describe("progress.reset", function()
  it("returns clean default state", function()
    local state = progress.reset_data()
    assert.equals(0, state.total_xp)
    assert.same({}, state.cleared)
    assert.equals(0, state.streak)
  end)
end)
```

- [ ] **Step 2: Run to verify they fail**

```bash
busted tests/spec/progress_spec.lua 2>&1 | tail -5
```

Expected: `Error` — module `the-vimmer.progress` not found.

- [ ] **Step 3: Implement progress.lua**

Create `lua/the-vimmer/progress.lua`:

```lua
local M = {}

local function json_encode(t)
  local ok, r = pcall((vim.json or require("the-vimmer.json")).encode, t)
  return ok and r or nil
end

local function json_decode(s)
  local ok, r = pcall((vim.json or require("the-vimmer.json")).decode, s)
  return ok and type(r) == "table" and r or nil
end

local function default_state()
  return { total_xp = 0, cleared = {}, streak = 0, unlocked_tiers = { beginner = true } }
end

function M.calculate_xp(base_xp, remaining_hp, streak)
  local hp_bonus = math.floor(remaining_hp / 100 * base_xp)
  local subtotal = base_xp + hp_bonus
  local streak_bonus = (streak >= 3) and math.floor(subtotal * 0.5) or 0
  return subtotal + streak_bonus
end

function M.is_tier_unlocked(tier, cleared, total_in_tier)
  if tier == "beginner" then return true end
  local prefix = (tier == "warrior") and "beginner_" or "warrior_"
  local count = 0
  for k in pairs(cleared) do
    if k:match("^" .. prefix) then count = count + 1 end
  end
  return count >= math.ceil((total_in_tier or 1) * 0.8)
end

function M.default_path()
  local data_dir = (vim.fn and vim.fn.stdpath("data") or "/tmp") .. "/the-vimmer"
  if vim.fn then vim.fn.mkdir(data_dir, "p") end
  return data_dir .. "/progress.json"
end

function M.save(data, path)
  path = path or M.default_path()
  local encoded = json_encode(data)
  if not encoded then return end
  local f = io.open(path, "w")
  if f then f:write(encoded); f:close() end
end

function M.load(path)
  path = path or M.default_path()
  local f = io.open(path, "r")
  if not f then return default_state() end
  local raw = f:read("*a"); f:close()
  local data = json_decode(raw)
  if not data then return default_state() end
  local def = default_state()
  return vim.tbl_deep_extend("force", def, data)
end

function M.reset(path)
  local state = default_state()
  M.save(state, path)
  return state
end

function M.reset_data()
  return default_state()
end

return M
```

- [ ] **Step 4: Run tests**

```bash
busted tests/spec/progress_spec.lua
```

Expected: `10 successes / 0 failures / 0 errors`

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "feat: add progress module with XP calc and persistence"
```

---

### Task 4: rooms.lua — room loader and validator

**Files:**
- Create: `lua/the-vimmer/rooms.lua`
- Create: `lua/rooms/beginner/hjkl.lua` (sample room for tests)
- Create: `tests/spec/rooms_spec.lua`

- [ ] **Step 1: Create sample beginner room for tests**

Create `lua/rooms/beginner/hjkl.lua`:

```lua
return {
  id = "beginner_hjkl",
  tier = "beginner",
  command = "h / j / k / l",
  title = "Basic Motions: hjkl",
  description = "Move cursor left (h), down (j), up (k), right (l)",
  before_example = "|hello world",
  after_example = "hell|o world",
  usage_tip = "Stay on home row. Never reach for arrow keys again.",
  start_text = "move right to reach the end",
  target_text = "move right to reach the end",
  base_xp = 30,
  optimal_keystrokes = { "l", "l", "l", "l" },
}
```

- [ ] **Step 2: Write failing tests**

Create `tests/spec/rooms_spec.lua`:

```lua
require("helpers")
local rooms = require("the-vimmer.rooms")

describe("rooms.validate", function()
  local valid_room = {
    id = "test_room", tier = "beginner", command = "w",
    title = "Test", description = "Desc",
    before_example = "|before", after_example = "after|",
    usage_tip = "tip", start_text = "start", target_text = "target",
    base_xp = 50, optimal_keystrokes = { "w" },
  }

  it("accepts a valid room", function()
    assert.is_true(rooms.validate(valid_room))
  end)

  it("rejects room missing id", function()
    local r = {}
    for k, v in pairs(valid_room) do r[k] = v end
    r.id = nil
    assert.is_false(rooms.validate(r))
  end)

  it("rejects room missing optimal_keystrokes", function()
    local r = {}
    for k, v in pairs(valid_room) do r[k] = v end
    r.optimal_keystrokes = nil
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.load_tier", function()
  it("loads rooms from beginner tier", function()
    local loaded = rooms.load_tier("beginner")
    assert.is_true(#loaded > 0)
  end)

  it("loaded rooms have correct tier", function()
    local loaded = rooms.load_tier("beginner")
    for _, r in ipairs(loaded) do
      assert.equals("beginner", r.tier)
    end
  end)

  it("returns empty table for nonexistent tier", function()
    local loaded = rooms.load_tier("nonexistent")
    assert.same({}, loaded)
  end)
end)

describe("rooms.get_room", function()
  it("returns room by id", function()
    local room = rooms.get_room("beginner_hjkl")
    assert.is_not_nil(room)
    assert.equals("beginner_hjkl", room.id)
  end)

  it("returns nil for unknown id", function()
    assert.is_nil(rooms.get_room("does_not_exist"))
  end)
end)

describe("rooms.all_tiers", function()
  it("returns three tiers in order", function()
    local tiers = rooms.all_tiers()
    assert.equals("beginner", tiers[1])
    assert.equals("warrior", tiers[2])
    assert.equals("ninja", tiers[3])
  end)
end)
```

- [ ] **Step 3: Run to verify they fail**

```bash
busted tests/spec/rooms_spec.lua 2>&1 | tail -5
```

Expected: `Error` — module `the-vimmer.rooms` not found.

- [ ] **Step 4: Implement rooms.lua**

Create `lua/the-vimmer/rooms.lua`:

```lua
local M = {}

local TIERS = { "beginner", "warrior", "ninja" }

local REQUIRED_FIELDS = {
  "id", "tier", "command", "title", "description",
  "before_example", "after_example", "usage_tip",
  "start_text", "target_text", "base_xp", "optimal_keystrokes",
}

function M.validate(room)
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
```

- [ ] **Step 5: Run tests**

```bash
busted tests/spec/rooms_spec.lua
```

Expected: `8 successes / 0 failures / 0 errors`

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/rooms.lua lua/rooms/beginner/hjkl.lua tests/spec/rooms_spec.lua
git commit -m "feat: add room loader with validation"
```

---

### Task 5: game.lua — state machine and HP tracking

**Files:**
- Create: `lua/the-vimmer/game.lua`
- Create: `tests/spec/game_spec.lua`

- [ ] **Step 1: Write failing tests**

Create `tests/spec/game_spec.lua`:

```lua
require("helpers")
local game = require("the-vimmer.game")

local function make_room(overrides)
  local r = { id = "test", base_xp = 50, optimal_keystrokes = { "w", "b" } }
  for k, v in pairs(overrides or {}) do r[k] = v end
  return r
end

describe("game state machine", function()
  local g

  before_each(function() g = game.new() end)

  it("starts in idle state", function()
    assert.equals("idle", g.state)
  end)

  it("idle -> teaching on start_room", function()
    g:start_room(make_room())
    assert.equals("teaching", g.state)
  end)

  it("teaching -> playing on begin_play, HP reset to 100", function()
    g:start_room(make_room()); g:begin_play()
    assert.equals("playing", g.state)
    assert.equals(100, g.hp)
  end)

  it("playing -> results on complete_room", function()
    g:start_room(make_room()); g:begin_play(); g:complete_room(100)
    assert.equals("results", g.state)
  end)

  it("results -> idle on dismiss_results", function()
    g:start_room(make_room()); g:begin_play(); g:complete_room(100)
    g:dismiss_results()
    assert.equals("idle", g.state)
  end)
end)

describe("game HP tracking", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room()); g:begin_play()
  end)

  it("starts at 100 HP", function()
    assert.equals(100, g.hp)
  end)

  it("optimal keystroke does not drain HP", function()
    g:register_key("w")
    assert.equals(100, g.hp)
  end)

  it("non-optimal keystroke drains 5 HP", function()
    g:register_key("x")
    assert.equals(95, g.hp)
  end)

  it("HP never goes below 0", function()
    for _ = 1, 30 do g:register_key("x") end
    assert.equals(0, g.hp)
  end)

  it("is_dead returns true at 0 HP", function()
    for _ = 1, 20 do g:register_key("x") end
    assert.is_true(g:is_dead())
  end)

  it("is_dead returns false above 0 HP", function()
    g:register_key("x")
    assert.is_false(g:is_dead())
  end)
end)

describe("game streak", function()
  it("increments streak on dismiss_results", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play(); g:complete_room(100)
    g:dismiss_results()
    assert.equals(1, g.streak)
  end)

  it("resets streak on retry_room", function()
    local g = game.new()
    g.streak = 5
    g:start_room(make_room()); g:begin_play()
    g:retry_room()
    assert.equals(0, g.streak)
  end)

  it("retry_room returns to teaching state", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play()
    g:retry_room()
    assert.equals("teaching", g.state)
  end)
end)

describe("game.last_xp", function()
  it("is set after complete_room", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play()
    g:complete_room(100)
    assert.equals(50, g.last_xp)
  end)
end)
```

- [ ] **Step 2: Run to verify they fail**

```bash
busted tests/spec/game_spec.lua 2>&1 | tail -5
```

Expected: `Error` — module `the-vimmer.game` not found.

- [ ] **Step 3: Implement game.lua**

Create `lua/the-vimmer/game.lua`:

```lua
local M = {}

function M.new()
  local g = {
    state = "idle",
    current_room = nil,
    hp = 100,
    streak = 0,
    last_xp = 0,
  }

  function g:start_room(room)
    self.current_room = room
    self.state = "teaching"
  end

  function g:begin_play()
    self.hp = 100
    self.state = "playing"
  end

  function g:register_key(key)
    if self.state ~= "playing" then return end
    local optimal = self.current_room.optimal_keystrokes or {}
    for _, k in ipairs(optimal) do
      if k == key then return end
    end
    self.hp = math.max(0, self.hp - 5)
  end

  function g:is_dead()
    return self.hp <= 0
  end

  function g:complete_room(remaining_hp)
    local progress = require("the-vimmer.progress")
    self.last_xp = progress.calculate_xp(
      self.current_room.base_xp,
      remaining_hp,
      self.streak
    )
    self.state = "results"
  end

  function g:dismiss_results()
    self.streak = self.streak + 1
    self.state = "idle"
  end

  function g:retry_room()
    self.streak = 0
    local room = self.current_room
    self.state = "idle"
    self:start_room(room)
  end

  return g
end

return M
```

- [ ] **Step 4: Run tests**

```bash
busted tests/spec/game_spec.lua
```

Expected: `14 successes / 0 failures / 0 errors`

- [ ] **Step 5: Run full test suite**

```bash
busted tests/spec/
```

Expected: All tests pass, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat: add game state machine with HP and streak tracking"
```

---

### Task 6: ui.lua — map screen

**Files:**
- Create: `lua/the-vimmer/ui.lua`

This module uses vim APIs throughout. All tests in this task are manual.

- [ ] **Step 1: Create ui.lua with helpers and open_map**

Create `lua/the-vimmer/ui.lua`:

```lua
local M = {}
local api = vim.api

local function pad_row(content, width)
  local visible = content:gsub("[\xc2-\xdf][\x80-\xbf]", "_")
    :gsub("[\xe0-\xef][\x80-\xbf][\x80-\xbf]", "_")
    :gsub("[\xf0-\xf7][\x80-\xbf][\x80-\xbf][\x80-\xbf]", "_")
  local pad = width - 2 - #visible
  if pad < 0 then pad = 0 end
  return "║" .. content .. string.rep(" ", pad) .. "║"
end

local function make_border(width)
  return {
    top = "╔" .. string.rep("═", width - 2) .. "╗",
    sep = "╠" .. string.rep("═", width - 2) .. "╣",
    bot = "╚" .. string.rep("═", width - 2) .. "╝",
    row = function(content) return pad_row(content, width) end,
  }
end

local function xp_bar(xp, bar_width)
  local max_xp = 1000
  local filled = math.min(math.floor((xp / max_xp) * bar_width), bar_width)
  return string.rep("▓", filled) .. string.rep("░", bar_width - filled)
end

local function open_float(lines, width)
  local height = #lines
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = row, col = col,
    width = width, height = height,
    style = "minimal", border = "none",
  })
  return buf, win
end

function M.open_map(progress_data, rooms_by_tier, on_select)
  local width = 50
  local b = make_border(width)
  local bar = xp_bar(progress_data.total_xp, 6)
  local lines = {}
  local selectable = {}

  lines[#lines+1] = b.top
  lines[#lines+1] = b.row(string.format("  THE VIMMER           XP:%-5d %s",
    progress_data.total_xp, bar))
  lines[#lines+1] = b.sep

  local tiers = { "beginner", "warrior", "ninja" }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA" }
  local tier_prereq = { warrior = "complete 80%% of beginner", ninja = "complete 80%% of warrior" }
  local progress = require("the-vimmer.progress")

  for ti, tier in ipairs(tiers) do
    local tier_rooms = rooms_by_tier[tier] or {}
    local total = #tier_rooms
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total)

    if not unlocked then
      lines[#lines+1] = b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or ""))
    else
      lines[#lines+1] = b.row(string.format("  [%s]", tier_labels[tier]))
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, 36))
        lines[#lines+1] = b.row(label)
        if not cleared then
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
    end
    if ti < #tiers then lines[#lines+1] = b.row("") end
  end

  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  <Enter> play   j/k navigate   <q> quit")
  lines[#lines+1] = b.bot

  local buf, win = open_float(lines, width)
  local cur_idx = 1

  if selectable[1] then
    api.nvim_win_set_cursor(win, { selectable[1].line, 0 })
  end

  local function map_key(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  map_key("j", function()
    cur_idx = math.min(cur_idx + 1, #selectable)
    if selectable[cur_idx] then
      api.nvim_win_set_cursor(win, { selectable[cur_idx].line, 0 })
    end
  end)

  map_key("k", function()
    cur_idx = math.max(cur_idx - 1, 1)
    if selectable[cur_idx] then
      api.nvim_win_set_cursor(win, { selectable[cur_idx].line, 0 })
    end
  end)

  map_key("<CR>", function()
    if selectable[cur_idx] then
      local room = selectable[cur_idx].room
      api.nvim_win_close(win, true)
      on_select(room)
    end
  end)

  map_key("q", function()
    api.nvim_win_close(win, true)
  end)
end

return M
```

- [ ] **Step 2: Manual test**

Open Neovim from `/mnt/storage/apps/the_vimmer`:
```vim
:set rtp+=.
:lua
local ui = require("the-vimmer.ui")
local rooms = require("the-vimmer.rooms")
local prog = { total_xp = 340, cleared = { beginner_hjkl = true }, streak = 1, unlocked_tiers = {} }
local rbt = { beginner = rooms.load_tier("beginner"), warrior = {}, ninja = {} }
ui.open_map(prog, rbt, function(r) print("selected: " .. r.id) end)
```

Expected: Map window opens centered. j/k move cursor between unlocked rooms. Enter prints room id. q closes.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add map screen UI"
```

---

### Task 7: ui.lua — teach screen

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Add open_teach to ui.lua**

Add before the final `return M` in `lua/the-vimmer/ui.lua`:

```lua
function M.open_teach(room, on_begin)
  local width = 50
  local b = make_border(width)
  local lines = {}

  lines[#lines+1] = b.top
  lines[#lines+1] = b.row("  COMMAND: " .. room.command)
  lines[#lines+1] = b.row("  " .. room.description)
  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  BEFORE:  " .. room.before_example)
  lines[#lines+1] = b.row("  AFTER:   " .. room.after_example)
  lines[#lines+1] = b.row("")
  -- wrap usage_tip at 46 chars
  local tip = room.usage_tip
  while #tip > 46 do
    local cut = tip:sub(1, 46):match("^(.+) ")
    lines[#lines+1] = b.row("  " .. (cut or tip:sub(1, 46)))
    tip = tip:sub(#(cut or tip:sub(1, 46)) + 2)
  end
  if #tip > 0 then lines[#lines+1] = b.row("  " .. tip) end
  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  <Enter> to begin   <q> back")
  lines[#lines+1] = b.bot

  local buf, win = open_float(lines, width)

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_begin()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true, silent = true })
end
```

- [ ] **Step 2: Manual test**

```vim
:lua
local ui = require("the-vimmer.ui")
local rooms = require("the-vimmer.rooms")
local r = rooms.load_tier("beginner")[1]
ui.open_teach(r, function() print("begin!") end)
```

Expected: Teach window shows command, description, before/after, usage tip. Enter closes and prints "begin!". q closes without action.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add teach screen UI"
```

---

### Task 8: ui.lua — play screen

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Add open_play and _close_play to ui.lua**

Add before `return M` in `lua/the-vimmer/ui.lua`:

```lua
local _play_ns = nil
local _play_tab = nil

function M.open_play(room, game_state, on_win, on_death)
  local target_lines = vim.split(room.target_text, "\n")
  local start_lines = vim.split(room.start_text, "\n")

  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
  api.nvim_buf_set_option(target_buf, "modifiable", false)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(play_buf, 0, -1, false, start_lines)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")

  vim.cmd("tabnew")
  _play_tab = api.nvim_get_current_tabpage()
  local top_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(top_win, target_buf)

  vim.cmd("split")
  local play_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(play_win, play_buf)
  api.nvim_set_current_win(play_win)

  local function update_hud()
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    vim.wo[play_win].statusline = string.format(
      " HP [%s] %d  |  Streak %d  |  %s",
      hp_bar, game_state.hp, game_state.streak, room.command
    )
  end

  update_hud()

  _play_ns = api.nvim_create_namespace("the-vimmer-keys")

  vim.on_key(function(key)
    if not api.nvim_win_is_valid(play_win) then
      vim.on_key(nil, _play_ns)
      return
    end
    if api.nvim_get_current_win() ~= play_win then return end

    game_state:register_key(key)
    update_hud()

    if game_state:is_dead() then
      vim.on_key(nil, _play_ns)
      vim.schedule(function() on_death() end)
      return
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(play_buf) then return end
      local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
      local target = table.concat(target_lines, "\n")
      if vim.trim(current) == vim.trim(target) then
        vim.on_key(nil, _play_ns)
        on_win(game_state.hp)
      end
    end)
  end, _play_ns)
end

function M._close_play()
  if _play_ns then
    vim.on_key(nil, _play_ns)
    _play_ns = nil
  end
  if _play_tab and api.nvim_tabpage_is_valid(_play_tab) then
    pcall(function()
      local tab = _play_tab
      _play_tab = nil
      vim.cmd(api.nvim_tabpage_get_number(tab) .. "tabclose")
    end)
  end
end
```

- [ ] **Step 2: Manual test**

```vim
:lua
local ui = require("the-vimmer.ui")
local game = require("the-vimmer.game")
local rooms = require("the-vimmer.rooms")
local r = rooms.load_tier("beginner")[1]
local g = game.new()
g:start_room(r); g:begin_play()
ui.open_play(r, g,
  function(hp) print("WIN hp=" .. hp) end,
  function() print("DEAD") end)
```

Expected: New tab opens with two splits — top is readonly target text, bottom is editable. HUD statusline shows HP bar, streak, and command hint. Pressing wrong keys drains HP. Editing bottom buffer to match target triggers win callback.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add play screen with split buffers and HUD"
```

---

### Task 9: ui.lua — results screen

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Add open_results to ui.lua**

Add before `return M` in `lua/the-vimmer/ui.lua`:

```lua
function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue)
  local width = 50
  local b = make_border(width)
  local lines = {}

  lines[#lines+1] = b.top
  lines[#lines+1] = b.row("  ROOM CLEARED!")
  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row(string.format("  XP Earned:     +%d", xp_earned))
  lines[#lines+1] = b.row(string.format("  HP Remaining:  %d / 100", hp_remaining))
  lines[#lines+1] = b.row(string.format("  Streak:        %d", streak))

  if unlocked_tier then
    lines[#lines+1] = b.sep
    lines[#lines+1] = b.row("  NEW TIER UNLOCKED:")
    lines[#lines+1] = b.row("  " .. unlocked_tier)
  end

  lines[#lines+1] = b.sep
  lines[#lines+1] = b.row("  <Enter> next room   <q> map")
  lines[#lines+1] = b.bot

  local buf, win = open_float(lines, width)

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_continue(false)
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
    on_continue(true)
  end, { buffer = buf, nowait = true, silent = true })
end
```

- [ ] **Step 2: Manual test**

```vim
:lua
local ui = require("the-vimmer.ui")
ui.open_results(75, 50, 3, "Warrior", function(go_map)
  print(go_map and "go to map" or "next room")
end)
```

Expected: Results window shows XP, HP, streak, unlock message. Enter prints "next room". q prints "go to map".

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add results screen UI"
```

---

### Task 10: commands.lua — wire everything together

**Files:**
- Create: `lua/the-vimmer/commands.lua`

- [ ] **Step 1: Implement commands.lua**

Create `lua/the-vimmer/commands.lua`:

```lua
local M = {}

local function deps()
  return {
    ui = require("the-vimmer.ui"),
    game = require("the-vimmer.game"),
    rooms = require("the-vimmer.rooms"),
    progress = require("the-vimmer.progress"),
  }
end

local function build_rooms_by_tier(d)
  local result = {}
  for _, tier in ipairs(d.rooms.all_tiers()) do
    result[tier] = d.rooms.load_tier(tier)
  end
  return result
end

local function check_newly_unlocked(d, prog, rooms_by_tier)
  for _, tier in ipairs(d.rooms.all_tiers()) do
    if not (prog.unlocked_tiers or {})[tier] then
      local total = #(rooms_by_tier[tier] or {})
      if d.progress.is_tier_unlocked(tier, prog.cleared, total) then
        prog.unlocked_tiers = prog.unlocked_tiers or {}
        prog.unlocked_tiers[tier] = true
        return tier:sub(1,1):upper() .. tier:sub(2) .. " tier"
      end
    end
  end
  return nil
end

local function start_flow(room)
  local d = deps()
  local prog = d.progress.load()
  local g = d.game.new()
  g.streak = prog.streak or 0

  local rooms_by_tier = build_rooms_by_tier(d)

  local function show_map()
    prog = d.progress.load()
    d.ui.open_map(prog, build_rooms_by_tier(d), start_flow)
  end

  local function on_win(hp_remaining)
    d.ui._close_play()
    g:complete_room(hp_remaining)

    prog.cleared[room.id] = true
    prog.total_xp = (prog.total_xp or 0) + g.last_xp
    g:dismiss_results()
    prog.streak = g.streak
    local unlocked_msg = check_newly_unlocked(d, prog, rooms_by_tier)
    d.progress.save(prog)

    d.ui.open_results(g.last_xp, hp_remaining, g.streak, unlocked_msg,
      function(go_map)
        if go_map then
          show_map()
          return
        end
        local tier_rooms = d.rooms.load_tier(room.tier)
        local next_room = nil
        for i, r in ipairs(tier_rooms) do
          if r.id == room.id and tier_rooms[i + 1] then
            next_room = tier_rooms[i + 1]
            break
          end
        end
        if next_room then
          start_flow(next_room)
        else
          show_map()
        end
      end)
  end

  local function on_death()
    d.ui._close_play()
    g:retry_room()
    prog.streak = 0
    d.progress.save(prog)
    vim.notify("the-vimmer: 0 HP — retrying room...", vim.log.levels.INFO)
    start_flow(room)
  end

  g:start_room(room)
  d.ui.open_teach(room, function()
    g:begin_play()
    d.ui.open_play(room, g, on_win, on_death)
  end)
end

function M.register()
  vim.api.nvim_create_user_command("VimmerPlay", function(opts)
    local d = deps()
    if opts.args ~= "" then
      local room = d.rooms.get_room(opts.args)
      if not room then
        vim.notify("the-vimmer: room not found: " .. opts.args, vim.log.levels.ERROR)
        return
      end
      start_flow(room)
    else
      local prog = d.progress.load()
      d.ui.open_map(prog, build_rooms_by_tier(d), start_flow)
    end
  end, { nargs = "?", desc = "Play the-vimmer (optional room id)" })

  vim.api.nvim_create_user_command("VimmerProgress", function()
    local prog = deps().progress.load()
    local count = 0
    for _ in pairs(prog.cleared) do count = count + 1 end
    vim.notify(string.format(
      "the-vimmer | XP: %d | Cleared: %d | Streak: %d",
      prog.total_xp, count, prog.streak
    ), vim.log.levels.INFO)
  end, { desc = "Show the-vimmer progress" })

  vim.api.nvim_create_user_command("VimmerReset", function()
    deps().progress.reset()
    vim.notify("the-vimmer: progress reset", vim.log.levels.INFO)
  end, { desc = "Reset all the-vimmer progress" })
end

return M
```

- [ ] **Step 2: Manual full-flow test**

Open Neovim from `/mnt/storage/apps/the_vimmer`:
```vim
:set rtp+=.
:VimmerPlay
```

Checklist:
- Map opens, shows beginner rooms
- j/k navigate, Enter selects a room
- Teach screen shows command info, Enter starts play
- Play screen opens in new tab (target top, editable bottom)
- Matching target text → results screen with XP and streak
- Enter → auto-advances to next room; q → returns to map

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/commands.lua
git commit -m "feat: wire full game flow in commands.lua"
```

---

### Task 11: Beginner rooms

**Files:**
- `lua/rooms/beginner/hjkl.lua` — already created in Task 4
- Create: `lua/rooms/beginner/w_motion.lua`
- Create: `lua/rooms/beginner/b_motion.lua`
- Create: `lua/rooms/beginner/e_motion.lua`
- Create: `lua/rooms/beginner/insert_mode.lua`
- Create: `lua/rooms/beginner/delete_yank.lua`
- Create: `lua/rooms/beginner/undo_redo.lua`

- [ ] **Step 1: Create w_motion.lua**

Create `lua/rooms/beginner/w_motion.lua`:

```lua
return {
  id = "beginner_w_motion",
  tier = "beginner",
  command = "w",
  title = "Word Motion: w",
  description = "Move to the start of the next word",
  before_example = "|fix this line now",
  after_example = "fix |this line now",
  usage_tip = "Jump word by word forward. Faster than holding l.",
  start_text = "fix this line now",
  target_text = "fix this line now",
  base_xp = 40,
  optimal_keystrokes = { "w" },
}
```

- [ ] **Step 2: Create b_motion.lua**

Create `lua/rooms/beginner/b_motion.lua`:

```lua
return {
  id = "beginner_b_motion",
  tier = "beginner",
  command = "b",
  title = "Word Motion: b",
  description = "Move to the start of the previous word",
  before_example = "fix this line |now",
  after_example = "fix this |line now",
  usage_tip = "Jump backward word by word. Pair with w for fast navigation.",
  start_text = "revert this change now",
  target_text = "revert this change now",
  base_xp = 40,
  optimal_keystrokes = { "b" },
}
```

- [ ] **Step 3: Create e_motion.lua**

Create `lua/rooms/beginner/e_motion.lua`:

```lua
return {
  id = "beginner_e_motion",
  tier = "beginner",
  command = "e",
  title = "Word Motion: e",
  description = "Move to the end of the current or next word",
  before_example = "|hello world",
  after_example = "hell|o world",
  usage_tip = "Use e to land at the end of a word, e.g. before appending a char.",
  start_text = "jump to word ends here",
  target_text = "jump to word ends here",
  base_xp = 40,
  optimal_keystrokes = { "e" },
}
```

- [ ] **Step 4: Create insert_mode.lua**

Create `lua/rooms/beginner/insert_mode.lua`:

```lua
return {
  id = "beginner_insert_mode",
  tier = "beginner",
  command = "i / a / o",
  title = "Insert Mode: i, a, o",
  description = "Enter insert mode: before cursor (i), after cursor (a), new line below (o)",
  before_example = "helo world",
  after_example = "hello world",
  usage_tip = "i inserts BEFORE cursor. Move to the gap, press i, type, then <Esc>.",
  start_text = "helo world",
  target_text = "hello world",
  base_xp = 50,
  optimal_keystrokes = { "l", "l", "l", "i", "l", "\27" },
}
```

- [ ] **Step 5: Create delete_yank.lua**

Create `lua/rooms/beginner/delete_yank.lua`:

```lua
return {
  id = "beginner_delete_yank",
  tier = "beginner",
  command = "x / dd / yy / p",
  title = "Delete & Paste: x, dd, yy, p",
  description = "Delete char (x), delete line (dd), yank line (yy), paste (p)",
  before_example = "good line\nbad line\ngood line",
  after_example = "good line\ngood line",
  usage_tip = "dd deletes the whole line into a register. Nothing is truly deleted in Vim.",
  start_text = "good line\nbad line\ngood line",
  target_text = "good line\ngood line",
  base_xp = 60,
  optimal_keystrokes = { "j", "d", "d" },
}
```

- [ ] **Step 6: Create undo_redo.lua**

Create `lua/rooms/beginner/undo_redo.lua`:

```lua
return {
  id = "beginner_undo_redo",
  tier = "beginner",
  command = "u / Ctrl-r",
  title = "Undo & Redo: u, Ctrl-r",
  description = "Undo last change (u), redo an undone change (Ctrl-r)",
  before_example = "correct text (after accidental edit)",
  after_example = "correct text",
  usage_tip = "u is your safety net. Experiment freely knowing you can always undo.",
  start_text = "correct text",
  target_text = "correct text",
  base_xp = 30,
  optimal_keystrokes = { "u" },
}
```

- [ ] **Step 7: Commit**

```bash
git add lua/rooms/beginner/
git commit -m "feat: add all beginner rooms"
```

---

### Task 12: Warrior rooms

**Files:**
- Create: `lua/rooms/warrior/ciw.lua`
- Create: `lua/rooms/warrior/f_motion.lua`
- Create: `lua/rooms/warrior/search.lua`
- Create: `lua/rooms/warrior/percent_motion.lua`
- Create: `lua/rooms/warrior/visual_mode.lua`
- Create: `lua/rooms/warrior/macros_intro.lua`

- [ ] **Step 1: Create ciw.lua**

Create `lua/rooms/warrior/ciw.lua`:

```lua
return {
  id = "warrior_ciw",
  tier = "warrior",
  command = "ciw / caw",
  title = "Change Inner Word: ciw, caw",
  description = "Change the word under cursor. ciw = inner word, caw = word + surrounding space",
  before_example = "the wrong word here",
  after_example = "the right word here",
  usage_tip = "ciw deletes the word under cursor and puts you in insert mode. No manual selecting.",
  start_text = "the wrong word here",
  target_text = "the right word here",
  base_xp = 70,
  optimal_keystrokes = { "w", "c", "i", "w" },
}
```

- [ ] **Step 2: Create f_motion.lua**

Create `lua/rooms/warrior/f_motion.lua`:

```lua
return {
  id = "warrior_f_motion",
  tier = "warrior",
  command = "f<char> / t<char>",
  title = "Find Char: f, t",
  description = "Jump to next occurrence of a char (f lands ON it, t lands BEFORE it)",
  before_example = "|jump to the colon: right here",
  after_example = "jump to the colon|: right here",
  usage_tip = "f: jumps to the colon. Use ; to repeat the jump forward, , to go back.",
  start_text = "jump to the colon: right here",
  target_text = "jump to the colon: right here",
  base_xp = 70,
  optimal_keystrokes = { "f", ":" },
}
```

- [ ] **Step 3: Create search.lua**

Create `lua/rooms/warrior/search.lua`:

```lua
return {
  id = "warrior_search",
  tier = "warrior",
  command = "/ and n / N",
  title = "Search: /, n, N",
  description = "Search forward for a pattern (/), jump to next match (n), previous (N)",
  before_example = "|the quick brown fox jumps over the lazy dog",
  after_example = "the quick brown |fox jumps over the lazy dog",
  usage_tip = "/ followed by your search term then Enter. n hops to next match instantly.",
  start_text = "the quick brown fox jumps over the lazy dog",
  target_text = "the quick brown fox jumps over the lazy dog",
  base_xp = 70,
  optimal_keystrokes = { "/", "f", "o", "x", "\13" },
}
```

- [ ] **Step 4: Create percent_motion.lua**

Create `lua/rooms/warrior/percent_motion.lua`:

```lua
return {
  id = "warrior_percent",
  tier = "warrior",
  command = "%",
  title = "Jump to Match: %",
  description = "Jump between matching bracket pairs: (), [], {}",
  before_example = "|(outer (inner) outer)",
  after_example = "(outer (inner) outer|)",
  usage_tip = "% jumps to the matching bracket. Essential for navigating nested code.",
  start_text = "function foo(bar, baz) { return bar + baz; }",
  target_text = "function foo(bar, baz) { return bar + baz; }",
  base_xp = 70,
  optimal_keystrokes = { "f", "(", "%" },
}
```

- [ ] **Step 5: Create visual_mode.lua**

Create `lua/rooms/warrior/visual_mode.lua`:

```lua
return {
  id = "warrior_visual",
  tier = "warrior",
  command = "v / V / Ctrl-v",
  title = "Visual Mode: v, V, Ctrl-v",
  description = "Select: characters (v), whole lines (V), or a rectangular block (Ctrl-v)",
  before_example = "keep this DELETE_ME keep this",
  after_example = "keep this  keep this",
  usage_tip = "v enters char-wise visual. Extend with motion keys, then d to delete selection.",
  start_text = "keep this DELETE_ME keep this",
  target_text = "keep this  keep this",
  base_xp = 80,
  optimal_keystrokes = { "w", "w", "v", "e", "d" },
}
```

- [ ] **Step 6: Create macros_intro.lua**

Create `lua/rooms/warrior/macros_intro.lua`:

```lua
return {
  id = "warrior_macros",
  tier = "warrior",
  command = "q<reg> to record, @<reg> to replay",
  title = "Macros: q, @",
  description = "Record a macro into a register (qa), stop (q), replay it (@a)",
  before_example = "line one\nline two\nline three",
  after_example = "- line one\n- line two\n- line three",
  usage_tip = "qa records into register a. Do edits. q stops. @a replays. 2@a repeats twice.",
  start_text = "line one\nline two\nline three",
  target_text = "- line one\n- line two\n- line three",
  base_xp = 90,
  optimal_keystrokes = { "q", "a", "I", "-", " ", "\27", "j", "q", "2", "@", "a" },
}
```

- [ ] **Step 7: Commit**

```bash
git add lua/rooms/warrior/
git commit -m "feat: add all warrior rooms"
```

---

### Task 13: Ninja rooms

**Files:**
- Create: `lua/rooms/ninja/text_objects.lua`
- Create: `lua/rooms/ninja/complex_motions.lua`
- Create: `lua/rooms/ninja/registers.lua`
- Create: `lua/rooms/ninja/advanced_macros.lua`

- [ ] **Step 1: Create text_objects.lua**

Create `lua/rooms/ninja/text_objects.lua`:

```lua
return {
  id = "ninja_text_objects",
  tier = "ninja",
  command = "di( / da[ / ci{",
  title = "Text Objects: di(, da[, ci{",
  description = "Operate on text inside or around delimiters without moving cursor first",
  before_example = "call(wrong_arg)",
  after_example = "call()",
  usage_tip = "i = inner (excludes delimiters), a = around (includes them). Works with d/c/y.",
  start_text = "call(wrong_arg)",
  target_text = "call()",
  base_xp = 100,
  optimal_keystrokes = { "f", "(", "d", "i", "(" },
}
```

- [ ] **Step 2: Create complex_motions.lua**

Create `lua/rooms/ninja/complex_motions.lua`:

```lua
return {
  id = "ninja_complex_motions",
  tier = "ninja",
  command = "gg / G / { / }",
  title = "File Motions: gg, G, {, }",
  description = "Jump to file start (gg), file end (G), prev blank-separated block ({), next (})",
  before_example = "|paragraph one\n\nparagraph two",
  after_example = "paragraph one\n\n|paragraph two",
  usage_tip = "G goes to end of file instantly. { and } jump between paragraphs in prose or code.",
  start_text = "paragraph one\n\nparagraph two\n\nparagraph three",
  target_text = "paragraph one\n\nparagraph two\n\nparagraph three",
  base_xp = 90,
  optimal_keystrokes = { "}", "}" },
}
```

- [ ] **Step 3: Create registers.lua**

Create `lua/rooms/ninja/registers.lua`:

```lua
return {
  id = "ninja_registers",
  tier = "ninja",
  command = '"<reg>y and "<reg>p',
  title = "Named Registers: \"ay, \"ap",
  description = 'Yank into a named register ("ay) and paste from it ("ap)',
  before_example = "alpha\nbeta\n\npaste_here",
  after_example = "alpha\nbeta\n\nalpha",
  usage_tip = '"ay yanks the line into register a. "ap pastes it anywhere. Store up to 26 values.',
  start_text = "alpha\nbeta\n\npaste_here",
  target_text = "alpha\nbeta\n\nalpha",
  base_xp = 110,
  optimal_keystrokes = { '"', "a", "y", "y", "j", "j", "j", '"', "a", "p", "d", "d" },
}
```

- [ ] **Step 4: Create advanced_macros.lua**

Create `lua/rooms/ninja/advanced_macros.lua`:

```lua
return {
  id = "ninja_advanced_macros",
  tier = "ninja",
  command = "macro + text objects + repeat",
  title = "Advanced Macros",
  description = "Combine macros with text objects for powerful repeatable bulk edits",
  before_example = 'var foo = "hello"\nvar bar = "world"',
  after_example = 'const foo = "hello"\nconst bar = "world"',
  usage_tip = 'Record: qa ciw const <Esc> j q. Then @a on next line. One macro replaces any word.',
  start_text = 'var foo = "hello"\nvar bar = "world"',
  target_text = 'const foo = "hello"\nconst bar = "world"',
  base_xp = 120,
  optimal_keystrokes = { "q", "a", "c", "i", "w", "c", "o", "n", "s", "t", "\27", "j", "q", "@", "a" },
}
```

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/ninja/
git commit -m "feat: add all ninja rooms"
```

---

### Task 14: Integration and final verification

**Files:**
- No new files. Verify everything wires together.

- [ ] **Step 1: Run full unit test suite**

```bash
busted tests/spec/
```

Expected: All tests pass with 0 failures, 0 errors.

- [ ] **Step 2: Full playthrough — beginner tier**

```vim
:set rtp+=.
:VimmerPlay
```

Checklist:
- [ ] Map opens centered, beginner rooms listed
- [ ] j/k navigate rooms, Enter selects
- [ ] Teach screen shows command, before/after, tip
- [ ] Enter begins play in new tab (target top readonly, edit bottom)
- [ ] HUD statusline shows HP bar, streak, command hint
- [ ] Wrong keys drain HP by 5 each
- [ ] Matching target text triggers results screen
- [ ] Results shows XP, HP, streak
- [ ] Enter auto-advances to next room
- [ ] q returns to map

- [ ] **Step 3: Test HP drain and death**

Play a room, press random keys. Verify:
- HP bar in HUD decreases
- At 0 HP, notification appears: `the-vimmer: 0 HP — retrying room...`
- Room restarts from teach screen
- Streak resets to 0

- [ ] **Step 4: Test persistence**

```vim
:VimmerPlay    " clear one room
:qa            " quit Neovim
nvim
:set rtp+=.
:VimmerProgress
```

Expected notification: `the-vimmer | XP: <N> | Cleared: 1 | Streak: <N>`

- [ ] **Step 5: Test tier unlock**

Clear 6 or more of 7 beginner rooms. Open map. Verify Warrior tier no longer shows "locked".

- [ ] **Step 6: Test VimmerReset**

```vim
:VimmerReset
:VimmerProgress
```

Expected: `XP: 0 | Cleared: 0 | Streak: 0`

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "feat: complete the-vimmer — neovim shortcut dungeon game"
```
