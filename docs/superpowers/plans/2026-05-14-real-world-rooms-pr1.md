# Real-World Rooms — PR 1 (Engine Support) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add engine support for real-world scenario rooms — three optional schema fields (`filetype`, `cursor_start`, `goal`), play-time application of those fields, buffer hygiene against user plugins, and a reachability harness that verifies every room's keystroke sequence actually reaches `target_text`. No room content is rewritten in this PR.

**Architecture:** Schema additions are validator-only changes in `lua/the-vimmer/rooms.lua`. UI plumbing lands in `lua/the-vimmer/ui/play.lua` (cursor placement, filetype, buffer hygiene, HUD goal line) and `lua/the-vimmer/ui/teach.lua` (teach-screen goal line). Reachability harness is a standalone Lua script invoked from headless nvim, looping every loaded room and verifying its primary + alternate keystroke sequences. All new schema fields are optional and default to current behavior, so existing rooms keep loading unchanged.

**Tech Stack:** Lua 5.1 (via LuaJIT in Neovim), Neovim 0.8+ API, busted (headless tests with stubbed vim global), headless nvim invocation for integration-style reachability checks.

---

## File Structure

| File | Status | Responsibility |
|------|--------|----------------|
| `lua/the-vimmer/rooms.lua` | Modify | Extend `M.validate` with optional-field type checks. Validator now accepts/rejects `filetype`, `cursor_start`, `goal` at room level and (for boss) per phase. |
| `lua/the-vimmer/ui/play.lua` | Modify | In `start_phase`, set `filetype` on play_buf, move cursor to `cursor_start`, apply buffer hygiene (`buftype=nofile`, detach LSP, set common disable flags). Extend HUD `update_hud` to render `goal` line when present. |
| `lua/the-vimmer/ui/teach.lua` | Modify | Render `goal` line on teach screen for non-boss rooms; render per-phase goal for boss rooms. |
| `tests/spec/rooms_spec.lua` | Modify | Add validator tests for the three new optional fields, covering accept-when-valid, accept-when-absent, and reject-when-malformed. Cover boss per-phase too. |
| `tests/reachability.lua` | Create | Standalone harness. Run via `nvim --headless --noplugin -l tests/reachability.lua`. Loops every room across all tiers, sets up a scratch buffer with `start_text` + `bo` overrides + `cursor_start`, feeds primary `optimal_keystrokes` (and each alternate) via `nvim_feedkeys` in `'nx'` mode, asserts resulting buffer matches `target_text`. Exit 0 on full pass, 1 on any failure with per-room error lines on stderr. |
| `README.md` | Modify | Add a short "Tests" subsection documenting the busted command and the new `nvim --headless -l tests/reachability.lua` invocation. |

---

## Task 1: Validator accepts and rejects new optional fields

**Files:**
- Modify: `lua/the-vimmer/rooms.lua` (function `M.validate`)
- Modify: `tests/spec/rooms_spec.lua` (new describe blocks)

- [ ] **Step 1: Write the failing tests for `filetype`**

Add these blocks at the end of `tests/spec/rooms_spec.lua`, before the final newline:

