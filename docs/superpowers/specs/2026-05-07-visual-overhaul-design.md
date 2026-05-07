# The Vimmer — Visual Overhaul Design Spec

**Date:** 2026-05-07
**Goal:** Full visual overhaul — colors on all screens, animated win/death feedback, redesigned layouts. Vibrant game-like aesthetic.

---

## Overview

Layer a highlights system and screen redesigns onto the existing architecture. No game logic changes. Animation is a UI-only concern. All screens widen to 60 chars.

---

## Architecture

### New module: `lua/the-vimmer/highlights.lua`

Defines all highlight groups. Called once from `init.lua` on setup — groups persist for the session.

| Group | Color | Used for |
|---|---|---|
| `VimmerTitle` | bold white | Screen titles |
| `VimmerTierBeginner` | cyan | Beginner tier header |
| `VimmerTierWarrior` | yellow | Warrior tier header |
| `VimmerTierNinja` | magenta | Ninja tier header |
| `VimmerCleared` | green | Cleared room `✓` rows |
| `VimmerLocked` | grey (Comment) | Locked tier rows |
| `VimmerSelected` | bold + reverse | Currently selected map row |
| `VimmerXP` | gold/yellow | XP numbers and bar |
| `VimmerHP_high` | green | HP bar > 60 |
| `VimmerHP_mid` | yellow | HP bar 30–60 |
| `VimmerHP_low` | red | HP bar < 30 |
| `VimmerWin` | green bg | Full-buffer win flash |
| `VimmerDeath` | red bg | Full-buffer death flash + death screen title |
| `VimmerCommand` | bold yellow | Command key in teach screen |
| `VimmerExample` | cyan | Cursor `|` in before/after examples |

### `ui.lua` additions

- `apply_hl(buf, highlights)` — batches `nvim_buf_add_highlight` calls. Takes `{ {group, line, col_start, col_end}, … }`.
- `flash(buf, group, callback)` — applies full-buffer highlight, defers 100ms, clears it, calls callback.
- Every `open_*` function builds a highlight spec alongside its lines and calls `apply_hl` after `nvim_buf_set_lines`.

### `commands.lua` changes

- `on_death` no longer calls `vim.notify` — calls `ui.open_death(room, on_retry, on_map)` instead.
- `on_win` gains flash step before closing tab.

### `game.lua` — no changes.

---

## Screens

### Map screen (width 60)

Layout unchanged, width increased to 60. Highlights added:

- Title row `THE VIMMER` — `VimmerTitle`
- XP number and bar — `VimmerXP`
- `[BEGINNER]` — `VimmerTierBeginner`
- `[WARRIOR]` — `VimmerTierWarrior`
- `[NINJA]` — `VimmerTierNinja`
- Locked tier rows — `VimmerLocked`
- Cleared room rows — `VimmerCleared`
- Selected room row — `VimmerSelected` (updated on j/k movement)

### Teach screen (width 60)

- Command key (e.g. `w`, `ciw`) — `VimmerCommand` (bold yellow)
- Description text — `VimmerTitle` (white)
- BEFORE/AFTER label text — `VimmerLocked` (dim)
- Cursor `|` character positions in before/after — `VimmerExample` (cyan)

### Play screen

- Virtual text header above target buffer: `── TARGET ──` colored `VimmerCleared` (green)
- Virtual text header above play buffer: `── EDIT HERE ──` colored `VimmerTierWarrior` (blue/yellow)
- Statusline HP bar uses dynamic highlight group swapped in `update_hud()`:
  - `hp > 60` → `%#VimmerHP_high#`
  - `hp > 30` → `%#VimmerHP_mid#`
  - `hp <= 30` → `%#VimmerHP_low#`

### Results screen (width 60)

- `ROOM CLEARED!` title — `VimmerTitle` + `VimmerWin`
- XP earned number — `VimmerXP`
- Streak number — `VimmerTierWarrior` (yellow)
- Unlocked tier name — matching tier color group
- Lines revealed one-by-one via `vim.defer_fn` at 80ms intervals
- Keymaps (`<CR>` / `q`) activate only after last line reveals

### Death screen (width 40, new)

New `ui.open_death(room, on_retry, on_map)` function. Instant (no reveal animation — contrast with win).

```
╔══════════════════════════════════════╗
║           YOU DIED                   ║
╠══════════════════════════════════════╣
║  HP reached zero                     ║
║  Streak lost                         ║
╠══════════════════════════════════════╣
║  <Enter> retry   <q> map             ║
╚══════════════════════════════════════╝
```

- Title row — `VimmerDeath` (bold red)

---

## Animation flows

### Win

1. Buffer matches target
2. `flash(play_buf, "VimmerWin", callback)` — green wash 100ms
3. Tab closes
4. Results float opens with all lines blank
5. `vim.defer_fn` chain reveals each line at 80ms intervals
6. After last line: keymaps activate

### Death

1. HP reaches 0
2. `flash(play_buf, "VimmerDeath", callback)` — red wash 100ms
3. Tab closes
4. Death float opens instantly
5. `<Enter>` → retry room, `q` → map

### `flash(buf, group, callback)`

```
nvim_buf_add_highlight(buf, ns, group, 0, -1)  -- all lines
vim.defer_fn(function()
  nvim_buf_clear_namespace(buf, ns, 0, -1)
  callback()
end, 100)
```

---

## File changes summary

| File | Change |
|---|---|
| `lua/the-vimmer/highlights.lua` | **new** — all group definitions |
| `lua/the-vimmer/ui.lua` | add `apply_hl`, `flash`, `open_death`; update all `open_*`; widen to 60; add virtual text headers |
| `lua/the-vimmer/init.lua` | call `highlights.setup()` on plugin load |
| `lua/the-vimmer/commands.lua` | `on_death` → `ui.open_death`; `on_win` → flash before close |

---

## Out of scope

- Sound effects
- Persistent animation state across sessions
- Custom colorscheme themes / user config for colors
