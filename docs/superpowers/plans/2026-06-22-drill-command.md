# `:VimmerDrill` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `:VimmerDrill` command that plays the player's 3 weakest regular rooms back-to-back (worst keystroke-waste first), then returns to the map.

**Architecture:** Generalise the existing single-room finder into `weakest_regular_room_ids(prog, rooms_by_tier, n)` (the old singular function becomes a wrapper). Add an optional `queue`/`queue_idx` pair to `flow_opts` that the `on_continue` callback honours before the existing next-in-tier logic. Register `:VimmerDrill` to build the queue and start it.

**Tech Stack:** Lua 5.1+, Neovim Lua API, busted test framework.

## Global Constraints

- `weakest_regular_room_ids` must run headlessly — plain Lua over `prog` + a `rooms_by_tier` map; the `tests/spec/helpers.lua` stub only.
- Fixed count of 3 weakest rooms; selection metric is keystroke-waste ratio (`keystrokes_over_budget / keystrokes_used`), highest first; deterministic id tie-break.
- Only regular rooms (`not r.is_boss`) in unlocked tiers with `attempts > 0` and `keystrokes_used > 0` are eligible.
- No new save fields, no migration, no gameplay rebalancing.
- Run tests with: `~/.luarocks/bin/busted tests/spec/` (single file: append the path).
- Commit messages use Conventional Commits.

---

### Task 1: `weakest_regular_room_ids` + wrapper

**Files:**
- Modify: `lua/the-vimmer/progress.lua` (`weakest_regular_room_id` ~86-109)
- Test: `tests/spec/progress_spec.lua`

