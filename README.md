# the-vimmer

A room-based dungeon game that teaches Neovim shortcuts. Each room explains a command, shows before/after examples, then challenges you to use it for real. Progress saves between sessions.

## Rooms

| Tier | Rooms |
|------|-------|
| Beginner | hjkl, w, b, e, insert mode, delete/yank, undo/redo |
| Warrior | ciw/caw, f/t, search, %, visual mode, macros |
| Ninja | text objects, file motions, named registers, advanced macros |

Warrior unlocks at 80% beginner cleared. Ninja unlocks at 80% warrior cleared.

## Gameplay

Each room has three phases:

1. **Teach** — command name, description, before/after example, usage tip
2. **Play** — edit the bottom buffer to match the top target. HP starts at 100, drops 5 per non-optimal keystroke.
3. **Results** — XP earned (scales with HP remaining and streak), streak counter

Die (HP → 0): room restarts, streak resets.

## Requirements

- Neovim 0.8+

## Installation

### lazy.nvim

```lua
{
  "mihyar-30614/the-vimmer",
  config = function()
    require("the-vimmer").setup({
      colorblind = false, -- set true for a deuteranopia-safe palette
      -- Optional lifecycle hooks (payload tables documented below)
      hooks = {
        win = function(ev)
          -- ev: room_id, xp, streak, flawless, daily
        end,
        death = function(ev)
          -- ev: room_id, timed_out, mistakes
        end,
      },
    })
  end,
}
```

### packer.nvim

```lua
use {
  "mihyar-30614/the-vimmer",
  config = function()
    require("the-vimmer").setup({}) -- same options as lazy.nvim example above
  end,
}
```

### Manual (no plugin manager)

Clone into your Neovim packages directory:

```bash
git clone https://github.com/mihyar-30614/the-vimmer \
  ~/.local/share/nvim/site/pack/plugins/start/the-vimmer
```

### Local (from this directory)

Add to your `init.lua`:

```lua
vim.opt.rtp:prepend("/path/to/the_vimmer")
require("the-vimmer").setup({})
```

Or run directly from Neovim:

```vim
:set rtp+=/path/to/the_vimmer
:lua require("the-vimmer").setup({})
```

## Commands

| Command | Description |
|---------|-------------|
| `:VimmerPlay` | Open room map, pick a room |
| `:VimmerPlay <room_id>` | Jump directly to a room (e.g. `beginner_hjkl`) |
| `:VimmerPick` | Fuzzy-pick a room (requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)) |
| `:VimmerDaily` | Today’s seeded challenge + optional random unlocked mutator |
| `:VimmerProgress` | Floating panel: XP, streak, tiers, suggested drill, mutators |
| `:VimmerReset` | Reset all progress |

### Mutators

Lifetime XP unlocks mutators used by `:VimmerDaily` (and extensible via `start_flow`):

| ID | Unlock (total XP) | Effect |
|----|-------------------|--------|
| `iron` | 120 | No +2 HP on every 3rd correct key |
| `glass` | 280 | Wrong keys cost −8 HP instead of −5 |
| `rush` | 480 | Timer loses 2 seconds per tick |

### Extra room packs

Add validated room Lua files under **`the-vimmer/rooms/<tier>/`** (for example `the-vimmer/rooms/warrior/foo.lua`) anywhere on **`runtimepath`**. They load after the built-in pack; duplicate room `id`s are skipped with a warning.

### Setup hooks

```lua
require("the-vimmer").setup({
  hooks = {
    win = function(ev) end,   -- room_id, xp, streak, flawless, daily
    death = function(ev) end,   -- room_id, timed_out, mistakes
  },
})
```

## Room IDs

```
beginner_hjkl       beginner_w_motion     beginner_b_motion
beginner_e_motion   beginner_insert_mode  beginner_delete_yank
beginner_undo_redo

warrior_ciw         warrior_f_motion      warrior_search
warrior_percent     warrior_visual        warrior_macros

ninja_text_objects  ninja_complex_motions ninja_registers
ninja_advanced_macros
```

## Progress

Saved to `~/.local/share/nvim/the-vimmer/progress.json` (XP, clears, streak, personal-best times per room, skill stats per room, daily stamp, unlocked mutators). Reset with `:VimmerReset`.

## Development

Tests use [busted](https://lunarmodules.github.io/busted/). Game logic (XP, HP, state machine, room loader) is fully unit-tested without Neovim.

```bash
luarocks install busted --local
~/.luarocks/bin/busted tests/spec/
```

### Reachability harness

For rooms with a `goal` field set, a separate harness verifies that the
declared `optimal_keystrokes` (and each alternate) actually transform
`start_text` into `target_text`. It runs inside headless nvim:

```bash
nvim --headless --noplugin -l tests/reachability.lua
```

Exit code 0 = all checked sequences pass. Non-zero with per-room diagnostics
on stderr if any sequence fails. Rooms without `goal` are skipped (legacy
fragment-style `optimal_keystrokes`). Pass `--all` to force-check every room.
