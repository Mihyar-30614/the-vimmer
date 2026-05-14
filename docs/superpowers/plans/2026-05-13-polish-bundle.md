# Polish Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land five small hygiene fixes — wall-clock timer, room-loader cache, dead-ref cleanup, dup-warning suppression, and an opt-in colorblind palette — without touching the larger `ui.lua` module split (deferred to 6b).

**Architecture:** Each unit is isolated to one or two files. Game `run_seconds` source moves behind a `_now()` selector with a busted-friendly fallback. Room loader gains a module-level cache. Dead combo-era highlights and namespace declarations are removed. Duplicate-room-ID notifications become silent. Highlights module gains two named palette tables driven by a `setup({ colorblind = true })` flag stored on the entry module.

**Tech Stack:** Lua 5.1+ / LuaJIT, Neovim 0.8+, busted (`~/.luarocks/bin/busted tests/spec/`).

**Spec:** `docs/superpowers/specs/2026-05-13-polish-bundle-design.md`

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `lua/the-vimmer/game.lua` | `_now()` helper + two call-sites | Modify |
| `lua/the-vimmer/rooms.lua` | `_tier_cache` + silent dup skip | Modify |
| `lua/the-vimmer/highlights.lua` | drop combo refs + two-palette setup | Modify |
| `lua/the-vimmer/ui.lua` | drop orphan `_crit_ns` namespace | Modify |
| `lua/the-vimmer/init.lua` | store `M.config.colorblind` | Modify |
| `tests/spec/rooms_spec.lua` | cache identity + clear_cache tests | Modify |
| `tests/spec/highlights_spec.lua` | smoke-load via headless nvim | Modify |

---

## Task 1: `_now()` helper in `game.lua`

**Files:**
- Modify: `lua/the-vimmer/game.lua:1` (insert helper near top)
- Modify: `lua/the-vimmer/game.lua` (two `os.clock()` call sites)
- Modify: `tests/spec/game_spec.lua` (append small sentinel test)

- [ ] **Step 1.1: Add sentinel test that `run_started_at` is a number after `begin_play`**

Append to `tests/spec/game_spec.lua`:

```lua
describe("game wall-clock timer", function()
  it("run_started_at is a number after begin_play (headless busted)", function()
    local g = game.new()
    g:start_room(make_room())
    g:begin_play()
    assert.equals("number", type(g.run_started_at))
  end)

  it("run_seconds is a non-negative number after complete_room", function()
    local g = game.new()
    g:start_room(make_room())
    g:begin_play()
    g:register_key("w")
    g:complete_room()
    assert.equals("number", type(g.run_seconds))
    assert.is_true(g.run_seconds >= 0)
  end)
end)
```

- [ ] **Step 1.2: Run tests — they should already pass (regression sentinel)**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua --filter "wall-clock"`

Expected: 2 successes.

- [ ] **Step 1.3: Insert `_now()` helper at top of `game.lua`**

Open `lua/the-vimmer/game.lua`. After line 1 (`local M = {}`), insert:

```lua

-- Prefer wall-clock time via vim.loop when available; fall back to os.clock for headless busted.
local _now
if type(vim) == "table" and type(vim.loop) == "table" and type(vim.loop.now) == "function" then
  _now = function() return vim.loop.now() / 1000 end
else
  _now = os.clock
end
```

- [ ] **Step 1.4: Replace both `os.clock()` call sites**

Locate `self.run_started_at = os.clock()` in `begin_play` — replace with:

```lua
    self.run_started_at = _now()
```

Locate `self.run_seconds = self.run_started_at and math.max(0, os.clock() - self.run_started_at) or nil`
in `complete_room` — replace with:

```lua
    self.run_seconds = self.run_started_at and math.max(0, _now() - self.run_started_at) or nil
```

- [ ] **Step 1.5: Run full game spec**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua`

Expected: all green.