**Interfaces:**
- Consumes: `rooms.all_tiers()`, `M.is_tier_unlocked` (both existing).
- Produces: `progress.weakest_regular_room_ids(prog, rooms_by_tier, n)` → array of up to `n` room-id strings, ordered by waste ratio descending, id-ascending tie-break. `progress.weakest_regular_room_id(prog, rooms_by_tier)` → first id of the `n=1` result (or nil).

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/progress_spec.lua`. The helper builds a `prog` with room
stats and a `rooms_by_tier` map of plain room tables (only `id`/`is_boss`
matter to the function):

```lua
describe("progress.weakest_regular_room_ids", function()
  -- All tiers unlocked: beginner is always unlocked; mark the warrior/ninja
  -- bosses cleared so warrior/ninja rooms are eligible too if used.
  local function make()
    local prog = progress.reset_data()
    prog.room_stats = {
      a = { attempts = 1, keystrokes_used = 10, keystrokes_over_budget = 1 }, -- waste 0.1
      b = { attempts = 1, keystrokes_used = 10, keystrokes_over_budget = 5 }, -- waste 0.5
      c = { attempts = 1, keystrokes_used = 10, keystrokes_over_budget = 3 }, -- waste 0.3
      z = { attempts = 0, keystrokes_used = 0,  keystrokes_over_budget = 0 }, -- ineligible
    }
    local rooms_by_tier = {
      beginner = {
        { id = "a" }, { id = "b" }, { id = "c" }, { id = "z" },
      },
      warrior = {}, ninja = {},
    }
    return prog, rooms_by_tier
  end

  it("orders by waste ratio descending", function()
    local prog, rby = make()
    assert.same({ "b", "c", "a" }, progress.weakest_regular_room_ids(prog, rby, 3))
  end)

  it("limits to n", function()
    local prog, rby = make()
    assert.same({ "b", "c" }, progress.weakest_regular_room_ids(prog, rby, 2))
  end)

  it("excludes rooms with no attempts or no keystrokes", function()
    local prog, rby = make()
    local ids = progress.weakest_regular_room_ids(prog, rby, 10)
    assert.same({ "b", "c", "a" }, ids)  -- "z" never appears
  end)

  it("excludes boss rooms", function()
    local prog, rby = make()
    rby.beginner[#rby.beginner + 1] =
      { id = "beginner_boss", is_boss = true }
    prog.room_stats.beginner_boss =
      { attempts = 1, keystrokes_used = 10, keystrokes_over_budget = 9 }
    local ids = progress.weakest_regular_room_ids(prog, rby, 10)
    assert.same({ "b", "c", "a" }, ids)
  end)

  it("excludes locked-tier rooms", function()
    local prog, rby = make()
    -- warrior is locked (no beginner_boss cleared)
    rby.warrior = { { id = "w1" } }
    prog.room_stats.w1 = { attempts = 1, keystrokes_used = 10, keystrokes_over_budget = 9 }
    local ids = progress.weakest_regular_room_ids(prog, rby, 10)
    assert.same({ "b", "c", "a" }, ids)  -- w1 excluded
  end)

  it("breaks ties by id ascending", function()
    local prog, rby = make()
    prog.room_stats.c.keystrokes_over_budget = 5  -- c waste now 0.5, tie with b
    assert.same({ "b", "c", "a" }, progress.weakest_regular_room_ids(prog, rby, 3))
  end)

  it("returns empty when nothing is eligible", function()
    local prog = progress.reset_data()
    local rby = { beginner = { { id = "a" } }, warrior = {}, ninja = {} }
    assert.same({}, progress.weakest_regular_room_ids(prog, rby, 3))
  end)

  it("singular wrapper returns the first id", function()
    local prog, rby = make()
    assert.equals("b", progress.weakest_regular_room_id(prog, rby))
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`
Expected: FAIL — `attempt to call field 'weakest_regular_room_ids' (a nil value)`.

- [ ] **Step 3: Write minimal implementation**

In `lua/the-vimmer/progress.lua`, replace the entire existing
`weakest_regular_room_id` function with:

```lua
-- Return up to `n` regular room IDs across unlocked tiers, ordered by
-- keystroke-waste ratio (keystrokes_over_budget / keystrokes_used) descending.
-- Only rooms with attempts > 0 and keystrokes_used > 0 are eligible.
-- Ties break by id ascending for determinism.
function M.weakest_regular_room_ids(prog, rooms_by_tier, n)
  local tiers = require("the-vimmer.rooms").all_tiers()
  local scored = {}
  for _, tier in ipairs(tiers) do
    local list = rooms_by_tier[tier] or {}
    if M.is_tier_unlocked(tier, prog.cleared) then
      for _, r in ipairs(list) do
        if not r.is_boss then
          local st = prog.room_stats and prog.room_stats[r.id]
          if st and st.attempts > 0 and (st.keystrokes_used or 0) > 0 then
            local waste = (st.keystrokes_over_budget or 0) / st.keystrokes_used
            scored[#scored + 1] = { id = r.id, waste = waste }
          end
        end
      end
    end
  end
  table.sort(scored, function(a, b)
    if a.waste == b.waste then return a.id < b.id end
    return a.waste > b.waste
  end)
  local ids = {}
  local limit = math.min(n or #scored, #scored)
  for i = 1, limit do
    ids[i] = scored[i].id
  end
  return ids
end

-- Find the single regular room with the worst keystroke-waste ratio.
function M.weakest_regular_room_id(prog, rooms_by_tier)
  return M.weakest_regular_room_ids(prog, rooms_by_tier, 1)[1]
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`
Expected: PASS (new specs + the existing `weakest_regular_room_id` spec, which
now exercises the wrapper).

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "feat(progress): add weakest_regular_room_ids (top-N finder)"
```

---

### Task 2: Queue branch + `:VimmerDrill` command

**Files:**
- Modify: `lua/the-vimmer/commands.lua` (`on_continue` callback ~104-121; `M.register` command block ~187-231)
- Modify: `README.md` (commands table ~ the `| :VimmerProgress | ... |` area)
- Test: none new (integration-level; verified by full suite + headless smoke + manual play).

**Interfaces:**
- Consumes: `progress.weakest_regular_room_ids` (Task 1), `rooms.get_room` (existing), `M.start_flow` (existing).
- Produces: `flow_opts.queue` (array of room tables) and `flow_opts.queue_idx` (1-based int) honoured by the `on_continue` callback; `:VimmerDrill` user command.

- [ ] **Step 1: Add the queue branch to on_continue**

In `lua/the-vimmer/commands.lua`, inside the `open_results` `on_continue`
callback, the `go_map == false` path currently reads:

```lua
      function(go_map)
        if go_map then
          show_map()
          return
        end
        local tier_rooms = d.rooms.load_tier(room.tier)
```

Insert the queue branch between the `go_map` guard and the `tier_rooms` lookup:

```lua
      function(go_map)
        if go_map then
          show_map()
          return
        end
        if flow_opts.queue and flow_opts.queue_idx then
          local nxt = flow_opts.queue[flow_opts.queue_idx + 1]
          if nxt then
            M.start_flow(nxt, { queue = flow_opts.queue, queue_idx = flow_opts.queue_idx + 1 })
          else
            show_map()
          end
          return
        end
        local tier_rooms = d.rooms.load_tier(room.tier)
```

(`flow_opts` is the function parameter of `start_flow`, in scope inside this
closure. No change is needed in `on_death`: it already calls
`M.start_flow(room, flow_opts)`, preserving `queue`/`queue_idx` across retries.)

- [ ] **Step 2: Register the :VimmerDrill command**

In `lua/the-vimmer/commands.lua`, inside `M.register`, after the `VimmerDaily`
command block (before `VimmerPick`), add:

```lua
  vim.api.nvim_create_user_command("VimmerDrill", function()
    local d = deps()
    local prog = d.progress.load()
    local rooms_by_tier = build_rooms_by_tier(d)
    local ids = d.progress.weakest_regular_room_ids(prog, rooms_by_tier, 3)
    local queue = {}
    for _, id in ipairs(ids) do
      local r = d.rooms.get_room(id)
      if r then queue[#queue + 1] = r end
    end
    if #queue == 0 then
      vim.notify("the-vimmer: no drillable rooms yet — play a few first",
        vim.log.levels.INFO)
      return
    end
    M.start_flow(queue[1], { queue = queue, queue_idx = 1 })
  end, { desc = "Drill your 3 weakest the-vimmer rooms" })
```

- [ ] **Step 3: Document the command in README**

In `README.md`, in the Commands table, add a row after the `:VimmerProgress`
row:

```markdown
| `:VimmerDrill` | Play your 3 weakest rooms back-to-back (by keystroke waste) |
```

- [ ] **Step 4: Run the full suite (no regressions)**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — all specs green (prior + Task 1 additions).

- [ ] **Step 5: Headless smoke check (command registered + empty-queue path)**

```bash
nvim --headless --clean -u NORC -c "set rtp+=$(pwd)" \
  -c "lua require('the-vimmer').setup({})" \
  -c "lua local ok = pcall(vim.cmd, 'VimmerDrill'); print('drill ok', ok)" \
  -c "qa!" 2>&1 | tail -1
```

Expected: prints `drill ok  true`. With a fresh (empty) progress file no rooms
are eligible, so the command takes the notify path and returns without error —
proving the command is registered and the empty-queue guard works.

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/commands.lua README.md
git commit -m "feat(commands): add :VimmerDrill weakest-rooms session"
```

---

## Self-Review

**Spec coverage:**
- `weakest_regular_room_ids` + wrapper (spec §1) → Task 1. ✓
- Queue fields + `on_continue` branch + death-retry behaviour (spec §2) → Task 2 Step 1. ✓
- `:VimmerDrill` registration + empty-queue notify (spec §2) → Task 2 Step 2. ✓
- README documentation (spec §Files touched) → Task 2 Step 3. ✓
- Edge cases: no eligible rooms (notify), <3 rooms (math.min slice), unresolved id (`get_room` guard), locked/boss exclusion (Task 1 filter), death mid-drill (flow_opts carry) → covered in Tasks 1-2 and their tests. ✓
- Tests (spec §Testing): progress_spec for the finder (Task 1); smoke for the command (Task 2 Step 5). ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output.

**Type consistency:** `weakest_regular_room_ids(prog, rooms_by_tier, n)→string[]`, `weakest_regular_room_id(prog, rooms_by_tier)→string|nil`, `flow_opts.queue` (room-table array), `flow_opts.queue_idx` (int) — names identical across Tasks 1-2. The queue holds room *tables* (from `get_room`), and `start_flow`'s first arg is a room table, matching `M.start_flow(nxt, ...)` in the branch. ✓
