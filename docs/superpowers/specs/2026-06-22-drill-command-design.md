# `:VimmerDrill` — practice your weakest rooms

**Date:** 2026-06-22
**Status:** Approved design

## Problem

`progress.weakest_regular_room_id` already computes the single room with the
worst keystroke-waste ratio, and the map surfaces it as a one-off "Drill"
suggestion. But there is no way to run a focused practice *session* across
several weak spots — the player has to return to the map and re-pick after every
room. The metrics exist; the practice loop does not.

## Goal

Add a `:VimmerDrill` command that plays the player's **3 weakest regular rooms
back-to-back** (worst keystroke-waste first), then returns to the map. Reuse the
existing play flow; add only a small queue mechanism.

## Non-goals

- No configurable count (rejected during brainstorming — fixed at 3).
- No new scoring, mutators, or rewards specific to drills.
- No change to the map's existing single-room "Drill" suggestion.
- No spaced-repetition scheduling beyond "worst waste ratio right now".

## Decisions (locked during brainstorming)

1. `:VimmerDrill` plays the **top 3 weakest** rooms sequentially, then map.
2. Selection metric: existing keystroke-waste ratio
   (`keystrokes_over_budget / keystrokes_used`), highest first.

## Architecture

Two touch points: selection (progress) and a queued play flow (commands).

### 1. Selection — `lua/the-vimmer/progress.lua`

Generalise the existing single-room finder into an N-room finder, then make the
old function a thin wrapper (DRY — the map still calls the singular form).

- Add:

  ```lua
  -- Return up to `n` regular room IDs across unlocked tiers, ordered by
  -- keystroke-waste ratio (keystrokes_over_budget / keystrokes_used) descending.
  -- Only rooms with attempts > 0 and keystrokes_used > 0 are eligible.
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
    for i = 1, math.min(n or #scored, #scored) do
      ids[i] = scored[i].id
    end
    return ids
  end
  ```

- Rewrite the existing finder as a wrapper:

  ```lua
  function M.weakest_regular_room_id(prog, rooms_by_tier)
    return M.weakest_regular_room_ids(prog, rooms_by_tier, 1)[1]
  end
  ```

  The tie-break (`a.id < b.id`) makes ordering deterministic, which the existing
  singular behaviour did not guarantee — acceptable and testable.

### 2. Queued play flow — `lua/the-vimmer/commands.lua`

The play flow already supports a "continue to next" path in the `open_results`
`on_continue` callback (the `go_map == false` branch, currently advancing to the
next room in the same tier). Add a queue that takes precedence.

- `flow_opts` gains two optional fields, both nil for normal play:
  - `queue` — an array of room tables to play in order.
  - `queue_idx` — 1-based index of the *current* room within `queue`.

- In the `on_continue` callback, at the very top of the `go_map == false`
  branch (after the `if go_map then show_map(); return end` guard), insert:

  ```lua
  if flow_opts.queue and flow_opts.queue_idx then
    local nxt = flow_opts.queue[flow_opts.queue_idx + 1]
    if nxt then
      M.start_flow(nxt, { queue = flow_opts.queue, queue_idx = flow_opts.queue_idx + 1 })
    else
      show_map()
    end
    return
  end
  ```

  This runs before the existing next-room-in-tier logic, so during a drill the
  queue drives progression and the tier auto-advance is bypassed. When the queue
  is exhausted, control returns to the map.

- Death handling needs no change: `on_death` already calls
  `M.start_flow(room, flow_opts)`, and `flow_opts` carries `queue`/`queue_idx`,
  so a retry stays inside the drill at the same position. Clearing then advances.

- Register the command in `M.register`, alongside the other `:Vimmer*`
  commands:

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

## Data flow

```
:VimmerDrill
  -> weakest_regular_room_ids(prog, rooms_by_tier, 3) -> {id1, id2, id3}
  -> resolve to room tables -> queue
  -> start_flow(queue[1], { queue, queue_idx = 1 })
       teach -> play -> results
         on_continue(go_map=false):
           queue has next? -> start_flow(queue[idx+1], { queue, queue_idx=idx+1 })
           else -> map
         on_death: start_flow(room, flow_opts)  (same queue position)
```

## Error handling / edge cases

- **No eligible rooms** (nobody has attempted a room, or no over-budget data):
  `weakest_regular_room_ids` returns `{}` → command notifies and returns. No
  crash, no empty play session.
- **Fewer than 3 eligible rooms:** queue holds 1 or 2; the session plays those
  and returns to the map. `math.min` guards the slice.
- **A weak room's ID no longer resolves** (e.g. a room pack was removed): the
  `get_room` guard skips it; the queue shrinks accordingly.
- **Locked tiers:** `is_tier_unlocked` filter excludes their rooms, same as the
  existing singular finder.
- **Boss rooms:** excluded (`not r.is_boss`), as before.
- **Death mid-drill:** retry stays at the same queue position via `flow_opts`.
- **Headless tests:** `weakest_regular_room_ids` is pure Lua over a `prog` table
  plus a `rooms_by_tier` map; no Neovim needed.

## Testing

- `tests/spec/progress_spec.lua` — `weakest_regular_room_ids`:
  - orders eligible rooms by waste ratio descending;
  - limits to `n`;
  - excludes rooms with `attempts == 0` or `keystrokes_used == 0`;
  - excludes locked-tier rooms;
  - deterministic tie-break by id;
  - returns `{}` when nothing is eligible;
  - `weakest_regular_room_id` returns the same room as `..._ids(...,1)[1]`.
- The `:VimmerDrill` command + queue threading are integration-level (need the
  full play UI); verified by a headless smoke check that the command is
  registered and runs without error when no rooms are eligible (the notify
  path), plus manual play-through.

## Files touched

- `lua/the-vimmer/progress.lua` — `weakest_regular_room_ids` + wrapper rewrite
- `lua/the-vimmer/commands.lua` — queue branch in `on_continue`; `:VimmerDrill`
- `README.md` — document `:VimmerDrill` in the commands table

No new save fields, no migration, no gameplay rebalancing.
