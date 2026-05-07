# Animated Feedback Design

**Date:** 2026-05-07  
**Approach:** Extend in-place (Option A) — no new modules, all changes inside `ui.lua` and `highlights.lua`

---

## Overview

Add four animated feedback effects to make gameplay feel more responsive and satisfying:

1. HP damage / regen flash
2. Keystroke crit highlight
3. Combo pop-up text in HUD
4. Multi-step death / win animation

---

## 1. HP Damage & Regen Flash

**Trigger:** Inside `vim.on_key` callback in `start_phase()`, after `game_state:register_key(key)`.

**Wrong key (damage):**
- After `register_key`, check `game_state:is_dead()` first
- If dead: skip damage flash entirely, go straight to death sequence
- If not dead: call `flash(play_buf, "VimmerDamage", 80)` — red background, 80ms

**Correct key, regen tick (every 3 correct):**
- Detect regen: `game_state.correct_streak % 3 == 0` after a correct key
- Call `flash(play_buf, "VimmerRegen")` — green background, 80ms

**New highlight groups** (`highlights.lua`):
- `VimmerDamage` — red background (e.g. `#5c1010` bg, `#ff8080` fg)
- `VimmerRegen` — green background (e.g. `#0d3b1a` bg, `#80ff99` fg)

`flash()` gains an optional `duration` param (default 100ms): `flash(buf, group, duration, callback)`.

**Files changed:** `ui.lua` (~6 lines), `highlights.lua` (2 groups)

---

## 2. Keystroke Crit Highlight

**Trigger:** Inside `vim.on_key` callback, when `register_key` returns a correct key.

**Effect:**
- Read cursor line: `api.nvim_win_get_cursor(play_win)[1] - 1`
- Apply `VimmerCrit` highlight on that line via `api.nvim_buf_add_highlight` using namespace `the-vimmer-crit`
- Clear after 120ms via `vim.defer_fn` + `api.nvim_buf_clear_namespace`

**New highlight group** (`highlights.lua`):
- `VimmerCrit` — bright gold background (e.g. `#5c4a00` bg, `#ffd700` fg)

**Files changed:** `ui.lua` (~8 lines), `highlights.lua` (1 group)

---

## 3. Combo Pop-up Text in HUD

**Location:** Inside `update_hud()` — replaces the plain `Combo x2` line.

**Threshold text:**

| Combo count | Text            | Highlight group    |
|-------------|-----------------|-------------------|
| 5–9         | `⚡ x2 COMBO!`  | `VimmerPhase` (existing) |
| 10–19       | `🔥 ON FIRE!`   | `VimmerComboFire` (new, orange) |
| 20+         | `💀 UNSTOPPABLE`| `VimmerComboCrit` (new, magenta/red) |
| < 5         | no combo line   | — |

**On combo break:** combo resets to 0 → text disappears on next `update_hud()` call (every keypress).

**New highlight groups** (`highlights.lua`):
- `VimmerComboFire` — orange fg (e.g. `#ff8c00`)
- `VimmerComboCrit` — magenta fg (e.g. `#ff00cc`)

**Files changed:** `ui.lua` (~10 lines in `update_hud`), `highlights.lua` (2 groups)

---

## 4. Multi-step Death / Win Animation

**New helper** in `ui.lua` (local, ~15 lines):

```lua
local function multi_flash(buf, steps, callback)
  -- steps: list of { group, duration_ms }
  -- chains vim.defer_fn calls, calls callback after last step
end
```

**Win sequence** (~600ms):
1. `VimmerWin` — 150ms
2. `VimmerCrit` — 150ms
3. `VimmerWin` — 150ms
4. → `on_win()`

**Death sequence** (~700ms):
1. `VimmerDamage` — 200ms
2. clear — 100ms (pass `nil` group to skip highlight, just delay)
3. `VimmerDeath` — 200ms
4. → `on_death()`

**Replaces:** The two existing `flash(play_buf, "VimmerWin/Death", callback)` call sites in `open_play`.

**Files changed:** `ui.lua` (~15 lines new helper + 2 call site changes)

---

## Summary of Changes

| File | Change |
|------|--------|
| `lua/the-vimmer/highlights.lua` | 5 new highlight groups: `VimmerDamage`, `VimmerRegen`, `VimmerCrit`, `VimmerComboFire`, `VimmerComboCrit` |
| `lua/the-vimmer/ui.lua` | `flash()` duration param, crit highlight in `on_key`, combo text in `update_hud()`, `multi_flash()` helper, updated win/death call sites |

No new files. No schema changes. No progress/game state changes.

---

## Out of Scope

- Sound effects
- Achievements / badges
- New rooms or tiers
- Challenge mode