```lua
describe("rooms.validate optional filetype", function()
  local base = {
    id = "t", tier = "beginner", command = "w",
    title = "T", description = "D",
    before_example = "a", after_example = "b",
    usage_tip = "tip", start_text = "x", target_text = "y",
    base_xp = 10, optimal_keystrokes = { "w" },
  }
  local function clone() local r = {}; for k, v in pairs(base) do r[k] = v end; return r end

  it("accepts room without filetype", function()
    assert.is_true(rooms.validate(clone()))
  end)

  it("accepts room with string filetype", function()
    local r = clone(); r.filetype = "typescript"
    assert.is_true(rooms.validate(r))
  end)

  it("rejects room with non-string filetype", function()
    local r = clone(); r.filetype = 123
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.validate optional cursor_start", function()
  local base = {
    id = "t", tier = "beginner", command = "w",
    title = "T", description = "D",
    before_example = "a", after_example = "b",
    usage_tip = "tip", start_text = "x", target_text = "y",
    base_xp = 10, optimal_keystrokes = { "w" },
  }
  local function clone() local r = {}; for k, v in pairs(base) do r[k] = v end; return r end

  it("accepts room without cursor_start", function()
    assert.is_true(rooms.validate(clone()))
  end)

  it("accepts room with valid cursor_start", function()
    local r = clone(); r.cursor_start = { row = 3, col = 5 }
    assert.is_true(rooms.validate(r))
  end)

  it("rejects cursor_start with non-table value", function()
    local r = clone(); r.cursor_start = "1,1"
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with missing row", function()
    local r = clone(); r.cursor_start = { col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with non-integer row", function()
    local r = clone(); r.cursor_start = { row = 1.5, col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with row < 1", function()
    local r = clone(); r.cursor_start = { row = 0, col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with col < 1", function()
    local r = clone(); r.cursor_start = { row = 1, col = 0 }
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.validate optional goal", function()
  local base = {
    id = "t", tier = "beginner", command = "w",
    title = "T", description = "D",
    before_example = "a", after_example = "b",
    usage_tip = "tip", start_text = "x", target_text = "y",
    base_xp = 10, optimal_keystrokes = { "w" },
  }
  local function clone() local r = {}; for k, v in pairs(base) do r[k] = v end; return r end

  it("accepts room without goal", function()
    assert.is_true(rooms.validate(clone()))
  end)

  it("accepts room with string goal", function()
    local r = clone(); r.goal = "Rename param"
    assert.is_true(rooms.validate(r))
  end)

  it("rejects room with non-string goal", function()
    local r = clone(); r.goal = { "bad" }
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.validate boss phase optional fields", function()
  local base_boss = {
    id = "tb", tier = "warrior", is_boss = true,
    command = "X", title = "B", description = "D",
    usage_tip = "tip", base_xp = 300, time_limit = 100,
    phases = {
      { start_text = "a", target_text = "b", optimal_keystrokes = { "x" }, tip = "p1" },
    },
  }
  local function clone()
    local r = {}; for k, v in pairs(base_boss) do r[k] = v end
    r.phases = { {} }
    for k, v in pairs(base_boss.phases[1]) do r.phases[1][k] = v end
    return r
  end

  it("accepts boss with valid per-phase filetype/cursor_start/goal", function()
    local r = clone()
    r.phases[1].filetype = "lua"
    r.phases[1].cursor_start = { row = 1, col = 1 }
    r.phases[1].goal = "do the thing"
    assert.is_true(rooms.validate(r))
  end)

  it("rejects boss with malformed per-phase cursor_start", function()
    local r = clone()
    r.phases[1].cursor_start = { row = 0, col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects boss with non-string per-phase filetype", function()
    local r = clone()
    r.phases[1].filetype = 7
    assert.is_false(rooms.validate(r))
  end)
end)
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
busted --helper=tests/spec/helpers.lua tests/spec/rooms_spec.lua
```

Expected: the new accept-and-reject tests fail because validator does not yet inspect the new fields. The "accepts room without X" tests should already pass (current validator simply ignores extra fields). Confirm at least the malformed-input tests fail (validator returns `true` when it should return `false`).

- [ ] **Step 3: Extend validator in `lua/the-vimmer/rooms.lua`**

Replace the body of `M.validate` and add a helper above it. Find the existing block:

```lua
-- Validate required room fields; boss rooms have a different required set (phases instead of start/target).
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
```

Replace with:

```lua
-- Validate the optional cursor_start field: nil or { row=int>=1, col=int>=1 }.
local function validate_cursor_start(cs)
  if cs == nil then return true end
  if type(cs) ~= "table" then return false end
  local r, c = cs.row, cs.col
  if type(r) ~= "number" or type(c) ~= "number" then return false end
  if r < 1 or c < 1 then return false end
  if r ~= math.floor(r) or c ~= math.floor(c) then return false end
  return true
end

-- Validate the optional filetype field: nil or non-empty string.
local function validate_filetype(ft)
  if ft == nil then return true end
  return type(ft) == "string" and #ft > 0
end

-- Validate the optional goal field: nil or string.
local function validate_goal(g)
  if g == nil then return true end
  return type(g) == "string"
end

-- Validate the optional schema additions shared by rooms and boss phases.
local function validate_optional_additions(ctx)
  if not validate_filetype(ctx.filetype) then return false end
  if not validate_cursor_start(ctx.cursor_start) then return false end
  if not validate_goal(ctx.goal) then return false end
  return true
end

-- Validate required room fields; boss rooms have a different required set (phases instead of start/target).
function M.validate(room)
  if room.is_boss then
    for _, field in ipairs(BOSS_REQUIRED) do
      if room[field] == nil then return false end
    end
    if type(room.phases) ~= "table" or #room.phases < 1 then return false end
    if not validate_optional_additions(room) then return false end
    for _, phase in ipairs(room.phases) do
      if not phase.start_text or not phase.target_text or not phase.optimal_keystrokes then
        return false
      end
      if not validate_alternates(phase.optimal_keystrokes_alternates) then return false end
      if not validate_optional_additions(phase) then return false end
    end
    return true
  end
  for _, field in ipairs(REQUIRED_FIELDS) do
    if room[field] == nil then return false end
  end
  if not validate_alternates(room.optimal_keystrokes_alternates) then return false end
  if not validate_optional_additions(room) then return false end
  return true
end
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
busted --helper=tests/spec/helpers.lua tests/spec/rooms_spec.lua
```

