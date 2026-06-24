# Fold Map Groups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player fold/unfold tier groups on the world map with `za`, hiding a tier's rooms behind a single header line.

**Architecture:** Split `lua/the-vimmer/ui/map.lua`'s one-shot rendering into a pure `build_view(folds, ...)` function (returns `lines`, `hls`, and a uniform `nav` list) plus a `render()` closure that rewrites the buffer and resizes the float on every fold toggle. Fold state is a session-local table; nothing is persisted.

**Tech Stack:** Lua, Neovim API, busted test framework.

## Global Constraints

- Touch only `lua/the-vimmer/ui/map.lua` (plus its new test file). No changes to game logic, progress data, or other UI screens.
- Fold state is session-only — no writes to progress data.
- `build_view` must be pure (no `vim.api` calls) so it is unit-testable under the busted harness, which stubs `vim` but not `vim.api`.
- Existing busted suite must stay green: `~/.luarocks/bin/busted tests/spec/`.

---

## File Structure

- **Modify** `lua/the-vimmer/ui/map.lua`:
  - Extract a module-level pure `build_view(folds, progress_data, rooms_by_tier, width)` → `lines, hls, nav`.
  - Add module-level helper `tier_fully_cleared(tier_rooms, boss_room, cleared)`.
  - Expose `M._build_view = build_view` for testing.
  - Rewrite `M.open_map` to own fold state, a `render()` closure, window resize, and the new keymaps.
- **Create** `tests/spec/map_view_spec.lua`: unit tests for `build_view` nav/line output under fold state.

---

### Task 1: Pure `build_view` with fold-aware nav

**Files:**
- Modify: `lua/the-vimmer/ui/map.lua` (add `tier_fully_cleared`, `build_view`, `M._build_view`; do NOT yet touch `open_map`)
- Test: `tests/spec/map_view_spec.lua`

**Interfaces:**
- Consumes: `common`, `icons`, `progress`, `require("the-vimmer.rooms")` (already required in file); module-level helpers `split_tier_rooms`, `count_cleared`, `global_room_counts`, `boss_hint_game`, and the `TIERS`/`TIER_*` tables (already defined).
- Produces:
  - `build_view(folds, progress_data, rooms_by_tier, width) -> lines (string[]), hls (table[]), nav (table[])`.
    - `folds`: `{ [tier]=boolean }`, entry present only for unlocked tiers.
    - `nav` items, each one of:
      - `{ kind="quick", line=int, room, icon, title, title_max, hl="VimmerBadge" }`
      - `{ kind="tier", tier=string, line=int }`
      - `{ kind="room", tier=string, line=int, room, icon, title, title_max, hl=string|nil }`
  - `tier_fully_cleared(tier_rooms, boss_room, cleared) -> boolean`
  - `M._build_view = build_view`

- [ ] **Step 1: Write the failing test**

Create `tests/spec/map_view_spec.lua`:

