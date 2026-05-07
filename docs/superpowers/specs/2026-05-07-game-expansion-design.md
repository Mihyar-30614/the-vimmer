# Game Expansion Design
Date: 2026-05-07

## Overview

Expand the-vimmer with boss rooms, game mechanics (timer, combo, HP regen, power-ups), and 15 new regular rooms. Boss rooms are the anchor: building them forces all mechanics to exist, and regular rooms inherit those systems for free.

---

## Section 1: Architecture

Five systems, each touching specific files:

| System | Files |
|---|---|
| Boss rooms | `rooms.lua`, `game.lua`, `ui.lua`, new `boss.lua` per tier |
| Timer | `game.lua`, `ui.lua` |
| Combo multiplier | `game.lua`, `ui.lua`, `progress.lua` |
| HP regen | `game.lua` |
| Power-ups | `game.lua`, `ui.lua` |
| New rooms | new `.lua` files under `lua/rooms/` |
| Unlock system | `progress.lua`, `ui.lua` |

`game.lua` carries all state. `ui.lua` renders. No new modules.

---

## Section 2: Boss Room System

### Schema

Boss rooms use an extended schema:

```lua
{
  id = "beginner_boss",
  tier = "beginner",
  is_boss = true,
  title = "BOSS: The Gauntlet",
  command = "hjkl + insert + delete",
  description = "Three-phase trial. All beginner skills tested.",
  usage_tip = "...",
  base_xp = 300,
  phases = {
    { start_text = "...", target_text = "...", optimal_keystrokes = {...}, tip = "Phase 1: navigate" },
    { start_text = "...", target_text = "...", optimal_keystrokes = {...}, tip = "Phase 2: insert" },
    { start_text = "...", target_text = "...", optimal_keystrokes = {...}, tip = "Phase 3: combined" },
  },
  time_limit = 120,  -- seconds total across all phases
}
```

`rooms.validate()` accepts boss rooms if they have `is_boss=true` and `phases` instead of `start_text`/`target_text`.

### Flow

1. Map shows boss as `⚔ BOSS: The Gauntlet` at bottom of tier (selectable only after 80% regular rooms cleared)
2. Teach screen shows all 3 phase previews (before/after per phase)
3. Phase 1 starts — timer running, shared across all phases
4. Beat phase → `PHASE 2 ▶` flash on buffer, next phase loads in same buffer (no tab switch)
5. Beat phase 3 → boss victory screen with tier unlock animation
6. Die in any phase → death screen shows `Died in Phase 2/3`

### Boss content

**`beginner_boss` — "The Gauntlet" (120s)**
- Phase 1: navigate 8-line file with hjkl to 6 cursor positions
- Phase 2: insert/append/open-line edits on paragraph
- Phase 3: navigate + delete + yank + paste to reorder a file

**`warrior_boss` — "The Siege" (150s)**
- Phase 1: f-motion + search chain across dense code
- Phase 2: visual block + ciw on 6 parallel lines
- Phase 3: record macro, apply 6 times across mixed file

**`ninja_boss` — "The Void" (180s)**
- Phase 1: multi-register workflow (yank 4 things, paste in reverse)
- Phase 2: nested text-objects on deeply nested code
- Phase 3: macro + registers + text-objects combined refactor task

---

## Section 3: Game Mechanics

### Timer

- `game_state.timer_remaining` (seconds). `vim.loop.new_timer()` decrements every second during play.
- Time up = death (same path as HP=0).
- Timer persists across boss phases (shared countdown).
- Regular rooms have optional `time_limit` field. Rooms without it: no timer shown.
- HUD color: green >50%, yellow 25–50%, red <25%.

### Combo Multiplier

- `game_state.combo` counter. Correct key = +1. Wrong key = reset to 0.
- Thresholds: 0–4 = x1 | 5–9 = x2 | 10+ = x3.
- Shown in HUD as `x2`.
- Applied in `progress.calculate_xp()` as final multiplier factor.

### HP Regen