Expected: all tests in the file pass, including the new blocks.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/rooms.lua tests/spec/rooms_spec.lua
git commit -m "feat(rooms): validate optional filetype, cursor_start, goal"
```

---

## Task 2: Default helper for resolving optional fields with fallbacks

**Files:**
- Modify: `lua/the-vimmer/rooms.lua`
- Modify: `tests/spec/rooms_spec.lua`

This task exposes a small `M.phase_view` helper that returns a normalized view of a room or boss-phase context: `{ filetype, cursor_start, goal, start_text, target_text, optimal_keystrokes, optimal_keystrokes_alternates, bo }` with defaults applied. The UI uses this so it never branches on `is_boss` for the new fields.

- [ ] **Step 1: Write the failing tests**

Add to the end of `tests/spec/rooms_spec.lua`:

```lua
describe("rooms.phase_view", function()
  it("returns defaults when fields absent", function()
    local v = rooms.phase_view({
      start_text = "x", target_text = "y",
      optimal_keystrokes = { "w" },
    })
    assert.equals("", v.filetype)
    assert.same({ row = 1, col = 1 }, v.cursor_start)
    assert.is_nil(v.goal)
    assert.equals("x", v.start_text)
    assert.equals("y", v.target_text)
  end)

  it("passes through provided values", function()
    local v = rooms.phase_view({
      start_text = "x", target_text = "y",
      optimal_keystrokes = { "w" },
      filetype = "lua",
      cursor_start = { row = 4, col = 2 },
      goal = "G",
      bo = { shiftwidth = 4 },
      optimal_keystrokes_alternates = { { "a" } },
    })
    assert.equals("lua", v.filetype)
    assert.same({ row = 4, col = 2 }, v.cursor_start)
    assert.equals("G", v.goal)
    assert.same({ shiftwidth = 4 }, v.bo)
    assert.same({ { "a" } }, v.optimal_keystrokes_alternates)
  end)
end)
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
busted --helper=tests/spec/helpers.lua tests/spec/rooms_spec.lua
```

Expected: `attempt to call field 'phase_view' (a nil value)`.

- [ ] **Step 3: Implement `M.phase_view` in `lua/the-vimmer/rooms.lua`**

Add this function near `M.acceptable_key_sequences`:

```lua
-- Return a normalized view of a room or boss-phase context with defaults applied.
-- UI calls this so it never needs to branch on missing optional fields.
function M.phase_view(ctx)
  return {
    filetype = ctx.filetype or "",
    cursor_start = ctx.cursor_start or { row = 1, col = 1 },
    goal = ctx.goal,
    start_text = ctx.start_text,
    target_text = ctx.target_text,
    optimal_keystrokes = ctx.optimal_keystrokes,
    optimal_keystrokes_alternates = ctx.optimal_keystrokes_alternates,
    bo = ctx.bo,
  }