```lua
dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local map = require("the-vimmer.ui.map")

-- Minimal mock: beginner tier (always unlocked) with 2 regular rooms + boss.
local function fixture()
  return {
    beginner = {
      { id = "beginner_a", title = "Room A" },
      { id = "beginner_b", title = "Room B" },
      { id = "beginner_boss", title = "Beginner Boss", is_boss = true },
    },
  }
end

local function progress(cleared)
  return { total_xp = 0, streak = 0, cleared = cleared or {} }
end

local function nav_kinds(nav)
  local out = {}
  for _, item in ipairs(nav) do out[#out + 1] = item.kind end
  return out
end

describe("map.build_view fold behavior", function()
  it("expanded tier emits a tier item followed by its room items", function()
    local _, _, nav = map._build_view({ beginner = false }, progress(), fixture(), 60)
    -- boss is locked (0% cleared) so it is rendered but NOT in nav.
    assert.same({ "tier", "room", "room" }, nav_kinds(nav))
    assert.equal("beginner", nav[1].tier)
    assert.equal("beginner_a", nav[2].room.id)
  end)

  it("folded tier emits only its tier item", function()
    local _, _, nav = map._build_view({ beginner = true }, progress(), fixture(), 60)
    assert.same({ "tier" }, nav_kinds(nav))
  end)

  it("cleared regular rooms are still navigable", function()
    local prog = progress({ beginner_a = true })
    local _, _, nav = map._build_view({ beginner = false }, prog, fixture(), 60)
    -- both rooms present regardless of cleared state
    assert.same({ "tier", "room", "room" }, nav_kinds(nav))
  end)

  it("unlocked boss is navigable", function()
    -- both regular rooms cleared -> boss unlocked (>=80%)
    local prog = progress({ beginner_a = true, beginner_b = true })
    local _, _, nav = map._build_view({ beginner = false }, prog, fixture(), 60)
    assert.same({ "tier", "room", "room", "room" }, nav_kinds(nav))
    assert.equal("beginner_boss", nav[4].room.id)
  end)

  it("folded header shows the closed marker, expanded shows open", function()
    local folded_lines = select(1, map._build_view({ beginner = true }, progress(), fixture(), 60))
    local open_lines = select(1, map._build_view({ beginner = false }, progress(), fixture(), 60))
    local function has(lines, glyph)
      for _, l in ipairs(lines) do if l:find(glyph, 1, true) then return true end end
      return false
    end
    assert.is_true(has(folded_lines, "▸"))
    assert.is_true(has(open_lines, "▾"))
  end)
end)

describe("map.tier_fully_cleared", function()
  it("false until every regular room and the boss are cleared", function()
    local rooms = { { id = "beginner_a" }, { id = "beginner_b" } }
    local boss = { id = "beginner_boss", is_boss = true }
    assert.is_false(map._tier_fully_cleared(rooms, boss, { beginner_a = true }))
    assert.is_false(map._tier_fully_cleared(rooms, boss,
      { beginner_a = true, beginner_b = true }))
    assert.is_true(map._tier_fully_cleared(rooms, boss,
      { beginner_a = true, beginner_b = true, beginner_boss = true }))
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/map_view_spec.lua`
Expected: FAIL — `attempt to call field '_build_view' (a nil value)` (function not exposed yet).

- [ ] **Step 3: Add the helpers and pure builder**

In `lua/the-vimmer/ui/map.lua`, after the existing `boss_hint_game` function (around line 61) and before `function M.open_map`, add:

