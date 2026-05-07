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
    require("the-vimmer").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "mihyar-30614/the-vimmer",
  config = function()
    require("the-vimmer").setup()
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
require("the-vimmer").setup()
```

Or run directly from Neovim:

```vim
:set rtp+=/path/to/the_vimmer
:lua require("the-vimmer").setup()
```

## Commands

| Command | Description |
|---------|-------------|
| `:VimmerPlay` | Open room map, pick a room |
| `:VimmerPlay <room_id>` | Jump directly to a room (e.g. `beginner_hjkl`) |
| `:VimmerProgress` | Show XP, rooms cleared, and streak |
| `:VimmerReset` | Reset all progress |

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

Saved to `~/.local/share/nvim/the-vimmer/progress.json`. Reset with `:VimmerReset`.

## Development

Tests use [busted](https://lunarmodules.github.io/busted/). Game logic (XP, HP, state machine, room loader) is fully unit-tested without Neovim.

```bash
luarocks install busted --local
~/.luarocks/bin/busted tests/spec/
```