end
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
busted --helper=tests/spec/helpers.lua tests/spec/rooms_spec.lua
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/rooms.lua tests/spec/rooms_spec.lua
git commit -m "feat(rooms): add phase_view helper for normalized context"
```

---

## Task 3: Apply filetype and cursor_start in play.lua

**Files:**
- Modify: `lua/the-vimmer/ui/play.lua` (function `start_phase`, lines 189-203 area)

This task is UI plumbing in a function that's only meaningful inside real nvim. No automated test — change is verified by a manual run-room smoke test plus by the reachability harness in Task 7 (which exercises the same cursor + filetype code path).

- [ ] **Step 1: Edit `start_phase` in `lua/the-vimmer/ui/play.lua`**

Find the existing block in `start_phase`:

```lua
  local function start_phase(phase_data)
    local target_lines = vim.split(phase_data.target_text, "\n")

    api.nvim_buf_set_option(target_buf, "modifiable", true)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
    api.nvim_buf_set_option(target_buf, "modifiable", false)

    api.nvim_buf_set_lines(play_buf, 0, -1, false, vim.split(phase_data.start_text, "\n"))

    local bo = phase_data.bo or room.bo
    if type(bo) == "table" then
      for k, v in pairs(bo) do
        vim.bo[play_buf][k] = v
      end
    end
```

Replace with:

```lua
  local function start_phase(phase_data)
    local rooms = require("the-vimmer.rooms")
    local view = rooms.phase_view(phase_data)
    local target_lines = vim.split(view.target_text, "\n")

    api.nvim_buf_set_option(target_buf, "modifiable", true)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
    api.nvim_buf_set_option(target_buf, "modifiable", false)

    api.nvim_buf_set_lines(play_buf, 0, -1, false, vim.split(view.start_text, "\n"))

    local bo = view.bo or room.bo
    if type(bo) == "table" then
      for k, v in pairs(bo) do
        vim.bo[play_buf][k] = v
      end
    end

    if view.filetype ~= "" then
      vim.bo[play_buf].filetype = view.filetype
      vim.bo[target_buf].filetype = view.filetype
    end

    pcall(api.nvim_win_set_cursor, play_win, { view.cursor_start.row, view.cursor_start.col - 1 })
```

Note: `nvim_win_set_cursor` is 1-indexed for row, 0-indexed for col, so we subtract 1 from `cursor_start.col`. The `pcall` swallows errors if the cursor row exceeds buffer line count — a misconfigured room should not crash play.

- [ ] **Step 2: Manual smoke test**

```bash
nvim --noplugin -c "set rtp+=$(pwd)" -c "lua require('the-vimmer').setup({})" -c "lua require('the-vimmer.ui').open_room(require('the-vimmer.rooms').get_room('beginner_hjkl'))"
```

Expected: room opens normally, cursor sits at line 1 col 1 (existing rooms have no `cursor_start`, so default applies). No errors in `:messages`.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui/play.lua
git commit -m "feat(play): apply filetype and cursor_start from room schema"
```

---

## Task 4: Buffer hygiene against user plugins

**Files:**
- Modify: `lua/the-vimmer/ui/play.lua`

Setting `filetype = "typescript"` will trigger LSP, autopairs, completion, snippets etc. on the play buffer, which can:
- Insert extra characters (autopairs) that break keystroke sequences
- Steal focus / popups that interfere with `vim.on_key`
- Cost startup time

Mitigations applied to both `play_buf` and `target_buf`:
- `buftype=nofile` (prevents writes, signals "scratch")
- `bufhidden=wipe` (already set)
- Disable common-plugin behaviors via buffer-local flags
- Detach any LSP clients that attached anyway

- [ ] **Step 1: Add a buffer-hygiene helper near the top of `lua/the-vimmer/ui/play.lua`**

Insert this function after the `show_phase_banner` function (~line 31), before `function M.open_play`:

```lua
-- Apply plugin-isolation settings to a scratch buffer used for room play.
-- Sets buftype, disables common plugin behaviors, and detaches LSP clients.
local function apply_buffer_hygiene(buf)
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "swapfile", false)
  api.nvim_buf_set_option(buf, "undolevels", 1000)
  for _, flag in ipairs({
    "minipairs_disable",
    "autopairs_disable",
    "copilot_enabled",
    "copilot_disable",
    "ai_enabled",
  }) do
    pcall(api.nvim_buf_set_var, buf, flag, flag == "copilot_enabled" and 0 or 1)
  end
  if vim.lsp and vim.lsp.get_clients then
    local ok, clients = pcall(vim.lsp.get_clients, { bufnr = buf })
    if ok and type(clients) == "table" then
      for _, client in ipairs(clients) do
        pcall(vim.lsp.buf_detach_client, buf, client.id)
      end
    end
  end
end
```

