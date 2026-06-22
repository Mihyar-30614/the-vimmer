# `grandmaster` tier — ex-command & line-op mastery

**Date:** 2026-06-22
**Status:** Approved design

## Problem

The game tops out at the `ninja` tier. The most powerful day-to-day Vim
techniques — substitute with capture groups, `:g` driving `:normal`/`:m`,
line copy/move (`:t`/`:m`), range `:normal`, external filters, and folds — are
either untaught or only touched at a basic level. There is no end-game content
for players who have cleared ninja.

## Goal

Add a fourth tier, `grandmaster`, unlocked after the ninja boss: **10 rooms +
1 three-phase boss**, focused on ex-command and line-operation mastery. Nine
rooms are text-mutating (strongly taught and reachability-checked); one is a
folds navigation room (weakly enforced, like the existing marks/jumplist rooms).

## Non-goals

- No splits/tabs rooms — the play engine only processes keys while the cursor is
  in the play window (`play.lua` `if api.nvim_get_current_win() ~= play_win then
  return end`), so leaving the window breaks input. Rejected during brainstorming.
- No multi-file rooms (quickfix/`:argdo`/`:bufdo`) — single scratch buffer only.
- No engine changes; no new mechanics. Pure content + tier wiring.

## Decisions (locked during brainstorming)

1. Tier name: **grandmaster** (directory `lua/rooms/grandmaster/`, ids
   `grandmaster_*`, map/progress label `GRANDMASTER`).
2. Size: **10 rooms + boss**, matching existing tier depth.
3. Content: **9 text-ops + 1 folds**; multi-file and splits/tabs dropped.
4. Unlock: after `ninja_boss` is cleared.

## Architecture

### Part A — Tier wiring (7 enumeration points)

The tier list is duplicated across several modules. All must gain
`grandmaster`:

1. `lua/the-vimmer/rooms.lua:8` — `TIERS = { "beginner", "warrior", "ninja", "grandmaster" }`.
2. `tests/reachability.lua:22` — same `TIERS` literal (harness scans tiers).
3. `lua/the-vimmer/progress.lua` `is_tier_unlocked` (~154) — extend the boss-id
   resolution so `grandmaster` requires `ninja_boss`:

   ```lua
   function M.is_tier_unlocked(tier, cleared)
     if tier == "beginner" then return true end
     local boss_id =
       (tier == "warrior") and "beginner_boss"
       or (tier == "ninja") and "warrior_boss"
       or "ninja_boss"   -- grandmaster
     return cleared[boss_id] == true
   end
   ```

