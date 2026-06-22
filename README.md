# the-vimmer

A room-based dungeon game that teaches Neovim shortcuts. Each room explains a command, shows before/after examples, then challenges you to use it for real. Progress saves between sessions.

## Rooms

| Tier | Rooms |
|------|-------|
| Beginner | hjkl, w, b, e, insert mode, delete/yank, undo/redo |
| Warrior | ciw/caw, f/t, search, %, visual mode, macros |
| Ninja | text objects, file motions, named registers, advanced macros |
| Grandmaster | substitute captures, & whole-match, :g/normal, :g/move, :t copy, :m move, :%! filter, range :norm, & repeat, folds |

Each tier's boss unlocks once 80% of that tier's regular rooms are cleared.
Beating a tier's boss unlocks the next tier (warrior after the beginner boss,
ninja after the warrior boss, grandmaster after the ninja boss).

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
      theme = "dracula",  -- "dracula" (default) | "auto" (match your colorscheme)
                          -- | a table of role->hex overrides, e.g.
                          -- { xp = "#f1fa8c", boss = "#ff79c6", hp_low = "#ff5555" }
      border = "sharp",   -- "sharp" (default) | "rounded" (╭╮ arc corners on floats)
      icons = "unicode",  -- "unicode" (default) | "ascii" (plain icon fallback)
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
| `:VimmerDrill` | Play your 3 weakest rooms back-to-back (by keystroke waste) |
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

## Adding rooms

A room is a Lua file that `return`s a single table. Drop it in
`lua/rooms/<tier>/<name>.lua` (built-in) or, for an external pack, anywhere on
`runtimepath` under `the-vimmer/rooms/<tier>/<name>.lua`. `<tier>` is one of
`beginner`, `warrior`, `ninja`. Files load at startup; invalid rooms are skipped
with a warning, duplicate `id`s are dropped.

### Standard room

```lua
-- lua/rooms/warrior/swap_args.lua
return {
  id = "warrior_swap_args",        -- unique; convention: <tier>_<name>
  tier = "warrior",                -- must match the directory tier
  command = "dt, p",               -- short label shown in the map
  title = "Swap Two Args",
  description = "dt deletes up to a char. p pastes after the cursor.",
  before_example = "foo(|a, b)",   -- | marks the cursor in the teach card
  after_example = "foo(|b, a)",
  usage_tip = "Delete the first arg, jump past the second, paste it back.",
  start_text = [[foo(a, b)]],      -- buffer the player starts with
  target_text = [[foo(b, a)]],     -- buffer they must produce
  base_xp = 90,                    -- XP before HP/streak scaling
  optimal_keystrokes = { "d", "t", ",", "f", ")", "p" },
}
```

`optimal_keystrokes` is the keystroke-by-keystroke ideal solution. Encode
special keys as Lua escapes: `"\27"` = `<Esc>`, `"\22"` = `<C-v>`. Multi-char
commands are split per key (`ciw` → `{ "c", "i", "w" }`). The list both scores
the player (deviation costs HP) and is checked by the reachability harness.

### Required fields

| Field | Meaning |
|-------|---------|
| `id` | Unique room id; scanned across all tiers |
| `tier` | `beginner` / `warrior` / `ninja`; must match the folder |
| `command` | Short command label for the map/teach card |
| `title` | Room title |
| `description` | What the command does (teach phase) |
| `before_example` / `after_example` | Inline demo, `|` marks the cursor |
| `usage_tip` | One-line "how to apply" hint |
| `start_text` | Starting buffer contents (`[[ ... ]]` for multi-line) |
| `target_text` | Buffer the player must produce |
| `base_xp` | XP awarded before HP/streak scaling |
| `optimal_keystrokes` | Ideal solution as a per-key string list |

### Optional fields

| Field | Default | Effect |
|-------|---------|--------|
| `optimal_keystrokes_alternates` | `nil` | List of alternate solutions, each a key list. Player matching any one is optimal. |
| `goal` | `nil` | Explicit objective string. **Set this to opt into the reachability harness** (verifies every sequence turns `start_text` into `target_text`). |
| `filetype` | `""` | Buffer `filetype` for both panes (syntax highlight). |
| `cursor_start` | `{ row=1, col=1 }` | 1-based cursor position in the play buffer. |
| `time_limit` | `nil` | Seconds before death; `nil` = untimed. |
| `bo` | `nil` | Buffer-option overrides applied to the play buffer, e.g. `{ shiftwidth = 2, expandtab = true }`. |
| `efficiency_hint` | `nil` | One-line tip shown on the results screen when the player used more keys than the most efficient accepted path. Omit it and a generic fallback line is shown instead. |

### Boss rooms

Set `is_boss = true` and replace `start_text` / `target_text` /
`optimal_keystrokes` with a `phases` list. Each phase is its own mini-room and
may carry the optional fields above. Required at the top level: `id`, `tier`,
`command`, `title`, `description`, `usage_tip`, `base_xp`, `phases`,
`time_limit`. Each phase needs `start_text`, `target_text`, `optimal_keystrokes`.

```lua
return {
  id = "warrior_boss", tier = "warrior", is_boss = true,
  command = "search + visual block + macros",
  title = "BOSS: The Siege",
  description = "Three-phase trial.",
  usage_tip = "Chain * + cgn, then <C-v> + I, then qa ... q + @a.",
  base_xp = 500, time_limit = 240,
  phases = {
    {
      tip = "Phase 1: Rename `tmp` everywhere",
      goal = "Rename all 3 occurrences of `tmp` to `out`.",
      filetype = "lua",
      cursor_start = { row = 1, col = 7 },
      start_text = [[local tmp = compute()]],
      target_text = [[local out = compute()]],
      optimal_keystrokes = { "*", "N", "c", "g", "n", "o", "u", "t", "\27" },
    },
    -- ... more phases
  },
}
```

### Verify a new room

```bash
~/.luarocks/bin/busted tests/spec/                 # loader/validator
nvim --headless --noplugin -l tests/reachability.lua  # if `goal` is set
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
