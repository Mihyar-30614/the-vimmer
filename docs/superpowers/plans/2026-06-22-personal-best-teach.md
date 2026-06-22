# Personal Best on Teach Screen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track best keystroke count per room alongside the existing best time, and show both on the teach screen as `PB: 4 keys · 0:08` so the player has a target before each run.

**Architecture:** Additive save field `room_best_keys` with a pure `record_best_keys` recorder in `progress.lua`. `commands.lua` records the best in `on_win` and builds a `pb` bag passed through `flow_opts` to the teach screen. A pure `pb_line` formatter in `common.lua` renders the row in `teach.lua`. No gameplay mechanics change.

**Tech Stack:** Lua 5.1+, Neovim Lua API, busted test framework.

## Global Constraints

- Pure helpers (`record_best_keys`, `pb_line`) must run headlessly — plain Lua + the `tests/spec/helpers.lua` stub only.
- No gameplay rebalancing; no new commands; additive save field only (no migration).
- Lower keystroke count is better; record the minimum.
- Boss rooms: suppress the keys PB (per-phase counts are misleading); time PB still allowed.
- Run tests with: `~/.luarocks/bin/busted tests/spec/` (single file: append the path).
- Commit messages use Conventional Commits.

---

### Task 1: `record_best_keys` + `room_best_keys` default

**Files:**
- Modify: `lua/the-vimmer/progress.lua` (`default_state` ~16-29; add recorder near `record_clear_run` ~61-69)
- Test: `tests/spec/progress_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `progress.record_best_keys(prog, room_id, keys)` → boolean (true when a new best is set, including first run); stores the minimum in `prog.room_best_keys[room_id]`. `default_state()` includes `room_best_keys = {}`.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/progress_spec.lua`:

```lua
describe("progress.record_best_keys", function()
  local prog
  before_each(function() prog = progress.reset_data() end)

  it("records the first run and returns true", function()
    assert.is_true(progress.record_best_keys(prog, "r1", 10))
    assert.equals(10, prog.room_best_keys.r1)
  end)

  it("overwrites with a lower count and returns true", function()
    progress.record_best_keys(prog, "r1", 10)
    assert.is_true(progress.record_best_keys(prog, "r1", 6))
    assert.equals(6, prog.room_best_keys.r1)
  end)

  it("keeps the old best for an equal or higher count and returns false", function()
    progress.record_best_keys(prog, "r1", 6)
    assert.is_false(progress.record_best_keys(prog, "r1", 6))
    assert.is_false(progress.record_best_keys(prog, "r1", 9))
    assert.equals(6, prog.room_best_keys.r1)
  end)

  it("ignores non-positive counts and returns false", function()
    assert.is_false(progress.record_best_keys(prog, "r1", 0))
    assert.is_nil(prog.room_best_keys.r1)
  end)

  it("creates room_best_keys when missing", function()
    prog.room_best_keys = nil
    assert.is_true(progress.record_best_keys(prog, "r1", 4))
    assert.equals(4, prog.room_best_keys.r1)
  end)

  it("default_state includes an empty room_best_keys", function()
    assert.same({}, progress.reset_data().room_best_keys)
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`
Expected: FAIL — `attempt to call field 'record_best_keys' (a nil value)` and the `default_state` assertion fails (`room_best_keys` is nil).

- [ ] **Step 3: Write minimal implementation**

In `lua/the-vimmer/progress.lua`, add to the table returned by `default_state()`:

```lua
    room_best = {},
    room_best_keys = {},
```

(If `room_best` is not already in `default_state`, add both lines; if it is, add only the `room_best_keys` line next to it.)

Add the recorder after `record_clear_run`:

```lua
-- Record a best (minimum) keystroke count for a room. Returns true when this
-- run set a new best (including the first recorded run). Lower is better.
function M.record_best_keys(prog, room_id, keys)
  if not keys or keys <= 0 then return false end
  prog.room_best_keys = prog.room_best_keys or {}
  local prev = prog.room_best_keys[room_id]
  if prev == nil or keys < prev then
    prog.room_best_keys[room_id] = keys
    return true
  end
  return false
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "feat(progress): track best keystroke count per room"
```

---

### Task 2: `pb_line` formatter

**Files:**
- Modify: `lua/the-vimmer/ui/common.lua` (add near `fmt_run_seconds` ~239)
- Test: `tests/spec/ui_common_spec.lua`

