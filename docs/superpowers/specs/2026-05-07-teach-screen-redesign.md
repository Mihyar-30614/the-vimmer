# Teach Screen Redesign

**Date:** 2026-05-07
**Approach:** Option A — cleaner single screen with better visual hierarchy and arrow diff

---

## Overview

Redesign `open_teach()` in `ui.lua` to reduce visual density. Same float window, same keybinds. Three changes: wider layout (70 chars), distinct visual weight per zone, arrow diff format for before/after.

---

## Section 1: Layout & Visual Hierarchy

**Width:** 60 → 70 chars (`local width = 70`).

**Three zones, each separated by `╠═╣` borders:**

| Zone | Content | Highlight group |
|------|---------|----------------|
| Command | Command name | `VimmerCommand` (bold yellow, existing) |
| Command | Description | `VimmerTitle` (white bold, existing) |
| Example | Arrow diff line(s) | See Section 2 |
| Tip | Usage tip text | `VimmerLocked` (muted `#6272a4`, existing) |

No new highlight groups needed.

**New structure (normal room):**
```
╔══════════════════════════════════════════════════════════════════════╗
║  h / j / k / l                                                       ║  ← VimmerCommand
║  Move cursor left (h), down (j), up (k), right (l)                  ║  ← VimmerTitle
╠══════════════════════════════════════════════════════════════════════╣
║  ▌hello world  →  hell▌o world                                       ║  ← arrow diff
╠══════════════════════════════════════════════════════════════════════╣
║  Stay on home row. Never reach for arrow keys again.                ║  ← VimmerLocked
╠══════════════════════════════════════════════════════════════════════╣
║  <Enter> to begin   <q> back                                         ║
╚══════════════════════════════════════════════════════════════════════╝
```

**Only `open_teach()` in `ui.lua` changes.** Width constant, line-building logic, and highlight application updated.

---

## Section 2: Arrow Diff Format

Replace `BEFORE: |text` / `AFTER: |text` with a single combined line:

```
  ▌hello world  →  hell▌o world
```

**Rules:**
- `|` cursor marker in room data → replaced with `▌` (U+258C, left half block) in display
- `▌` highlighted with `VimmerCrit` (gold, existing)
- `→` highlighted with `VimmerXP` (yellow, existing)
- Remaining text: default color, using per-character `nvim_buf_add_highlight` spans

**Long line handling:** If combined diff string exceeds 66 chars (width 70 minus 4 for padding), split to two lines:
```
  ▌some very long before text
  →  some very long after▌ text
```

**Boss rooms:** Same arrow diff format applied per-phase, replacing the current `BEFORE:` / `AFTER:` label lines inside each phase block.

---

## Implementation Scope

**File changed:** `lua/the-vimmer/ui.lua` — `open_teach()` function only

**What does NOT change:**
- `open_play()`, `open_map()`, `open_results()`, `open_death()`
- Room data files (still use `|` for cursor position)
- Highlight group definitions (all reused from existing set)
- Keybinds (`<Enter>` / `<q>`)
- Float window mechanism

**Highlight application:** Arrow diff line requires character-level highlights (not whole-line). Use `nvim_buf_add_highlight` with byte offsets for `▌` chars and `→` char. Both are multi-byte: `▌` is 3 bytes (UTF-8: `\xe2\x96\x8c`), `→` is 3 bytes (UTF-8: `\xe2\x86\x92`). Offsets must be byte-based, not character-based.

---

## Out of Scope

- Keystroke hint display ("press `w` then `b`")
- Re-reading teach screen mid-play
- Animated/stepped reveal
- Teach screen for boss phases beyond the existing phase list format