- [ ] **Step 1.6: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "refactor(game): use vim.loop.now for run_seconds, fall back to os.clock"
```

---

## Task 2: `load_tier` cache in `rooms.lua`

**Files:**
- Modify: `lua/the-vimmer/rooms.lua` (module-level cache + `M.clear_cache`)
- Modify: `tests/spec/rooms_spec.lua` (append describe block)

- [ ] **Step 2.1: Add failing tests for cache identity + clear_cache**

Append to `tests/spec/rooms_spec.lua`:

```lua
describe("rooms.load_tier cache", function()
  before_each(function()
    if rooms.clear_cache then rooms.clear_cache() end
  end)

  it("returns the same table on repeat calls", function()
    local a = rooms.load_tier("beginner")
    local b = rooms.load_tier("beginner")
    assert.is_true(a == b, "expected identical table reference on second call")
  end)

  it("clear_cache forces a fresh load (different table identity)", function()
    local a = rooms.load_tier("beginner")
    rooms.clear_cache()
    local b = rooms.load_tier("beginner")
    assert.is_false(a == b, "expected fresh table after clear_cache")
  end)
end)
```

- [ ] **Step 2.2: Run tests to confirm both fail**

Run: `~/.luarocks/bin/busted tests/spec/rooms_spec.lua --filter "cache"`

Expected: 2 failures (returns fresh table each call; `clear_cache` is nil).

- [ ] **Step 2.3: Add cache + helper to `rooms.lua`**

Open `lua/the-vimmer/rooms.lua`. Near the top (after `local TIERS = ...`), insert:

```lua

