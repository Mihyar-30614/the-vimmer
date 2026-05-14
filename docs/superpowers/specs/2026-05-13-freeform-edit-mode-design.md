# Free-Form Edit Mode

**Date:** 2026-05-13
**Sub-project:** 1 of 6 (foundation; unlocks replay, randomized content, multiple valid solutions)

## Problem

Today the game scores a player by matching their keystrokes against a fixed
`optimal_keystrokes` list per room. Every key that does not extend the
expected sequence costs 5 HP, even when the player is producing a valid
alternate solution. This punishes idiom diversity (e.g. `cw` vs `ciw`,
`dwi` vs `cw`) and forces room authors to enumerate every accepted path via
`optimal_keystrokes_alternates`.

The buffer-vs-target check that already exists in `ui.lua` (lines
1041–1043) is the real win condition; the keystroke matcher only drives
damage. Decoupling damage from a hard-coded path lets any valid solution
clear the room while still rewarding efficient ones.

## Goals

- Any keystroke sequence that produces `target_text` from `start_text`
  clears the room.
- Inefficient solutions still face pressure (HP drain) so the game does not
  collapse into "mash keys until done".
- XP rewards tight, efficient play.
- No regression for boss rooms (multi-phase clears stay intact).
- Mutators (`iron`, `glass`, `rush`) and power-ups (`hp_restore`,
  `freeze_timer`, `double_xp`) remain functional.

## Non-goals

- Replay/ghost playback (sub-project 2).
- Spaced repetition scheduling (sub-project 3).
- New room content (sub-project 4).
- Sandbox mode (sub-project 5).
- Polish bundle items: `vim.loop.now()`, ui.lua split, colorblind palette
  (sub-project 6).

## Design

### Damage model: keystroke budget with grace then cliff

For each room/phase:

```
budget = ceil(#optimal_keystrokes * 1.5)         -- default
budget = #optimal_keystrokes                     -- iron mutator
```

On every keypress:

```
keystrokes_used = keystrokes_used + 1
if keystrokes_used > budget:
  hp = max(0, hp - over_budget_cost)             -- 5 (default), 8 (glass)
```

There is no "wrong key" concept. Win is detected exclusively by the
buffer-text-vs-target check that already runs in `ui.lua` after every key.

### XP: efficiency multiplier

`progress.calculate_xp(base_xp, hp_remaining, streak, efficiency_mult, double_xp)`

```
efficiency_mult = clamp(#optimal_keystrokes / keystrokes_used, 0.5, 3.0)
```

Edge case: `keystrokes_used == 0` → `efficiency_mult = 1.0` (no division by
zero; should not occur in practice since clear requires at least one
keystroke for any non-trivial room).

Existing bonuses preserved:
- HP bonus (`hp_remaining / 100 * base_xp`) — unchanged.
- Streak bonus (+50% at streak ≥ 3) — unchanged.
- Flawless bonus (+15%) — redefined as
  `keystrokes_used <= #optimal_keystrokes`. Note this is strictly tighter
  than the budget grace: clearing under budget but above optimal still
  costs no HP, but is not flawless.
- `double_xp` power-up — unchanged.

### Game state changes

**Added to `Game` (`game.lua`):**

| Field | Purpose |
|-------|---------|
| `keystrokes_used` | Per-run counter; resets at `begin_play` and at each `advance_boss_phase`. |
| `keystrokes_budget` | Cached `ceil(optimal * 1.5)` (or `* 1.0` under iron); recomputed per phase. |

**Removed from `Game`:**

| Field | Reason |
|-------|--------|
| `_acceptable_sequences` | Sequence matching gone. |
| `_seq_active` | Sequence matching gone. |
| `keys_correct` / `keys_wrong` | Replaced by `keystrokes_used`. |
| `combo` | Replaced by efficiency multiplier. |
| `combo_mult` | Replaced by efficiency multiplier. |
| `correct_streak` | No "correct" notion; HP regen removed too — see below. |

**Removed module-level helper:** `step_sequence_states`.

### HP regen

Today every 3rd correct key restores +2 HP (unless `iron`). Without a
"correct" notion this becomes per-keystroke-while-under-budget. To keep the
model legible, **HP regen is dropped entirely** in free-form mode. Players
already have full HP from start, no extras from the matcher. Iron mutator
loses its "no regen" effect and instead removes budget grace (see above).