- [ ] **Step 2: Call the helper on both scratch buffers**

In `M.open_play`, find this block (~lines 41-49):

```lua
  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")

  local hud_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(hud_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(hud_buf, "modifiable", false)
```

Replace with:

```lua
  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")
  apply_buffer_hygiene(target_buf)

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")
  apply_buffer_hygiene(play_buf)

  local hud_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(hud_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(hud_buf, "modifiable", false)
```

`hud_buf` does not need full hygiene — it's never typed into.

- [ ] **Step 3: Re-detach LSP after filetype is set**

LSP attaches on `FileType` event. Detaching once before the filetype is set will miss the new attach. In `start_phase`, after the filetype-setting block from Task 3, add a deferred re-detach:

Find the block from Task 3:

```lua
    if view.filetype ~= "" then
      vim.bo[play_buf].filetype = view.filetype
      vim.bo[target_buf].filetype = view.filetype
    end
```

Replace with:

```lua
    if view.filetype ~= "" then
      vim.bo[play_buf].filetype = view.filetype
      vim.bo[target_buf].filetype = view.filetype
      vim.schedule(function()
        if api.nvim_buf_is_valid(play_buf) then apply_buffer_hygiene(play_buf) end
        if api.nvim_buf_is_valid(target_buf) then apply_buffer_hygiene(target_buf) end
      end)
    end
```

- [ ] **Step 4: Manual smoke test**

In a Neovim install with at least one LSP / autopairs plugin loaded:

```bash
nvim -c "set rtp+=$(pwd)" -c "lua require('the-vimmer').setup({})" -c "lua require('the-vimmer.ui').open_room(require('the-vimmer.rooms').get_room('beginner_hjkl'))"
```