```lua
local FOLD_OPEN, FOLD_CLOSED = "▾", "▸"

local function tier_fully_cleared(tier_rooms, boss_room, cleared)
  if count_cleared(tier_rooms, cleared) < #tier_rooms then return false end
  if boss_room and not cleared[boss_room.id] then return false end
  return true
end

-- Pure: builds the full screen from fold state + progress. No buffer/window
-- access so it can be unit-tested under the busted harness.
local function build_view(folds, progress_data, rooms_by_tier, width)
  local cleared = progress_data.cleared
  local b = common.make_border(width)
  local room_title_max = math.max(22, width - 18)
  local boss_title_max = math.max(18, width - 22)
  local lines, hls, nav = {}, {}, {}

  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end

  local cleared_total, room_total = global_room_counts(rooms_by_tier, cleared)

  add(b.top)
  add(common.spread_row(icons.get("hud") .. "  WORLD MAP  " .. icons.get("hud"),
    string.format("LV %02d", common.game_level(progress_data.total_xp)), width),
    "VimmerPanel")
  add(b.row(common.game_hud_row(
    width, progress_data.total_xp, progress_data.streak, cleared_total, room_total)),
    "VimmerXP")
  add(b.sep)

  do
    local rooms_mod = require("the-vimmer.rooms")
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    local weak_room = weak_id and rooms_mod.get_room(weak_id)
    if weak_room then
      add(b.row(common.game_section("QUICK PLAY", width)), "VimmerSection")
      add(b.row(common.game_menu_row(false, icons.get("star"), weak_room.title, room_title_max)),
        "VimmerBadge")
      nav[#nav + 1] = {
        kind = "quick", line = #lines, room = weak_room,
        icon = icons.get("star"), title = weak_room.title,
        title_max = room_title_max, hl = "VimmerBadge",
      }
      add(b.sep)
    end
  end

  for _, tier in ipairs(TIERS) do
    local tier_rooms, boss_room = split_tier_rooms(rooms_by_tier[tier])
    local unlocked = progress.is_tier_unlocked(tier, cleared)
    local roman = TIER_ROMAN[tier]
    local label = TIER_LABELS[tier]

    if not unlocked then
      add(b.row(common.game_section(
        icons.get("lock") .. " " .. roman .. " · " .. label, width)), "VimmerLocked")
      add(b.row(string.format("      %s", TIER_PREREQ[tier] or "locked")),
        "VimmerTeachFoot")
    else
      local cleared_ct = count_cleared(tier_rooms, cleared)
      local total_ct = #tier_rooms
      local boss_cleared = boss_room and cleared[boss_room.id]
      local boss_unlocked = boss_room and progress.is_boss_unlocked(
        tier, cleared, total_ct)
      local hint = boss_hint_game(
        boss_room, boss_cleared, boss_unlocked, cleared_ct, total_ct)
      local folded = folds[tier]
      local marker = folded and FOLD_CLOSED or FOLD_OPEN

      add(b.row(common.spread_row(
        string.format("%s %s · %s", marker, roman, label),
        common.tier_room_bar(cleared_ct, total_ct, 8) .. "  " .. hint, width)),
        TIER_COLORS[tier])
      nav[#nav + 1] = { kind = "tier", tier = tier, line = #lines }

      if not folded then
        for _, room in ipairs(tier_rooms) do
          local icon = cleared[room.id] and icons.get("check") or icons.get("ready")
          local hl = cleared[room.id] and "VimmerCleared" or nil
          add(b.row(common.game_menu_row(false, icon, room.title, room_title_max)), hl)
          nav[#nav + 1] = {
            kind = "room", tier = tier, line = #lines, room = room,
            icon = icon, title = room.title, title_max = room_title_max, hl = hl,
          }
        end

        if boss_room then
          local title = "BOSS · " .. boss_room.title
          if boss_cleared then
            add(b.row(common.game_menu_row(false, icons.get("check"), title, boss_title_max)),
              "VimmerCleared")
            nav[#nav + 1] = { kind = "room", tier = tier, line = #lines, room = boss_room,
              icon = icons.get("check"), title = title, title_max = boss_title_max,
              hl = "VimmerCleared" }
          elseif boss_unlocked then
            add(b.row(common.game_menu_row(false, icons.get("boss"), title, boss_title_max)),
              "VimmerBoss")
            nav[#nav + 1] = { kind = "room", tier = tier, line = #lines, room = boss_room,
              icon = icons.get("boss"), title = title, title_max = boss_title_max,
              hl = "VimmerBoss" }
          else
            add(b.row(common.game_menu_row(false, icons.get("lock"), title, boss_title_max)),
              "VimmerLocked")
          end
        end
      end
    end
  end

  add(b.sep)
  add(b.row(common.game_footer({
    { "ENTER", "play" }, { "ZA", "fold" }, { "J/K", "move" }, { "Q", "quit" },
  })), "VimmerTeachFoot")
  add(b.bot)

  return lines, hls, nav
end

M._build_view = build_view
M._tier_fully_cleared = tier_fully_cleared
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/map_view_spec.lua`
Expected: PASS — all `map.build_view` and `map.tier_fully_cleared` examples green.