- `game_state.correct_streak` internal counter (separate from win-streak).
- Every 3 consecutive correct keys: +2 HP (capped at 100). Wrong key resets counter.
- Brief green flash on HP bar portion of HUD.

### Power-ups

**Earning:** finish a room with >50% time remaining → results screen shows power-up choice section.

**Choice UI:** extra section at bottom of results float, j/k select, Enter pick.

**Pool:**
- `hp_restore` — +30 HP at start of next room
- `freeze_timer` — pause timer 5s on demand (`<Tab>` during play)
- `double_xp` — 2x XP from next room

**Storage:** `game_state.power_ups` list, max 2 held. Shown as icons in HUD.

**Application:** `hp_restore` and `double_xp` auto-apply at room start. `freeze_timer` is manual (`<Tab>`).

### Updated HUD

```
 HP [████████░░] 80%  ⏱ 1:45  x2  Streak 3  |  ciw  [⚡][★]
```

---

## Section 4: New Regular Rooms

15 rooms total, 5 per tier. All use bigger multi-line buffers.

### Beginner (5 new rooms)

| ID | Challenge |
|---|---|
| `beginner_hjkl2` | Navigate 6-line paragraph to 5 target cursor positions |
| `beginner_word_hop` | `w`/`b`/`e` across multi-word line, delete specific words |
| `beginner_insert2` | `a`/`A`/`o`/`O` — append to lines, open new lines |
| `beginner_dd_yp` | `dd`/`yy`/`p` — reorder 4 lines by cut-paste |
| `beginner_counts` | `3w`, `2dd`, `5l` — numeric prefixes on multi-line block |

### Warrior (5 new rooms)

| ID | Challenge |
|---|---|
| `warrior_n_repeat` | `/pattern` + `n`/`N` replace 4 occurrences in paragraph |
| `warrior_ft_chain` | `f`/`t`/`;`/`,` chain across a complex line |
| `warrior_visual_block` | Visual block select + insert on 5 parallel lines |
| `warrior_ci_combo` | `ci"` + `ci(` + `ci{` in nested code |
| `warrior_change_chain` | `cw`/`C`/`cc` on 4-line function signature |

### Ninja (5 new rooms)

| ID | Challenge |
|---|---|
| `ninja_global_macro` | Macro on 8-line block, `100@a` bulk-apply |
| `ninja_registers2` | Named + numbered registers: yank 3, paste in order |
| `ninja_surround_obj` | `da"`/`di(`/`ca{` on deeply nested code |
| `ninja_marks` | `ma`, `'a`, backtick-a for long-range jumps |
| `ninja_substitute` | `:%s/foo/bar/g` and `:'<,'>s` on visual selection |

---

## Section 5: Unlock System

### New two-step gate

1. **80% regular rooms** cleared in tier → boss room becomes selectable
2. **Boss cleared** → next tier unlocks

### `progress.lua` changes

- `is_tier_unlocked()` — unchanged signature, updated logic: warrior unlocked when `beginner_boss` in `cleared`
- New: `is_boss_unlocked(tier, cleared, total_regular)` — returns true when 80% regular rooms cleared
- Boss room IDs stored in `cleared` map same as regular rooms (no schema change to save file)

### Map rendering

- Boss shown at bottom of tier, always visible once tier is visible
- Boss locked: `⚔ THE GAUNTLET  [locked — clear 80% first]` dim color, not selectable
- Boss unlocked, not cleared: `⚔ THE GAUNTLET` selectable, distinct highlight
- Boss cleared: `✓ ⚔ THE GAUNTLET` in cleared color

---

## Summary

| Deliverable | Count |
|---|---|
| New regular rooms | 15 (5 per tier) |
| Boss rooms | 3 (3 phases each) |
| New mechanics | 4 (timer, combo, HP regen, power-ups) |
| Files modified | `game.lua`, `ui.lua`, `progress.lua`, `rooms.lua` |
| Files created | 18+ room files, 3 boss files |