Press `i` to enter insert, type `(`. Expected: no matching `)` auto-inserted. Run `:LspInfo` if available — expected: no clients attached to room buffer.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui/play.lua
git commit -m "feat(play): isolate room buffers from user plugins (autopairs, LSP)"
```

---

## Task 5: Render `goal` on teach screen

**Files:**
- Modify: `lua/the-vimmer/ui/teach.lua`

- [ ] **Step 1: Edit `lua/the-vimmer/ui/teach.lua`**

For non-boss rooms, the teach screen already adds command + description + diff example + usage tip. We insert the `goal` line between description and the separator. For boss rooms, we add per-phase goal lines after the phase tip.

Find the non-boss block (~lines 40-52):

```lua
  else
    common.add_wrapped_prefixed(add, b.row, "  ", room.command:gsub("\n", " ↵ "), width, "VimmerCommand")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    add(b.sep)
    local inner_example_w = width - 4
    local diff_lines = hl.build_diff_line(room.before_example, room.after_example, inner_example_w)
    for _, dl in ipairs(diff_lines) do
      diff_rows[#diff_rows+1] = #lines
      add(b.row("  " .. dl), "VimmerExample")
    end
    add(b.sep)
    common.add_wrapped_prefixed(add, b.row, "  ", room.usage_tip or "", width, "VimmerTeachTip")
  end
```

Replace with:

```lua
  else
    common.add_wrapped_prefixed(add, b.row, "  ", room.command:gsub("\n", " ↵ "), width, "VimmerCommand")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    if room.goal and room.goal ~= "" then
      common.add_wrapped_prefixed(add, b.row, "  GOAL: ", room.goal:gsub("\n", " ↵ "), width, "VimmerXP")
    end
    add(b.sep)
    local inner_example_w = width - 4
    local diff_lines = hl.build_diff_line(room.before_example, room.after_example, inner_example_w)
    for _, dl in ipairs(diff_lines) do
      diff_rows[#diff_rows+1] = #lines
      add(b.row("  " .. dl), "VimmerExample")
    end
    add(b.sep)
    common.add_wrapped_prefixed(add, b.row, "  ", room.usage_tip or "", width, "VimmerTeachTip")
  end
```

Find the boss-phase block (~lines 30-39):

```lua
  if room.is_boss then
    common.add_wrapped_prefixed(add, b.row, "  ⚔ BOSS: ", room.command:gsub("\n", " ↵ "), width, "VimmerBoss")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      common.add_wrapped_prefixed(add, b.row, string.format("  PHASE %d: ", i), phase.tip or "", width, "VimmerCommand")
      common.add_wrapped_prefixed(add, b.row, "  BEFORE: ", phase.start_text:gsub("\n", " ↵ "), width, "VimmerLocked")
      common.add_wrapped_prefixed(add, b.row, "  AFTER:  ", phase.target_text:gsub("\n", " ↵ "), width, "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
```

Replace with:

```lua
  if room.is_boss then
    common.add_wrapped_prefixed(add, b.row, "  ⚔ BOSS: ", room.command:gsub("\n", " ↵ "), width, "VimmerBoss")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      common.add_wrapped_prefixed(add, b.row, string.format("  PHASE %d: ", i), phase.tip or "", width, "VimmerCommand")
      if phase.goal and phase.goal ~= "" then
        common.add_wrapped_prefixed(add, b.row, "  GOAL:   ", phase.goal:gsub("\n", " ↵ "), width, "VimmerXP")
      end
      common.add_wrapped_prefixed(add, b.row, "  BEFORE: ", phase.start_text:gsub("\n", " ↵ "), width, "VimmerLocked")
      common.add_wrapped_prefixed(add, b.row, "  AFTER:  ", phase.target_text:gsub("\n", " ↵ "), width, "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
```

- [ ] **Step 2: Manual smoke test**

Run nvim with the plugin, open any room (no `goal` set yet → teach screen looks unchanged):

```bash
nvim -c "set rtp+=$(pwd)" -c "lua require('the-vimmer').setup({})" -c "lua require('the-vimmer.ui').open_room(require('the-vimmer.rooms').get_room('beginner_hjkl'))"
```

Expected: teach screen renders exactly as before (no goal line because no room has `goal` yet). No errors in `:messages`.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui/teach.lua
git commit -m "feat(teach): render optional goal line on teach screen"
```

---

## Task 6: Render `goal` line in play HUD

**Files:**
- Modify: `lua/the-vimmer/ui/play.lua` (function `update_hud`)

In play, the HUD bottom shows `room.command`. Add the goal as a line below it (wrapped). This keeps the player oriented during play, after the teach screen is dismissed.

- [ ] **Step 1: Edit `update_hud` in `lua/the-vimmer/ui/play.lua`**

Find the existing tail of `update_hud` (~lines 140-146):

```lua
    local cmd = " " .. room.command
    local max_w = HUD_W - 1
    while #cmd > max_w do
      lines[#lines+1] = cmd:sub(1, max_w)
      cmd = " " .. cmd:sub(max_w + 1)
    end
    lines[#lines+1] = cmd
```

Replace with:

```lua
    local cmd = " " .. room.command
    local max_w = HUD_W - 1
    while #cmd > max_w do
      lines[#lines+1] = cmd:sub(1, max_w)
      cmd = " " .. cmd:sub(max_w + 1)
    end
    lines[#lines+1] = cmd

    local rooms_mod = require("the-vimmer.rooms")
    local current_phase = room.is_boss and (room.phases[game_state.boss_phase] or {}) or room
    local goal_view = rooms_mod.phase_view(current_phase).goal
    if goal_view and goal_view ~= "" then
      lines[#lines+1] = ""
      lines[#lines+1] = " GOAL:"
      hls[#hls+1] = { "VimmerXP", #lines - 1, 1, -1 }
      local g = " " .. goal_view
      while #g > max_w do
        lines[#lines+1] = g:sub(1, max_w)
        g = " " .. g:sub(max_w + 1)
      end
      lines[#lines+1] = g
    end
```

- [ ] **Step 2: Manual smoke test**

Same command as Task 5 Step 2. Expected: HUD renders unchanged (no rooms have `goal` yet); no errors in `:messages`.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui/play.lua
git commit -m "feat(play): show goal line in HUD when room provides one"
```

---

## Task 7: Reachability harness

**Files:**
- Create: `tests/reachability.lua`
- Modify: `README.md`

The harness is a standalone Lua script invoked inside headless nvim. It loops every room across all tiers, for each: spins up a scratch buffer with `start_text` + `bo` + `cursor_start`, feeds the primary `optimal_keystrokes` via `nvim_feedkeys` with `'nx'` mode, asserts the resulting buffer text equals `target_text`. Repeats for each `optimal_keystrokes_alternates` entry. Reports per-room failures on stderr and exits non-zero on any failure.

For boss rooms, the harness loops over each phase as if it were a standalone room.

The harness intentionally does NOT load the full plugin (`require("the-vimmer").setup`) — it only loads `the-vimmer.rooms` to enumerate rooms, then runs keystrokes against a plain scratch buffer. This isolates the keystroke-sequence check from UI/state code.

- [ ] **Step 1: Create `tests/reachability.lua`**

```lua
-- Standalone reachability harness. Invoke with:
--   nvim --headless --noplugin -l tests/reachability.lua
-- Exits 0 if every room's primary + alternate keystroke sequences reach target_text.
-- Exits 1 with per-failure lines on stderr otherwise.

local function script_root()
  local src = debug.getinfo(1, "S").source:match("^@(.+)/tests/reachability%.lua$")
  return src or "."
end

local root = script_root()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local rooms = require("the-vimmer.rooms")
local api = vim.api

local TIERS = { "beginner", "warrior", "ninja" }

-- Run one keystroke sequence against a freshly-prepared buffer.
-- Returns (ok, actual_text).
local function run_sequence(ctx, sequence)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "swapfile", false)

  if type(ctx.bo) == "table" then
    for k, v in pairs(ctx.bo) do vim.bo[buf][k] = v end
  end
  if ctx.filetype and ctx.filetype ~= "" then
    vim.bo[buf].filetype = ctx.filetype
  end

  local lines = vim.split(ctx.start_text, "\n", { plain = true })
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = 0, col = 0, width = 80, height = 25,
    style = "minimal",
  })

  local cs = ctx.cursor_start or { row = 1, col = 1 }
  pcall(api.nvim_win_set_cursor, win, { cs.row, cs.col - 1 })

  -- Feed keys. 'nx' = no remapping, execute now (drain typeahead before returning).
  api.nvim_feedkeys(table.concat(sequence), "nx", false)

  local actual = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local target = ctx.target_text
  -- Normalize trailing newline differences.
  local function rtrim_nl(s) return (s:gsub("\n+$", "")) end
  local ok = rtrim_nl(actual) == rtrim_nl(target)

  api.nvim_win_close(win, true)
  return ok, actual
end

local failures = {}

local function check_ctx(label, ctx)
  local seqs = rooms.acceptable_key_sequences(ctx)
  for i, seq in ipairs(seqs) do
    local kind = (i == 1) and "primary" or ("alternate#" .. (i - 1))
    local ok, actual = run_sequence(ctx, seq)
    if not ok then
      failures[#failures + 1] = {
        label = label, kind = kind, expected = ctx.target_text, actual = actual,
        sequence = table.concat(seq, ""),
      }
    end
  end
end

for _, tier in ipairs(TIERS) do
  for _, room in ipairs(rooms.load_tier(tier)) do
    if room.is_boss then
      for i, phase in ipairs(room.phases) do
        check_ctx(room.id .. "#phase" .. i, phase)
      end
    else
      check_ctx(room.id, room)
    end
  end
end

if #failures == 0 then
  io.stdout:write("reachability: all sequences pass\n")
  vim.cmd("qa!")
else
  io.stderr:write(string.format("reachability: %d failure(s)\n", #failures))
  for _, f in ipairs(failures) do
    io.stderr:write(string.format("\n[%s %s] sequence=%q\n", f.label, f.kind, f.sequence))
    io.stderr:write("  expected:\n")
    for line in (f.expected or ""):gmatch("[^\n]*") do
      io.stderr:write("    | " .. line .. "\n")
    end
    io.stderr:write("  actual:\n")
    for line in (f.actual or ""):gmatch("[^\n]*") do
      io.stderr:write("    | " .. line .. "\n")
    end
  end
  vim.cmd("cq")
end
```

- [ ] **Step 2: Run the harness against existing rooms**

```bash
nvim --headless --noplugin -l tests/reachability.lua
```

Expected: `reachability: all sequences pass` on stdout, exit code 0. Verify with `echo $?` → `0`.

If any existing room fails, do NOT mass-edit rooms in this PR — surface each failure to the user with the harness output and stop. Existing rooms passing reachability is a precondition for merging PR 1.

- [ ] **Step 3: Add a Tests section to `README.md`**

Find the end of the README (after the install section) and add this section before the final newline:

```markdown
## Tests

Unit tests (validator, game state, progress) run via [busted](https://lunarmodules.github.io/busted/):

```bash
busted --helper=tests/spec/helpers.lua tests/spec
```

The reachability harness verifies every room's keystroke sequences actually transform `start_text` into `target_text`. It runs inside headless nvim:

```bash
nvim --headless --noplugin -l tests/reachability.lua
```

Exit code 0 = all sequences pass. Non-zero with per-room diagnostics on stderr if any sequence fails to reach the target.
```

(Use the exact markdown above. If your README does not end with a `## Tests` section already, append; if it does, replace.)

- [ ] **Step 4: Commit**

```bash
git add tests/reachability.lua README.md
git commit -m "test(rooms): add reachability harness for keystroke sequences"
```

---

## Task 8: Final verification pass

- [ ] **Step 1: Run all unit tests**

```bash
busted --helper=tests/spec/helpers.lua tests/spec
```

Expected: every spec passes. Note any pre-existing failures (game_spec etc.) and confirm they are unrelated to this PR's changes.

- [ ] **Step 2: Run the reachability harness**

```bash
nvim --headless --noplugin -l tests/reachability.lua
```

Expected: `reachability: all sequences pass`, exit code 0.

- [ ] **Step 3: Manual smoke test — open one room of each tier**

```bash
nvim -c "set rtp+=$(pwd)" -c "lua require('the-vimmer').setup({})" -c "lua require('the-vimmer.ui').open_room(require('the-vimmer.rooms').get_room('beginner_hjkl'))"
```

Quit (`:qa!`), repeat with `warrior_ciw` and `ninja_sort`. Each should open, render the teach screen (unchanged appearance — no goal line because no room has `goal` yet), accept `<CR>`, transition to play, accept keystrokes, and complete normally.

- [ ] **Step 4: Push branch and open PR**

```bash
git log --oneline main..HEAD
git push -u origin <branch-name>
gh pr create --title "feat(rooms): engine support for real-world scenario rooms" --body "$(cat <<'EOF'
## Summary
- Add optional `filetype`, `cursor_start`, `goal` schema fields with validator coverage
- Plumb new fields through play UI (cursor placement, filetype, HUD goal line) and teach screen
- Isolate room buffers from user plugins (autopairs, LSP, completion)
- Add reachability harness that verifies every room's keystroke sequence reaches `target_text`

## Test plan
- [ ] `busted --helper=tests/spec/helpers.lua tests/spec` — all pass
- [ ] `nvim --headless --noplugin -l tests/reachability.lua` — all sequences pass
- [ ] Open one beginner/warrior/ninja room manually — teach + play render unchanged
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Schema additions (filetype, cursor_start, goal) → Task 1 (validator) + Task 2 (phase_view helper) ✓
- UI rendering of goal on play screen → Task 6 (HUD) ✓
- UI rendering of goal on teach screen → Task 5 (teach) ✓ (spec said "Play screen renders goal" but goal usefulness extends to teach screen — adding both)
- Filetype applied in scratch buffer → Task 3 ✓
- Cursor moved to cursor_start → Task 3 ✓
- Buffer hygiene (buftype=nofile, LSP detach, disable plugin flags) → Task 4 ✓
- Reachability harness → Task 7 ✓
- README documentation of test commands → Task 7 ✓
- Backward-compatible (all new fields optional) → enforced by validator tests in Task 1 ("accepts room without X") ✓

**Placeholder scan:** No "TBD" / "TODO" / "fill in details". All steps include exact code or commands.

**Type consistency:**
- `M.phase_view` defined in Task 2 returns `filetype` (string, defaults `""`), `cursor_start` (table `{row, col}`, defaults `{1, 1}`), `goal` (string or nil). Consumed in Tasks 3 and 6 with these exact shapes ✓
- `apply_buffer_hygiene(buf)` defined in Task 4 takes a buffer handle; called consistently in Task 4 ✓
- Validator helpers (`validate_filetype`, `validate_cursor_start`, `validate_goal`, `validate_optional_additions`) are local to `rooms.lua`; not used cross-file ✓

**Scope check:** Plan covers only PR 1 (engine support). Per-tier room rewrites (PRs 2-4) and tuning (PR 5) are separate plans, called out in the spec's "Plan decomposition" section.

No fixups required.