### `progress.lua` changes

- `room_stats` schema: replace `keys_correct` and `keys_wrong` with
  `keystrokes_used` and `keystrokes_over_budget`. `keystrokes_over_budget`
  increments by 1 each time `register_key` ticks while
  `keystrokes_used > keystrokes_budget` (i.e. once per HP-drain key).
  Migration: on load, if old keys present, sum them into `keystrokes_used`
  and discard `keys_wrong` (best-effort; lifetime totals preserved).
- `weakest_regular_room_id` ranking metric switches from
  `keys_correct / (keys_correct + keys_wrong)` to
  `1 - (keystrokes_over_budget / keystrokes_used)` (waste ratio inverted).
  Lowest value = weakest room. No new per-room storage needed beyond the
  two counters above.
- `calculate_xp` signature: `combo_mult` parameter renamed to
  `efficiency_mult`. Same arithmetic role (final multiplier on subtotal +
  streak bonus). Single internal caller (`game.lua:complete_room`); no
  external API contract.

### `ui.lua` changes (minimal)

- HUD: remove the combo line (currently `ui.lua:899–911`). Add a budget
  line: `Keys: N/budget`. Colour normal while `N <= budget`, red when over.
- Damage feedback pulse: trigger when `hp` drops (over-budget tick), label
  it `-5 HP (over budget)` instead of `-5 HP (<key>)`.
- Win-detection block (`ui.lua:1038–1064`) untouched.
- Per-key insert-mode CRIT highlight, regen flash, and damage flash:
  remove the regen-flash branch (no regen). Damage-flash fires only on
  over-budget tick. CRIT highlight removed (depended on "is_correct").
- Boss phase reset: call `game_state:advance_boss_phase()` continues to
  reset `keystrokes_used` and recompute `keystrokes_budget`.

### Room data

- `optimal_keystrokes`: still required; now serves as golf reference for
  both budget and efficiency. Authors should keep this as the shortest
  realistic solution.
- `optimal_keystrokes_alternates`: kept for backwards compatibility, but
  display-only. Surfaced in teach screen under "Also valid:". Not used by
  budget/efficiency math.
- `rooms.lua` validator: unchanged required fields; alternates validation
  unchanged.

### Mutator semantics

| Mutator | Old effect | New effect |
|---------|-----------|------------|
| `iron`  | Disable +2 HP regen on every 3rd correct key | Budget = `optimal × 1.0` (no grace) |
| `glass` | Wrong key costs 8 HP instead of 5 | Over-budget key costs 8 HP instead of 5 |
| `rush`  | Timer ticks down 2s per second | Unchanged |

Display strings in `MUTATOR_TEACH` updated to reflect new effects.

### Boss room flow

`begin_play` initialises `keystrokes_used = 0` and computes
`keystrokes_budget` from phase 1. `advance_boss_phase` does the same for
the next phase. HP carries over between phases as today. Timer carries
over.

### Tests

Existing specs touched: `tests/spec/game_spec.lua`,
`tests/spec/progress_spec.lua`, any spec asserting `keys_correct`,
`keys_wrong`, `combo`, or `combo_mult`.

New specs:

1. `register_key` increments `keystrokes_used` on every call.
2. HP unchanged while `keystrokes_used <= budget`.
3. HP drops by 5 (default) once over budget.
4. HP drops by 8 with `glass`.
5. `iron` sets budget = `optimal × 1.0`.
6. `keystrokes_used` resets on `advance_boss_phase`.
7. `calculate_xp` with `efficiency_mult` clamped at 0.5 and 3.0.
8. `complete_room` computes `efficiency_mult` from `optimal/used`.
9. Flawless bonus triggers when `keystrokes_used <= #optimal_keystrokes`.
10. `weakest_regular_room_id` picks lowest efficiency ratio.

### Migration / compatibility

- Save files with old `room_stats.keys_correct`/`keys_wrong` are read and
  merged into `keystrokes_used` on load; new file format thereafter.
- No room files need editing. Existing alternates remain for display.
- `setup()` hooks (`win`, `death`) keep the same payload shape, except
  `death.mistakes` (currently `keys_wrong`) becomes `over_budget_count`.

## Open questions

None blocking. Defer to implementation:
- Final HUD wording for the budget line (`Keys: 7/12` vs `Budget: 7/12`).
- Whether to animate the budget bar (cosmetic).
