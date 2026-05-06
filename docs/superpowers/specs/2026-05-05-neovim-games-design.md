# The Vimmer — Design Spec

**Date:** 2026-05-05  
**Type:** Neovim Lua plugin  
**Goal:** Teach Neovim shortcuts through a room-based dungeon game, covering beginner to ninja skill levels.

---

## Overview

A Neovim plugin where each "room" teaches one command then immediately tests it on real text. Players earn XP, clear tiers, and unlock harder rooms as they progress.

---

## Architecture

```
the-vimmer/
├── lua/
│   ├── the-vimmer/
│   │   ├── init.lua          -- entry point, setup()
│   │   ├── ui.lua            -- floating windows, HUD
│   │   ├── game.lua          -- game loop, state machine
│   │   ├── rooms.lua         -- room definitions + loader
│   │   ├── progress.lua      -- save/load XP, unlocks
│   │   └── commands.lua      -- keymaps, :VimmerPlay etc.
│   └── rooms/
│       ├── beginner/         -- tier 1 room files
│       ├── warrior/          -- tier 2 room files
│       └── ninja/            -- tier 3 room files
├── plugin/
│   └── the-vimmer.lua        -- auto-load
└── data/
    └── progress.json         -- saved via stdpath("data")
```

- Pure Lua, no external dependencies
- Neovim floating windows for all UI
- Rooms defined as individual `.lua` files — easy to extend

---

## Game Loop

**State machine:** `idle → teaching → playing → results → idle`

### Phase 1: Teach
Floating window displays:
- Command name and keystroke
- What it does and when to use it
- Before/after text example showing the command in action
- Press `<Enter>` to start the game

### Phase 2: Play
Real Neovim buffer with actual editing:
- Top split: target state (readonly) — what the text should look like
- Bottom split: current state — what the player edits
- HUD statusline: HP, streak, current command hint
- No key blocking — Vim stays Vim; wrong approach drains HP
- Text matches target = room cleared

### Phase 3: Results
Score screen showing:
- XP earned, streak bonus, accuracy
- Unlock message if new room or tier unlocked
- `<Enter>` → next room or map

---

## HP System

- Start at 100 HP per room
- Plugin logs keystrokes during play; each keystroke not in the room's `optimal_keystrokes` list drains 5 HP
- Reach 0 HP = retry room
- Win with HP remaining = bonus XP multiplier

---

## Progression

### Tiers

| Tier | Name     | Unlock Requirement       | Topics Covered |
|------|----------|--------------------------|----------------|
| 1    | Beginner | Always open              | hjkl, w/b/e, i/a/o, x/dd/yy/p, u/Ctrl-r |
| 2    | Warrior  | 80% of Beginner cleared  | ciw/caw, f/t, /, %, visual mode, macros intro |
| 3    | Ninja    | 80% of Warrior cleared   | text objects, complex motions, registers, advanced macros |

### XP Formula

```
room_xp = base_xp + (remaining_hp / 100 * base_xp) + streak_bonus
streak_bonus = (streak >= 3) ? room_xp * 0.5 : 0
```

### Persistence

- Saved to `~/.local/share/nvim/the-vimmer/progress.json`
- Tracks: total XP, rooms cleared, HP remaining per room, current streak
- `:VimmerReset` wipes all progress

---

## Commands

| Command | Action |
|---------|--------|
| `:VimmerPlay` | Open map screen, pick a room |
| `:VimmerPlay <room_id>` | Jump directly to a room |
| `:VimmerProgress` | Show XP and level summary |
| `:VimmerReset` | Wipe all saved progress |

---

## UI

### Map Screen
```
╔══════════════════════════════════════╗
║  THE VIMMER          XP: 340 ▓▓▓░░  ║
╠══════════════════════════════════════╣
║  [BEGINNER]                          ║
║   ✓ hjkl basics        ★★★          ║
║   ✓ word motions        ★★☆          ║
║   ► insert mode         [NEXT]       ║
║   ○ delete & yank       [LOCKED]     ║
║                                      ║
║  [WARRIOR]  🔒 complete 80% above   ║
║  [NINJA]    🔒                       ║
╠══════════════════════════════════════╣
║  <Enter> play  <q> quit              ║
╚══════════════════════════════════════╝
```

### Teach Screen
```
╔══════════════════════════════════════╗
║  COMMAND: w                          ║
║  Move to start of next word          ║
╠══════════════════════════════════════╣
║  BEFORE:  |The quick brown fox       ║
║  AFTER:   The |quick brown fox       ║
║                                      ║
║  Use it when: jumping word by word   ║
║  forward without arrow keys          ║
╠══════════════════════════════════════╣
║  <Enter> to begin                    ║
╚══════════════════════════════════════╝
```

### Play Screen
Split buffer layout:
- Top: target text (readonly)
- Bottom: editable buffer
- Statusline HUD: HP bar + streak counter + hint

---

## Room File Format

Each room is a Lua file returning a table:

```lua
return {
  id = "beginner_w_motion",
  tier = "beginner",
  command = "w",
  title = "Word Motion: w",
  description = "Move to the start of the next word",
  before_example = "|The quick brown fox",
  after_example = "The |quick brown fox",
  usage_tip = "Jump word by word forward without arrow keys",
  start_text = "fix|this sentence word by word",
  target_text = "fix this sentence |word by word",
  base_xp = 50,
  optimal_keystrokes = { "w", "w", "w" },
}
```

---

## Error Handling

- Invalid progress file: reset to defaults silently, log warning
- Buffer creation failure: show error notification, exit game cleanly
- Missing room file: skip room, log warning, show "coming soon" on map

---

## Testing

- Unit tests for XP calculation, unlock logic, progress save/load
- Room definition validator: ensure all required fields present
- Manual playtest each tier before release