4. `lua/the-vimmer/highlights.lua` (~93) — add
   `hl(0, "VimmerTierGrandmaster", { bold = true, fg = "#bd93f9" })` (a purple
   distinct from ninja's pink, consistent with the existing Dracula-ish palette).
5. `lua/the-vimmer/ui/map.lua` (~27-34) — add `grandmaster` to `tier_colors`
   (`VimmerTierGrandmaster`), `tier_labels` (`"GRANDMASTER"`), `tier_prereq`
   (`grandmaster = "complete boss first"`), and the `tiers` array.
6. `lua/the-vimmer/ui/progress.lua` (~24-31) — same four additions.
7. `lua/the-vimmer/ui/results.lua` (~130) — add `grandmaster =
   "VimmerTierGrandmaster"` to the new-tier-unlocked banner group map.

`is_boss_unlocked`, `check_newly_unlocked`, and `build_rooms_by_tier` are already
generic (prefix / `all_tiers()` based) and need no change once `TIERS` includes
`grandmaster`.

**Label width:** `"GRANDMASTER"` is 11 chars. Map header rows format as
`"  [%s]  %d/%d ..."`; `FLOAT_MAP_W` accommodates the existing labels with
margin. The label fits the bracket line; no truncation of the label itself is
needed, but the design verifies rendering during implementation and shortens the
boss-title `:sub()` budget only if a row overflows.

### Part B — Room roster

Each regular room is a standard room table (full required schema) **with**
`goal` (opts into the reachability harness), `efficiency_hint`, `filetype`,
`cursor_start`, `base_xp` (scaled above ninja, ~80–110), and `time_limit`.
Optimal sequences are authored as real, reachability-verified keystrokes.

Nine text-ops rooms:

1. `grandmaster_sub_captures` — `:s/\(\w\+\) \(\w\+\)/\2 \1/` swap two words via
   capture groups.
2. `grandmaster_sub_amp` — `:%s/\d\+/[&]/g` wrap every number using `&` (whole
   match).
3. `grandmaster_global_normal` — `:g/TODO/normal A!` append to matching lines.
4. `grandmaster_global_move` — `:g/^#/m$` move comment lines to end (or
   `:g/pat/m0` to reverse a block — exact pattern chosen for deterministic
   reachability).
5. `grandmaster_copy` — `:t` line copy (e.g. `:1t$` duplicate first line to end).
6. `grandmaster_move` — `:m` line move (e.g. `:m0` move a line to top).
7. `grandmaster_filter` — `:%!sort` filter the buffer through an external
   command (POSIX `sort`, present on supported platforms).
8. `grandmaster_norm_range` — `:%norm I- ` prefix every line via a range
   `:normal` (distinct from ninja's `:norm` by using a different range/op).
9. `grandmaster_amp_repeat` — `:s/old/new/` then `:&` (or `&` in normal) to
   repeat the last substitute on another line.

One folds nav room:

10. `grandmaster_folds` — set `bo = { foldmethod = "indent" }`; player uses
    `zR`/`za`/`zj` to navigate folds, then makes a small edit. Weakly enforced
    (win is buffer text), documented as a nav room; **no `goal`** so the
    reachability harness skips it (folds don't change text, so a goal-based
    transform check is meaningless). Budget still teaches via `optimal_keystrokes`.

### Part C — Boss

`grandmaster_boss` — three phases combining the tier's pillars:

- Phase 1: capture-group substitute (reformat a list).
- Phase 2: `:g/pat/normal` batch edit.
- Phase 3: `:t`/`:m` range reshaping.

Schema mirrors `lua/rooms/ninja/boss.lua` (BOSS_REQUIRED: `id`, `tier`,
`command`, `title`, `description`, `usage_tip`, `base_xp`, `phases`,
`time_limit`; each phase has `tip`, `goal`, `start_text`, `target_text`,
`optimal_keystrokes`, `filetype`, `cursor_start`). `base_xp` ~900, `time_limit`
~360. Each phase sets `goal` so the harness checks it.

## Data flow

No new runtime paths. The tier loads through the existing
`rooms.load_tier("grandmaster")` (driven by `TIERS`), appears on map/progress
via the enumeration additions, unlocks via `is_tier_unlocked`, and plays through
the unchanged `start_flow`. Rooms with `goal` are validated by the reachability
harness.

## Error handling / edge cases

- **`:%!sort` filter room:** relies on an external `sort`. If a CI/runtime lacks
  it the reachability check for that one room would fail loudly (not silently
  wrong). Acceptable; `sort` is POSIX-standard. If it proves flaky in CI, the
  room's `goal` can be removed to exempt it (budget-only), noted in the plan.
- **Folds room:** no `goal` → harness skips it; it cannot produce a false
  reachability failure. Solvable without folding (weak enforcement) — accepted.
- **Label width:** verified at implementation; boss-title `:sub()` budget on the
  map is the only thing trimmed if a row overflows.
- **Unlock gating:** `grandmaster` rooms are hidden/locked until `ninja_boss`
  cleared, via the existing map/progress lock rendering plus `is_tier_unlocked`.
- **Reachability:** every text-ops room + every boss phase carries `goal` and is
  authored to pass `nvim --headless -l tests/reachability.lua`.

## Testing

- `tests/reachability.lua` — extended `TIERS` auto-checks all 9 text-ops rooms +
  3 boss phases (each has `goal`). Must report all sequences pass.
- `tests/spec/rooms_spec.lua` — assert `rooms.load_tier("grandmaster")` returns
  the 10 rooms + boss and each validates; assert `efficiency_hint` present on
  regular rooms.
- `tests/spec/progress_spec.lua` — `is_tier_unlocked("grandmaster", cleared)` is
  false without `ninja_boss` and true with it.
- Headless smoke — open the map with a save that has `ninja_boss` cleared and
  confirm the GRANDMASTER section renders without error.

## Files touched

- `lua/the-vimmer/rooms.lua` — `TIERS`
- `tests/reachability.lua` — `TIERS`
- `lua/the-vimmer/progress.lua` — `is_tier_unlocked` boss-id chain
- `lua/the-vimmer/highlights.lua` — `VimmerTierGrandmaster`
- `lua/the-vimmer/ui/map.lua` — tier enumeration (4 tables)
- `lua/the-vimmer/ui/progress.lua` — tier enumeration (4 tables)
- `lua/the-vimmer/ui/results.lua` — unlock-banner group map
- `lua/rooms/grandmaster/*.lua` — 10 rooms + boss (new directory)
- `README.md` — tier table row; room count

No save-format change (tiers are derived; `unlocked_tiers` is additive and
already deep-merged).