**Interfaces:**
- Consumes: `common.fmt_run_seconds(seconds)` (existing).
- Produces: `common.pb_line(pb)` where `pb` is `{ keys = <int|nil>, seconds = <number|nil> }` → a `"  PB: N keys · M:SS"` string, omitting a missing side; returns `nil` when neither side is present or `pb` is not a table.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/ui_common_spec.lua`:

```lua
describe("ui.common.pb_line", function()
  it("formats both keys and time", function()
    assert.equals("  PB: 4 keys · 0:08", c.pb_line({ keys = 4, seconds = 8 }))
  end)

  it("shows keys only when seconds is missing", function()
    assert.equals("  PB: 4 keys", c.pb_line({ keys = 4 }))
  end)

  it("shows time only when keys is missing", function()
    assert.equals("  PB: 0:08", c.pb_line({ seconds = 8 }))
  end)

  it("returns nil when neither side is present", function()
    assert.is_nil(c.pb_line({}))
    assert.is_nil(c.pb_line({ keys = 0, seconds = 0 }))
  end)

  it("returns nil for a non-table argument", function()
    assert.is_nil(c.pb_line(nil))
    assert.is_nil(c.pb_line("x"))
  end)
end)
```

(`fmt_run_seconds(8)` returns `"0:08"` — confirm by reading `common.lua` if the
expected string differs; adjust the literals to match its actual output.)

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: FAIL — `attempt to call field 'pb_line' (a nil value)`.

- [ ] **Step 3: Write minimal implementation**

Add to `lua/the-vimmer/ui/common.lua` (after `fmt_run_seconds`):

```lua
-- Format a "  PB: N keys · M:SS" line from a pb table { keys, seconds }.
-- Omits a missing side; returns nil when neither is present.
function M.pb_line(pb)
  if type(pb) ~= "table" then return nil end
  local parts = {}
  if pb.keys and pb.keys > 0 then
    parts[#parts + 1] = string.format("%d keys", pb.keys)
  end
  if pb.seconds and pb.seconds > 0 then
    parts[#parts + 1] = M.fmt_run_seconds(pb.seconds)
  end
  if #parts == 0 then return nil end
  return "  PB: " .. table.concat(parts, " · ")
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: PASS. If the time literal mismatched, fix the test to match
`fmt_run_seconds`'s real output, then re-run.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui/common.lua tests/spec/ui_common_spec.lua
git commit -m "feat(common): add pb_line formatter"
```

---

### Task 3: Record best keys + build pb bag in commands.lua, render in teach.lua

**Files:**
- Modify: `lua/the-vimmer/commands.lua` (`on_win` near the `room_best` block ~63-77 and `save` ~83; `start_flow` before `open_teach` ~172-173)
- Modify: `lua/the-vimmer/ui/teach.lua` (before the footer `add(b.sep)` ~85)
- Test: none new (pure logic covered in Tasks 1-2; wiring verified by full suite + headless smoke).

**Interfaces:**
- Consumes: `progress.record_best_keys` (Task 1), `common.pb_line` (Task 2), `g.keystrokes_used` (existing game field), `prog.room_best_keys` / `prog.room_best` (Task 1 + existing).
- Produces: `flow_opts.pb = { keys, seconds }` consumed by `teach.lua`.

- [ ] **Step 1: Record best keys in on_win**

In `lua/the-vimmer/commands.lua`, inside `on_win`, after the existing time
`room_best` block (the `if run_s and run_s > 0 then ... end` ending ~line 77)
and before `d.progress.record_clear_run(prog, room.id, g)`, add:

```lua
    d.progress.record_best_keys(prog, room.id, g.keystrokes_used)
```

This runs before the existing `d.progress.save(prog)` (~line 83), so the new
best persists.

- [ ] **Step 2: Build the pb bag in start_flow**

In `lua/the-vimmer/commands.lua`, in `start_flow`, immediately before
`d.ui.open_teach(room, flow_opts, function()` (~line 173), add:

```lua
  flow_opts.pb = {
    keys    = (not room.is_boss) and (prog.room_best_keys or {})[room.id] or nil,
    seconds = (prog.room_best or {})[room.id],
  }
```

`prog` is the save table already loaded at the top of `start_flow`.

- [ ] **Step 3: Render the PB row in teach.lua**

In `lua/the-vimmer/ui/teach.lua`, immediately before the footer block:

```lua
  add(b.sep)
  add(b.row("  <Enter> begin   <r> replay keys   <q> close"), "VimmerTeachFoot")
  add(b.bot)
```

insert:

```lua
  local pb_line = common.pb_line(flow_opts.pb)
  if pb_line then
    add(b.sep)
    add(b.row(pb_line), "VimmerXP")
  end
```

`flow_opts` is already resolved at the top of `open_teach` (it handles both the
table form and the legacy function-as-second-arg form), and `common` is already
required at the top of the file.

- [ ] **Step 4: Run the full suite (no regressions)**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — all specs green (prior + Tasks 1-2 additions).

- [ ] **Step 5: Headless smoke check**

```bash
nvim --headless --clean -u NORC -c "set rtp+=$(pwd)" \
  -c "lua local ok,err=pcall(function() require('the-vimmer.ui').open_teach(require('the-vimmer.rooms').get_room('beginner_hjkl'), { pb = { keys = 4, seconds = 8 } }, function() end) end); print('teach ok', ok, err)" \
  -c "qa!" 2>&1
```

Expected: prints `teach ok  true  nil` (the teach float renders with a PB row,
no Lua error).

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/commands.lua lua/the-vimmer/ui/teach.lua
git commit -m "feat(teach): show personal best keys and time before a run"
```

---

## Self-Review

**Spec coverage:**
- Storage `room_best_keys` + `record_best_keys` (spec §1) → Task 1. ✓
- Plumbing: record in on_win, build `pb` in start_flow, boss keys suppression (spec §2) → Task 3 Steps 1-2. ✓
- Display `pb_line` + teach row (spec §3) → Task 2 + Task 3 Step 3. ✓
- Edge cases: no prior run / one side / first clear / boss / zero keys (spec) → covered by `pb_line` nil-handling (Task 2 tests) and `record_best_keys` guards (Task 1 tests). ✓
- Tests (spec §Testing): progress_spec (Task 1), ui_common_spec (Task 2), smoke (Task 3). ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output. The one conditional ("if `room_best` not already in default_state") is a concrete branch with both cases specified, not a placeholder.

**Type consistency:** `record_best_keys(prog, room_id, keys)→bool`, `pb_line(pb)→string|nil`, `flow_opts.pb = { keys, seconds }` — names identical across Tasks 1-3. The `pb` bag shape produced in Task 3 Step 2 matches what `pb_line` consumes in Task 2. ✓
