# Personal best (keys + time) on the teach screen

**Date:** 2026-06-22
**Status:** Approved design

## Problem

The save data already records a best *time* per room (`room_best[id]`, seconds,
written in `commands.lua` `on_win`), but it is only ever shown on the results
screen *after* a run. The player never sees a target to beat *before* playing,
and best keystroke count — now meaningful thanks to the keystroke log — is not
tracked at all. There is no "beat your record" hook at the moment of decision
(the teach screen).

## Goal

Track a personal best **keystroke count** per room alongside the existing best
time, and surface both on the **teach screen** as a single line
(`PB: 4 keys · 0:08`) so the player has a concrete target before each run. No
gameplay mechanics change.

## Non-goals

- No map-screen per-room PB display (rejected during brainstorming — teach only).
- No global/cross-player leaderboard.
- No change to the results-screen PB/time display (already exists).
- No new commands.

## Decisions (locked during brainstorming)

1. Record **best keystrokes AND best time**; show both on the **teach screen**.
2. Map screen stays as-is.

## Architecture

Three touch points: storage, plumbing, display.

### 1. Storage — `lua/the-vimmer/progress.lua`

- Add `room_best_keys = {}` to `default_state()`. `load()` deep-merges defaults,
  so existing save files gain the empty table automatically — no migration code.
- Add a recorder:

  ```lua
  -- Record a best (minimum) keystroke count for a room. Returns true when this
  -- run set a new best (including the first recorded run).
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

  Mirrors the existing min-time pattern (`commands.lua:73`). Lower is better.

### 2. Plumbing — `lua/the-vimmer/commands.lua`

- In `on_win`, after `g:complete_room()` and near the existing `room_best`
  block, capture the pre-run best and record the new one:

  ```lua
  local prev_best_keys = (prog.room_best_keys or {})[room.id]
  d.progress.record_best_keys(prog, room.id, g.keystrokes_used)
  ```

  This runs before `d.progress.save(prog)` (existing call), so the new best
  persists. `prev_best_keys` is not needed by the results screen (results
  already reports keystrokes); it is only saved.

- In `start_flow`, before `d.ui.open_teach(...)` (currently `commands.lua:173`),
  compute the PB bag from the already-loaded `prog`:

  ```lua
  local pb = {
    keys    = (prog.room_best_keys or {})[room.id],
    seconds = (prog.room_best or {})[room.id],
  }
  flow_opts.pb = pb
  ```

  `flow_opts` is the existing context bag passed to `open_teach`. Adding `pb` to
  it keeps the `open_teach` signature unchanged.

  Note: `start_flow` mutates the caller's `flow_opts`; it already defaults it to
  `{}` at the top, and the only persistent caller (drill/daily) does not reuse
  the same table across rooms in a way that conflicts. Setting `pb` per call is
  safe because `start_flow` recomputes it each invocation.

### 3. Display — `lua/the-vimmer/ui/teach.lua`

- `open_teach` already extracts `flow_opts` (handles both the table and the
  legacy function-as-second-arg form). Read `flow_opts.pb`.
- Build a PB line via a pure helper in `common.lua` so it is unit-testable:

  ```lua
  -- Format a "PB: N keys · M:SS" line from a pb table { keys, seconds }.
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

- In `teach.lua`, just before the footer block (`add(b.sep)` + the
  `<Enter> begin ...` row), insert:

  ```lua
  local pb_line = common.pb_line(flow_opts.pb)
  if pb_line then
    add(b.sep)
    add(b.row(pb_line), "VimmerXP")
  end
  ```

- Boss rooms: `keystrokes_used` is per-phase, so a single keystroke PB is
  misleading for bosses. `record_best_keys` is still called (harmless), but the
  teach screen should not show a keys PB for bosses. Guard at the call site:
  pass `pb.keys = nil` when `room.is_boss` so only the time PB (if any) shows.
  Implement in `start_flow`:

  ```lua
  local pb = {
    keys    = (not room.is_boss) and (prog.room_best_keys or {})[room.id] or nil,
    seconds = (prog.room_best or {})[room.id],
  }
  ```

## Data flow

```
on_win: record_best_keys(prog, id, keystrokes_used) -> prog.room_best_keys[id]
        progress.save(prog)
start_flow: pb = { keys (skip if boss), seconds } from prog
        -> flow_opts.pb -> open_teach
teach.lua: common.pb_line(flow_opts.pb) -> "  PB: 4 keys · 0:08" (VimmerXP)
```

## Error handling / edge cases

- **No prior run:** both `room_best_keys[id]` and `room_best[id]` are nil →
  `pb_line` returns nil → no PB row rendered. No crash.
- **Only one side present** (e.g. untimed room has no seconds): `pb_line` shows
  just the keys side.
- **First clear:** `record_best_keys` returns true and stores the count; the
  PB shows on the *next* visit to that room's teach screen.
- **Boss rooms:** keys PB suppressed; time PB shown if recorded.
- **keystrokes_used == 0** (degenerate): `record_best_keys` ignores it.
- **Headless tests:** `record_best_keys` and `pb_line` are pure Lua.

## Testing

- `tests/spec/progress_spec.lua` — `record_best_keys`: first run records and
  returns true; a lower count overwrites and returns true; an equal/higher
  count keeps the old and returns false; `keys <= 0` returns false; missing
  `room_best_keys` table is created.
- `tests/spec/ui_common_spec.lua` — `pb_line`: both sides; keys-only;
  seconds-only; neither → nil; non-table → nil.
- `start_flow`/`teach.lua` wiring exercised via a headless smoke check.

## Files touched

- `lua/the-vimmer/progress.lua` — `room_best_keys` default + `record_best_keys`
- `lua/the-vimmer/commands.lua` — record best keys in `on_win`; build `pb` in `start_flow`
- `lua/the-vimmer/ui/common.lua` — `pb_line` helper
- `lua/the-vimmer/ui/teach.lua` — render PB row

No new commands, no save-format migration (additive field only).
