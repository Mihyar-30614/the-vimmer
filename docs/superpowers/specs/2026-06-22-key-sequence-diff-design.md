# Key-sequence diff on the results screen

**Date:** 2026-06-22
**Status:** Approved design

## Problem

The game never inspects *which* keys the player pressed. `register_key`
(`lua/the-vimmer/game.lua`) only counts keystrokes against a budget; the win
condition is a plain buffer match (`lua/the-vimmer/ui/play.lua`). The
`acceptable_key_sequences` data in `lua/the-vimmer/rooms.lua` is never consulted
during play. A room like `beginner_hjkl` can be cleared with arrow keys or an
unrelated edit and still "win" as long as the keystroke count stays under
budget. The teaching loop never closes: the player is told how many keys they
used, but not what an efficient solution looked like next to their own.

## Goal

Close the teaching loop with a **passive, post-run** comparison on the results
screen: show the player's actual keys beside the most efficient accepted path,
the keystroke delta, and an optional tailored hint. No gameplay mechanics
change — HP, budget, and win conditions are untouched. No rebalancing required.

## Non-goals

- No live/in-play penalty for leaving the optimal path (explicitly rejected:
  would require retuning every room's HP and budget).
- No per-key aligned diff / LCS marking (rejected: side-by-side is enough).
- No changes to `key_replay.lua` — it animates the optimal path only and remains
  a separate feature.
- No new user commands.

## Decisions (locked during brainstorming)

1. **Passive feedback only** — record keys, display diff on results. Mechanics
   unchanged.
2. **Side-by-side, no alignment** — show "your keys", "optimal", a delta count,
   and a hint. No per-key inline marking.
3. **Hint = optional authored field + fallback** — rooms may set
   `efficiency_hint`; rooms without it get a generic fallback line.

## Architecture

Five touch points, ordered from data capture to display.

### 1. Capture player keys — `lua/the-vimmer/game.lua`

- Add `keystroke_log = {}` to the state table in `M.new()`.
- In `register_key(key)`, append the raw `key` string:
  `self.keystroke_log[#self.keystroke_log + 1] = key`. Keep this *before* the
  budget/HP logic so every key is logged regardless of budget state.
- Reset the log where per-phase keystroke state already resets:
  - `begin_play()` — `self.keystroke_log = {}`
  - `advance_boss_phase()` — `self.keystroke_log = {}`
  (Per-phase reset means a boss results screen reflects the **final** phase
  only. Accepted limitation; documented here and in the results section.)
- Add accessor `function g:keystroke_log_keys() return self.keystroke_log end`.

Rationale for storing **raw** bytes: `vim.on_key` (the source in `play.lua`)
delivers raw key strings — `"\27"` for `<Esc>`, single chars for typed input,
one call per key. `common.format_key` already decodes raw bytes to display
notation, so storing raw and formatting at display time is lossless and reuses
existing code. Multi-key commands such as `ciw` arrive as three calls (`c`,
`i`, `w`), matching the single-key granularity used for comparison.

Optional safety cap: stop appending past 300 logged keys to bound memory on a
pathological run. The display wraps regardless.

### 2. Key expansion + baseline selection — `lua/the-vimmer/ui/common.lua`

Player keys are single-key granularity; `optimal_keystrokes` stores tokens
(`"ciw"`, `"<Esc>"`, `"j"`). To count fairly, expand optimal tokens to single
keys.

- `M.expand_keys(tokens)` → flat list of single keys. Rule per token: a `<...>`
  notation chunk counts as one key; every other character counts as one key.
  Examples: `"ciw"` → `{"c","i","w"}`; `"<Esc>"` → `{"<Esc>"}`; `"5"` → `{"5"}`.
  Pure function, no Neovim state.
- `M.pick_baseline(room_or_phase_ctx)` → returns `{ tokens = <token list>,
  expanded_count = <int> }` for the accepted sequence with the **fewest expanded
  keystrokes** (the most efficient path). Uses
  `require("the-vimmer.rooms").acceptable_key_sequences(ctx)` to enumerate the
  primary + alternates, expands each, picks the minimum by expanded length. Ties
  broken by first occurrence (primary wins). Returns `nil` if no sequence
  exists.

`expand_keys` and `pick_baseline` are pure and unit-testable headlessly.

### 3. Schema: optional hint — `lua/the-vimmer/rooms.lua`

- Add `efficiency_hint` as an **optional** field on both regular rooms and boss
  phases.
- `validate_efficiency_hint(h)` — `nil` or a string. Wire it into
  `validate_optional_additions(ctx)` alongside the existing optional validators.
- Add `efficiency_hint = ctx.efficiency_hint` to `M.phase_view(ctx)` so the UI
  reads it uniformly for rooms and boss phases.
- No edits to the 60 existing room files. Unset hints fall back at display time.
  Authors backfill `efficiency_hint` over time.

### 4. Display — `lua/the-vimmer/ui/results.lua`

Replace the current standalone "Optimal sequence:" block (lines ~89–95) with a
single comparison block. New `run_stats` fields drive it (see §5). Render only
when `#keystroke_log > 0` **and** a baseline exists; otherwise fall back to the
existing optimal-only block so behavior never regresses when data is absent.

Block layout (each line built with `b.row`, wrapped via the existing
`append`/`optimal_inner` width handling):

```
  Your keys (15):  j l l l l l l l l l l l l r 5
  Optimal (4):     j $ r 5
  Delta: +11 keys over optimal
  Hint: use $ to jump to line end
```

- "Your keys (N)": N = `#keystroke_log`; each key rendered via
  `common.format_key`, space-joined, wrapped at `optimal_inner`. Highlight
  `VimmerCommand` (matches existing optimal styling).
- "Optimal (M)": M = baseline `expanded_count`; tokens rendered via
  `common.build_optimal_lines`-style formatting (token form, not expanded, for
  readability). Note: M reflects true keystroke count, which may exceed the
  number of visible tokens (e.g. `ciw` shows as one token, counts as 3).
- "Delta": `+(N - M) keys over optimal` when `N > M`; `optimal — N keys, matched
  the efficient path` when `N <= M`. Highlight `VimmerDamage` when over,
  `VimmerCleared` when matched/under.
- "Hint": shown only when `N > M`. Use authored `efficiency_hint` if present,
  else fallback `"<N-M> keys over optimal — see sequence above"`. Highlight
  `VimmerXP`.

For boss rooms the block reflects the final phase (per §1). Acceptable.

### 5. Wiring — `lua/the-vimmer/commands.lua`

Extend the `run_stats` table passed to `open_results` (currently ~line 125):

```lua
run_stats = {
  ...existing fields...,
  keystroke_log   = g:keystroke_log_keys(),
  optimal_tokens  = baseline and baseline.tokens or nil,
  optimal_count   = baseline and baseline.expanded_count or nil,
  efficiency_hint = phase_view.efficiency_hint,
}
```

`baseline` comes from `common.pick_baseline(phase_ctx)` where `phase_ctx` is the
final phase for a boss (`room.phases[g.boss_phase]`) or `room` otherwise.
`phase_view` is `rooms.phase_view(phase_ctx)`.

## Data flow

```
play.lua (vim.on_key, raw key)
  -> game:register_key(key)        appends raw key to keystroke_log
  ...
commands.lua on_win
  -> common.pick_baseline(phase_ctx)         picks fewest-expanded path
  -> run_stats { keystroke_log, optimal_tokens, optimal_count, efficiency_hint }
  -> ui.open_results(..., run_stats)
results.lua
  -> format_key over keystroke_log           "Your keys (N)"
  -> tokens + optimal_count                   "Optimal (M)"
  -> delta + hint
```

## Error handling / edge cases

- **No keys logged** (`used == 0`) or **no baseline**: skip the comparison
  block, render the existing optimal-only block. No crash, no empty section.
- **Mouse / arrow keys**: `vim.on_key` delivers them as multi-byte termcodes;
  `format_key` passes them through raw (possibly ugly). Acceptable for v1; a
  prettier mapping is future polish.
- **Insert-mode text**: typed characters log one per key and are part of the
  optimal sequence for insert rooms, so granularities match.
- **Boss rooms**: log resets per phase; results reflect the final phase only.
- **Long runs**: optional 300-key cap on the log bounds memory; display wraps.
- **Headless tests**: `keystroke_log` capture, `expand_keys`, and `pick_baseline`
  work without a running Neovim (pure Lua + existing headless guards).

## Testing

- `tests/spec/common_spec.lua` — `expand_keys` (multi-char tokens, `<...>`
  notation, counts, empty input); `pick_baseline` (single path, alternates,
  min-by-expanded-length, tie → primary, nil when empty).
- `tests/spec/game_spec.lua` — `register_key` appends to `keystroke_log`;
  `begin_play` and `advance_boss_phase` reset it; `keystroke_log_keys` returns
  the list.
- `tests/spec/rooms_spec.lua` — `validate` accepts a room with a string
  `efficiency_hint`, rejects a non-string, accepts a room without it;
  `phase_view` surfaces `efficiency_hint` for rooms and boss phases.
- Results rendering is exercised indirectly; the pure helpers carry the
  load-bearing logic and are covered above.

## Files touched

- `lua/the-vimmer/game.lua` — log capture + reset + accessor
- `lua/the-vimmer/ui/common.lua` — `expand_keys`, `pick_baseline`
- `lua/the-vimmer/rooms.lua` — `efficiency_hint` validation + `phase_view`
- `lua/the-vimmer/ui/results.lua` — comparison block
- `lua/the-vimmer/commands.lua` — `run_stats` plumbing
- tests as above

No new commands, no schema migration, no save-format change.