-- Cache of validated rooms per tier; populated lazily by load_tier, reset via clear_cache.
local _tier_cache = {}
```

Then in `M.load_tier(tier)`, wrap the existing body. Replace the entire function with:

```lua
function M.load_tier(tier)
  if _tier_cache[tier] then return _tier_cache[tier] end

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
        -- silent: duplicates are typically room-pack vs built-in overlap, not user-facing
      else
        seen_ids[room.id] = true
        result[#result + 1] = room
      end
    elseif vim and vim.notify then
      vim.notify("the-vimmer: skipping invalid room: " .. filepath, vim.log.levels.WARN)
    end
  end

  _tier_cache[tier] = result
  return result
end

function M.clear_cache()
  _tier_cache = {}
end
```

Note: this single edit completes both Unit 2 (cache) and Unit 4 (silent
dup skip). The dup-warn line is gone in the new function body.

- [ ] **Step 2.4: Run tests to verify**

Run: `~/.luarocks/bin/busted tests/spec/rooms_spec.lua`

Expected: all green (existing tests still pass; new cache tests now pass).

- [ ] **Step 2.5: Run full suite**

Run: `~/.luarocks/bin/busted tests/spec/`

Expected: all green.

- [ ] **Step 2.6: Commit**

```bash
git add lua/the-vimmer/rooms.lua tests/spec/rooms_spec.lua
git commit -m "feat(rooms): cache load_tier output, drop dup-id warning"
```

---

## Task 3: Drop dead combo references

**Files:**
- Modify: `lua/the-vimmer/highlights.lua` (delete combo_group + 3 highlight groups + module-header comment)
- Modify: `lua/the-vimmer/ui.lua:821` (delete orphan namespace)

- [ ] **Step 3.1: Verify no remaining callers**

Run: `grep -rn "combo_group\|VimmerComboFire\|VimmerComboCrit\|VimmerRegen\|VimmerCrit\b\|_crit_ns" lua/ tests/`

Expected: only the definitions in `highlights.lua` and `ui.lua:821`. No usage in any other file. (`VimmerCrit` and `_crit_ns` were referenced only inside the CRIT-row branch removed in sub-project 1.)

If anything else turns up, stop and investigate.

- [ ] **Step 3.2: Update module header comment in `highlights.lua`**

Open `lua/the-vimmer/highlights.lua`. Replace line 2:

```lua
-- hp_group / timer_group / combo_group map numeric game state → a highlight group name.
```

with:

```lua
-- hp_group / timer_group map numeric game state → a highlight group name.
```

- [ ] **Step 3.3: Delete `M.combo_group`**

Remove lines 51–57 of `highlights.lua` (the `function M.combo_group(combo)` block and its leading comment on line 51):

```lua
-- Return a highlight group for the combo counter, or nil when combo is below 5.
function M.combo_group(combo)
  if combo >= 20 then return "VimmerComboCrit"
  elseif combo >= 10 then return "VimmerComboFire"
  elseif combo >= 5 then return "VimmerPhase"
  else return nil end
end
```

- [ ] **Step 3.4: Delete dead highlight definitions inside `M.setup()`**

In the `M.setup()` body, remove these four lines:

```lua
  hl(0, "VimmerRegen",        { bg = "#0d3b1a", fg = "#80ff99" })
  hl(0, "VimmerCrit",         { bg = "#5c4a00", fg = "#ffd700" })
  hl(0, "VimmerComboFire",    { bold = true,    fg = "#ff8c00" })
  hl(0, "VimmerComboCrit",    { bold = true,    fg = "#ff00cc" })
```

- [ ] **Step 3.5: Delete orphan namespace in `ui.lua`**

Open `lua/the-vimmer/ui.lua`. Locate line 821:

```lua
  local _crit_ns = api.nvim_create_namespace("the-vimmer-crit")
```

Delete that single line.

- [ ] **Step 3.6: Smoke check + run suite**

```bash
nvim --headless -c "lua require('the-vimmer').setup({})" -c "qa!" 2>&1
~/.luarocks/bin/busted tests/spec/
```

Expected: no errors from nvim; all busted tests green.

- [ ] **Step 3.7: Commit**

```bash
git add lua/the-vimmer/highlights.lua lua/the-vimmer/ui.lua
git commit -m "chore: drop dead combo highlights, combo_group, and orphan crit namespace"
```

---

## Task 4: Colorblind palette toggle

**Files:**
- Modify: `lua/the-vimmer/init.lua` (store `M.config.colorblind`)
- Modify: `lua/the-vimmer/highlights.lua` (palette tables + selector)

- [ ] **Step 4.1: Extend `init.lua` to read `colorblind` opt**

Replace `lua/the-vimmer/init.lua` with:

```lua
-- Plugin entry point. Call M.setup(opts) from your Neovim config.
-- opts.hooks    = { win = fn, death = fn } — lifecycle callbacks (see callbacks.lua).
-- opts.colorblind = true  — switch to a deuteranopia-safe palette (Wong/Okabe).
local M = {}

M.config = M.config or {}

--- @param opts? table optional `{ hooks = ..., colorblind = bool }`
function M.setup(opts)
  opts = opts or {}
  M.config.colorblind = opts.colorblind == true
  require("the-vimmer.highlights").setup()
  require("the-vimmer.commands").register(opts)
end

return M
```

- [ ] **Step 4.2: Add palette tables to `highlights.lua`**

Open `lua/the-vimmer/highlights.lua`. Above the `function M.setup()` line,
insert:

```lua

-- Highlight groups whose meaning depends on red/green; remap under colorblind mode.
local PALETTE_DEFAULT = {
  VimmerHP_high     = { fg = "#50fa7b" },
  VimmerHP_mid      = { fg = "#ffb86c" },
  VimmerHP_low      = { fg = "#ff5555" },
  VimmerDamage      = { bg = "#5c1010", fg = "#ff8080" },
  VimmerWin         = { bg = "#50fa7b", fg = "#282a36" },
  VimmerDeath       = { bold = true, fg = "#ff5555" },
  VimmerTimerOk     = { bold = true, fg = "#50fa7b" },
  VimmerTimerDanger = { bold = true, fg = "#ff5555" },
  VimmerXP          = { bold = true, fg = "#f1fa8c" },
  VimmerCleared     = { fg = "#50fa7b" },
}

-- Wong/Okabe deuteranopia-safe palette for the colorblind opt-in.
local PALETTE_CB = {
  VimmerHP_high     = { fg = "#56b4e9" },
  VimmerHP_mid      = { fg = "#f0e442" },
  VimmerHP_low      = { fg = "#e69f00" },
  VimmerDamage      = { bg = "#3a2400", fg = "#e69f00" },
  VimmerWin         = { bg = "#56b4e9", fg = "#282a36" },
  VimmerDeath       = { bold = true, fg = "#d55e00" },
  VimmerTimerOk     = { bold = true, fg = "#56b4e9" },
  VimmerTimerDanger = { bold = true, fg = "#d55e00" },
  VimmerXP          = { bold = true, fg = "#f0e442" },
  VimmerCleared     = { fg = "#56b4e9" },
}

local function palette()
  local ok, root = pcall(require, "the-vimmer")
  if ok and root and root.config and root.config.colorblind then
    return PALETTE_CB
  end
  return PALETTE_DEFAULT
end
```

- [ ] **Step 4.3: Rewrite `M.setup` to use the palette table**

Replace the existing `function M.setup() … end` body with:

```lua
function M.setup()
  local hl = vim.api.nvim_set_hl
  local p = palette()
  hl(0, "VimmerTitle",        { bold = true, fg = "#ffffff" })
  hl(0, "VimmerTierBeginner", { bold = true, fg = "#8be9fd" })
  hl(0, "VimmerTierWarrior",  { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTierNinja",    { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerCleared",      p.VimmerCleared)
  hl(0, "VimmerLocked",       { fg = "#6272a4" })
  hl(0, "VimmerSelected",     { bold = true, reverse = true })
  hl(0, "VimmerXP",           p.VimmerXP)
  hl(0, "VimmerHP_high",      p.VimmerHP_high)
  hl(0, "VimmerHP_mid",       p.VimmerHP_mid)
  hl(0, "VimmerHP_low",       p.VimmerHP_low)
  hl(0, "VimmerWin",          p.VimmerWin)
  hl(0, "VimmerDeath",        p.VimmerDeath)
  hl(0, "VimmerCommand",      { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerExample",      { fg = "#8be9fd" })
  hl(0, "VimmerTimerOk",      p.VimmerTimerOk)
  hl(0, "VimmerTimerWarn",    { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTimerDanger",  p.VimmerTimerDanger)
  hl(0, "VimmerBoss",         { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerPhase",        { bold = true, bg = "#44475a", fg = "#ff79c6" })
  hl(0, "VimmerDamage",       p.VimmerDamage)
  hl(0, "VimmerTeachTip",     { fg = "#bcc4ea" })
  hl(0, "VimmerTeachFoot",    { fg = "#6272a4" })
end
```

(Notice this list is the original minus the four entries removed in
Task 3. If any of those lines reappear, that's a merge artifact — delete
them.)

- [ ] **Step 4.4: Smoke check both palettes**

Default palette:

```bash
nvim --headless -c "lua require('the-vimmer').setup({})" -c "lua print(vim.fn.synIDattr(vim.fn.hlID('VimmerHP_low'), 'fg'))" -c "qa!" 2>&1
```

Expected: `#ff5555` (or matching colour name).

Colorblind palette:

```bash
nvim --headless -c "lua require('the-vimmer').setup({ colorblind = true })" -c "lua print(vim.fn.synIDattr(vim.fn.hlID('VimmerHP_low'), 'fg'))" -c "qa!" 2>&1
```

Expected: `#e69f00`.

- [ ] **Step 4.5: Run full busted suite**

Run: `~/.luarocks/bin/busted tests/spec/`

Expected: all green.

- [ ] **Step 4.6: Commit**

```bash
git add lua/the-vimmer/init.lua lua/the-vimmer/highlights.lua
git commit -m "feat: opt-in colorblind palette via setup({ colorblind = true })"
```

---

## Task 5: README colorblind opt mention

**Files:**
- Modify: `README.md` (note the new opt on the setup table)

- [ ] **Step 5.1: Update README**

In `README.md`, locate the lazy.nvim example (around line 38–50). After
the `hooks = { ... }` block inside the `setup()` table, add a comment line:

```lua
  config = function()
    require("the-vimmer").setup({
      colorblind = false, -- set true for a deuteranopia-safe palette
      hooks = {
```

Apply the same `colorblind = false,` comment line above the `hooks` block
in the packer example too. No content change to the `:VimmerProgress` /
mutator tables.

- [ ] **Step 5.2: Commit**

```bash
git add README.md
git commit -m "docs(readme): document colorblind setup opt"
```

---

## Task 6: Final suite + manual smoke

**Files:**
- None — verification only.

- [ ] **Step 6.1: Run entire busted suite**

Run: `~/.luarocks/bin/busted tests/spec/`

Expected: all green, count ≥ 107 (was 105 before; this bundle adds 4 new
tests).

- [ ] **Step 6.2: Headless smoke load with both palette settings**

```bash
nvim --headless -c "lua require('the-vimmer').setup({})" -c "qa!" 2>&1
nvim --headless -c "lua require('the-vimmer').setup({ colorblind = true })" -c "qa!" 2>&1
```

Expected: no output (no Lua errors).

- [ ] **Step 6.3: Quick git log check**

```bash
git log --oneline -8
```

Expected: 5 new commits from this bundle (Task 1 timer, Task 2 cache, Task 3
cleanup, Task 4 colorblind, Task 5 readme).

---

## Self-review notes

- **Spec coverage:**
  - Unit 1 (wall-clock timer) → Task 1.
  - Unit 2 (`load_tier` cache) → Task 2 (cache half).
  - Unit 3 (dead combo refs cleanup) → Task 3.
  - Unit 4 (dup-warn suppression) → Task 2 (silent skip half).
  - Unit 5 (colorblind palette) → Task 4 + Task 5 (README).
- **Placeholder scan:** No TBD/TODO. All replacement code shown in full.
- **Type consistency:** `M.config.colorblind` (boolean) is the only new
  cross-module signal; `palette()` selector uses the same key. `_now()`
  has the same return shape (seconds, number) as `os.clock()`.
- **Coverage gap fixes:** Task 5 (README) wasn't in the spec but is the
  right place to surface the new opt; included so users discover it.