- [ ] **Step 5: Run the full suite (no regressions)**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — previous count + new examples, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/ui/map.lua tests/spec/map_view_spec.lua
git commit -m "feat(map): pure build_view with fold-aware nav list"
```

---

### Task 2: Wire fold state, render loop, and keymaps into `open_map`

**Files:**
- Modify: `lua/the-vimmer/ui/map.lua` — replace the body of `M.open_map` (currently lines ~63–248) from after the `progress_data` defaulting down to the end of the function.

**Interfaces:**
- Consumes: `build_view`, `tier_fully_cleared` (Task 1); `split_tier_rooms`, `TIERS`, `progress`, `common`, `float`, `api` (existing).
- Produces: `M.open_map(progress_data, rooms_by_tier, on_select)` — same public signature as today, now with folding.

This task's deliverable is interactive Neovim UI that cannot be unit-tested (the busted harness has no live UI). It is verified by (a) the full busted suite staying green and (b) the manual checklist in Step 4.

- [ ] **Step 1: Replace `open_map`'s body**

In `lua/the-vimmer/ui/map.lua`, keep the first four lines of `M.open_map` (the `progress_data` defaulting) unchanged. Replace everything from `local width = common.pick_float_width(...)` through the final `end` of the function with:

```lua
  local width = common.pick_float_width(float.FLOAT_MAP_W)
  local b = common.make_border(width)

  -- Session fold state: auto-fold fully-cleared unlocked tiers. Locked tiers
  -- get no entry (not foldable).
  local folds = {}
  for _, tier in ipairs(TIERS) do
    if progress.is_tier_unlocked(tier, progress_data.cleared) then
      local tr, br = split_tier_rooms(rooms_by_tier[tier])
      folds[tier] = tier_fully_cleared(tr, br, progress_data.cleared)
    end
  end

  local lines, hls, nav = build_view(folds, progress_data, rooms_by_tier, width)
  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  local _sel_ns = api.nvim_create_namespace("the-vimmer-sel")
  local cur_idx = 1

  local function write_menu_row(sel, selected)
    local inner = common.game_menu_row(selected, sel.icon, sel.title, sel.title_max)
    local was = api.nvim_buf_get_option(buf, "modifiable")
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, sel.line - 1, sel.line, false, { b.row(inner) })
    api.nvim_buf_set_option(buf, "modifiable", was)
    if sel.hl and not selected then
      api.nvim_buf_add_highlight(buf, 0, sel.hl, sel.line - 1, 0, -1)
    end
  end

  local function update_selection()
    api.nvim_buf_clear_namespace(buf, _sel_ns, 0, -1)
    if #nav == 0 then return end
    for _, item in ipairs(nav) do
      if item.kind ~= "tier" then write_menu_row(item, false) end
    end
    float.apply_hl(buf, hls)
    local sel = nav[cur_idx]
    if sel then
      if sel.kind ~= "tier" then write_menu_row(sel, true) end
      api.nvim_buf_add_highlight(buf, _sel_ns, "VimmerSelected", sel.line - 1, 0, -1)
      api.nvim_win_set_cursor(win, { sel.line, 0 })
    end
  end

  local function resize()
    local height = #lines
    local row = math.max(0, math.floor((vim.o.lines - height) / 2))
    local col = math.max(0, math.floor((vim.o.columns - width) / 2))
    api.nvim_win_set_config(win, {
      relative = "editor", row = row, col = col, width = width, height = height,
    })
  end

  -- Rebuild from current fold state; keep the cursor on target_tier's header
  -- when given, otherwise clamp the existing index.
  local function render(target_tier)
    lines, hls, nav = build_view(folds, progress_data, rooms_by_tier, width)
    local was = api.nvim_buf_get_option(buf, "modifiable")
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_buf_set_option(buf, "modifiable", was)
    resize()
    if target_tier then
      for i, item in ipairs(nav) do
        if item.kind == "tier" and item.tier == target_tier then cur_idx = i break end
      end
    end
    cur_idx = math.min(math.max(cur_idx, 1), math.max(#nav, 1))
    update_selection()
  end

  local function current_tier()
    local item = nav[cur_idx]
    return item and item.tier or nil  -- tier/room carry .tier; quick has none
  end

  local function toggle_fold(tier)
    if not tier or folds[tier] == nil then return end
    folds[tier] = not folds[tier]
    render(tier)
  end

  local function set_all_folds(value)
    for _, t in ipairs(TIERS) do
      if folds[t] ~= nil then folds[t] = value end
    end
    render(current_tier())
  end

  update_selection()

  local function map_key(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  map_key("j", function()
    if #nav == 0 then return end
    cur_idx = math.min(cur_idx + 1, #nav)
    update_selection()
  end)

  map_key("k", function()
    if #nav == 0 then return end
    cur_idx = math.max(cur_idx - 1, 1)
    update_selection()
  end)

  map_key("za", function() toggle_fold(current_tier()) end)
  map_key("zM", function() set_all_folds(true) end)
  map_key("zR", function() set_all_folds(false) end)

  map_key("<CR>", function()
    local item = nav[cur_idx]
    if not item then return end
    if item.kind == "tier" then
      toggle_fold(item.tier)
    else
      api.nvim_win_close(win, true)
      on_select(item.room)
    end
  end)

  map_key("q", function() api.nvim_win_close(win, true) end)
  map_key("<Esc>", function() api.nvim_win_close(win, true) end)
end
```

- [ ] **Step 2: Run the full suite (no regressions)**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — 0 failures. (The UI rewrite has no automated test; this confirms nothing else broke.)

- [ ] **Step 3: Smoke-load the module under Neovim**

Run:
```bash
nvim --headless --noplugin -c "lua require('the-vimmer.ui.map')" -c "qa" 2>&1
```
Expected: no error output (module loads cleanly with the live `vim.api`).

- [ ] **Step 4: Manual verification (live UI)**

Open the game and the world map (per `README.md` launch instructions). Confirm:
1. A fully-cleared, unlocked tier opens **folded** (`▸` marker, rooms hidden, progress bar still shown).
2. `j`/`k` reaches the folded header; `za` **expands** it (`▾`, rooms appear) and the float recenters.
3. `za` again **collapses** it; the cursor stays on that tier's header.
4. Navigate onto a **cleared** room and press `<CR>` → it replays.
5. `zM` folds every unlocked tier; `zR` expands them all; cursor stays put.
6. A **locked** tier shows no fold marker and is not selectable.
7. `<CR>` on a tier header toggles its fold (same as `za`).

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui/map.lua
git commit -m "feat(map): foldable tier groups with za/zR/zM"
```

---

## Self-Review

**Spec coverage:**
- `za` toggle under cursor → Task 2 `za` map + `toggle_fold`/`current_tier`. ✓
- `zM`/`zR` → Task 2. ✓
- `▾`/`▸` markers + progress bar on folded header → Task 1 `build_view`, tested. ✓
- Uniform nav (headers + all rooms incl. cleared + quick) → Task 1, tested. ✓
- Locked tiers non-navigable, unchanged render → Task 1 (no nav push in the `not unlocked` branch). ✓
- Boss gated (locked boss not navigable) → Task 1 boss branch. ✓
- Session-only fold state, auto-fold cleared → Task 2 fold init. ✓
- `build_view`/`render` split + window resize → Tasks 1 & 2. ✓
- Empty-nav guards → Task 2 `#nav == 0` checks + `render` clamp. ✓
- `<CR>` on header toggles fold → Task 2. ✓

**Placeholder scan:** none — every code/test step is complete.

**Type consistency:** `build_view` returns `lines, hls, nav` in Task 1 and is destructured identically in Task 2. `nav` item fields (`kind`, `tier`, `line`, `room`, `icon`, `title`, `title_max`, `hl`) are produced in Task 1 and consumed by `write_menu_row`/`current_tier`/`<CR>` in Task 2 with matching names. `folds[tier]` boolean-or-nil contract is consistent across `tier_fully_cleared`, init, `toggle_fold`, and `set_all_folds`.
