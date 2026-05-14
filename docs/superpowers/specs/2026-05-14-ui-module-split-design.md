# UI Module Split (Sub-project 6b)

**Date:** 2026-05-14
**Sub-project:** 6b of 6 (deferred from polish bundle 6a)

## Problem

`lua/the-vimmer/ui.lua` is 1321 lines and holds nine public screen
functions plus a dozen helpers. The file mixes pure formatting helpers,
window/highlight primitives, and seven distinct full-screen renderers
(map, progress, teach, play, results, death, key-replay). Three concrete
costs:

1. The file is too large to hold in head or context window when editing
   one screen. Edits touch unrelated code and risk regressions.
2. Pure helpers (`build_optimal_lines`, `wrap_teach_text`,
   `fmt_run_seconds`, `xp_bar`, etc.) have no unit tests — they can only
   be exercised by manually opening a screen. Bugs ship.
3. Boundaries are implicit. A screen function reaches for any helper or
   namespace it likes; there is no contract distinguishing "shared
   utility" from "private to play screen".

## Goals

- Replace `ui.lua` with a `ui/` directory split into focused modules,
  each understandable in isolation.
- Preserve the public API exactly: `require("the-vimmer.ui").open_*`
  works unchanged for `commands.lua` and any future consumer. The
  underscore-prefixed `_show_phase_banner`, which is internal-by-convention
  and has no external callers (verified by grep), is removed from the
  facade and becomes module-local in `play.lua`.
- Make pure helpers unit-testable headlessly via busted.

## Non-goals

- No behavior changes. Pixel-identical output, identical callback
  contracts.
- No new screens or API additions.
- No widget framework, rendering DSL, or further extraction beyond pure
  helpers.
- No deprecation path. `ui.lua` is deleted in the same commit
  `ui/init.lua` lands.
- No tests for `vim`-touching helpers (`pick_float_width`, anything in
  `float.lua`).

## Design

### Module layout

```
lua/the-vimmer/ui/
├── init.lua          facade — requires submodules, re-exports M.* surface
├── common.lua        pure helpers (formatting, layout, text wrap)
├── float.lua         window primitives + namespaces + width constants
├── key_replay.lua    M.open_key_replay
├── map.lua           M.open_map
├── progress.lua      M.open_progress
├── teach.lua         M.open_teach
├── play.lua          M.open_play, M._close_play  (_show_phase_banner module-local)
├── results.lua       M.open_results
└── death.lua         M.open_death
```

`commands.lua` is unchanged. `require("the-vimmer.ui")` resolves to
`ui/init.lua` via Lua's package convention.

### Unit 1: `common.lua` (pure helpers)

Exports — all pure functions, no side effects on nvim state:

```lua
M.MUTATOR_TEACH                              -- table (mutator name → teach blurb)
M.pick_float_width(desired)                  -- reads vim.o.columns; clamp
M.format_key(k)
M.mutator_summary_line(names)
M.build_optimal_lines(room, inner_width)
M.pad_row(content, width)
M.wrap_teach_text(text, max_display_width)
M.add_wrapped_prefixed(add, row, prefix, text, box_width, hl_group)
M.make_border(width)
M.tier_room_bar(cleared, total, bar_len)
M.fmt_run_seconds(s)
M.streak_milestone_phrase(streak_after_win)
M.xp_bar(xp, bar_width)
```

`pick_float_width` reads `vim.o.columns` and so is not strictly pure;
it stays in `common` for cohesion but is not unit-tested.

### Unit 2: `float.lua` (window primitives)

Exports:

```lua
M.FLOAT_MAP_W       = 78
M.FLOAT_TEACH_W     = 86
M.FLOAT_RESULTS_W   = 78
M.FLOAT_DEATH_W     = 52
M.FLOAT_PROGRESS_W  = 74
M.flash_ns                                   -- shared "the-vimmer-flash" namespace
M.apply_hl(buf, highlights)
M.flash(buf, group, duration, callback)
M.multi_flash(buf, steps, callback)
M.open_float(lines, width)                   -- returns buf, win
```

`_flash_ns` is renamed to `flash_ns` (no underscore) on the module
surface; it remains a single namespace shared by `flash` and
`multi_flash`. Width constants live here because every screen reads
exactly one and they pair naturally with `open_float`.

### Unit 3: Screen modules

Each `ui/<screen>.lua` follows the same shape:

```lua
local M = {}
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
-- NOTE: do NOT top-level-require "the-vimmer.ui" — circular load.
-- For cross-screen calls (key_replay), use lazy require inside fn body.

function M.open_foo(...) ... end

return M
```

Mapping from current `ui.lua` line ranges:

| File              | Current lines | Public funcs                                   |
|-------------------|---------------|------------------------------------------------|
| `key_replay.lua`  | 293–355       | `open_key_replay`                              |
| `map.lua`         | 356–527       | `open_map`                                     |
| `progress.lua`    | 528–666       | `open_progress`                                |
| `teach.lua`       | 667–783       | `open_teach`                                   |
| `play.lua`        | 784–1080      | `open_play`, `_close_play` (also: `_show_phase_banner` becomes module-local) |
| `results.lua`     | 1081–1267     | `open_results`                                 |
| `death.lua`       | 1268–1321     | `open_death`                                   |

State currently held at module scope in `ui.lua` (`_play_ns`,
`_play_tab`, `_timer_handle`) moves to `play.lua` module scope. The
namespaces are read/written only by `open_play` and `_close_play`;
they stay private to `play.lua`.

### Unit 4: Cross-screen calls

Two cross-screen calls exist today:

- `teach.lua` end of flow calls `M.open_key_replay`
  (current `ui.lua:775`).
- `death.lua` "watch replay" branch calls `M.open_key_replay`
  (current `ui.lua:1312`).

Both go through the facade lazily:

```lua
function M.open_teach(room, flow_opts_or_cb, maybe_cb)
  ...
  require("the-vimmer.ui").open_key_replay(room, { phase_index = ... })
end
```

Lazy `require` inside the function body sidesteps the circular load
that would happen if a submodule top-level-required `the-vimmer.ui`
while init.lua is still in the middle of requiring submodules.

### Unit 5: `init.lua` facade

```lua
-- lua/the-vimmer/ui/init.lua
-- Facade for the ui submodules. Submodules MUST NOT top-level-require
-- this file; use `require("the-vimmer.ui")` inside function bodies for
-- cross-screen calls (circular load otherwise).
local M = {}

local function add(name)
  for k, v in pairs(require("the-vimmer.ui." .. name)) do
    M[k] = v
  end
end

add("key_replay")
add("map")
add("progress")
add("teach")
add("play")
add("results")
add("death")

return M
```

Each submodule exports its public funcs on its own `M`; the facade
flattens them onto the top-level `M`. `commands.lua` keeps using
`d.ui.open_map(...)` etc. unchanged.

### Tests

New: `tests/spec/ui_common_spec.lua`. Headless busted, no `vim`.

| Helper                       | Cases                                                            |
|------------------------------|------------------------------------------------------------------|
| `format_key`                 | special keys (`"<Esc>"`) passthrough; single chars               |
| `mutator_summary_line`       | empty input; single name; multi-name comma join                  |
| `build_optimal_lines`        | wraps inside given `inner_width`; no line exceeds width          |
| `pad_row`                    | pads short content; behavior for content longer than width       |
| `wrap_teach_text`            | word-boundary wrap; respects `max_display_width`                 |
| `make_border`                | output length matches `width`; corner characters present         |
| `tier_room_bar`              | `(0, N, W)` empty; `(N, N, W)` full; partial                     |
| `fmt_run_seconds`            | sub-minute; multi-minute formatting                              |
| `streak_milestone_phrase`    | known milestones return phrase; non-milestone returns `nil`      |
| `xp_bar`                     | proportional fill; zero and full edges                           |

Exact expected outputs are pinned by reading the current implementation
during the implementation phase — the spec is "match current behavior",
not "match what I think it does today".

Not tested: `pick_float_width` (`vim.o.columns`), `add_wrapped_prefixed`
(callback-driven; covered indirectly by `wrap_teach_text`), anything in
`float.lua` (requires nvim).

### Verification

- `busted` runs green: existing specs plus `ui_common_spec`.
- Headless `require("the-vimmer.ui")` and every `ui.<screen>` submodule
  loads without error (one-shot check during implementation, not a
  committed test).
- Manual smoke: open `:VimmerMap`, `:VimmerProgress`; play a room
  through teach → play → results paths; trigger death → replay; trigger
  boss phase banner.

### Edge cases

- **Circular require:** addressed by lazy `require("the-vimmer.ui")`
  inside function bodies for cross-screen calls. A comment at the top
  of `init.lua` documents the rule. Violating it causes silent missing
  function errors at call time.
- **`vim.loop.now()` / timer handles in play:** `_timer_handle` is
  reset by `_close_play`; moving both to `play.lua` keeps the
  lifecycle invariant intact.
- **Width constants on `float.lua`:** every screen calls `open_float`
  and so already needs `float`. Co-locating width constants there
  avoids `common` becoming a dumping ground.
- **Namespace clash with `the-vimmer.progress`:** `the-vimmer.ui.progress`
  resolves distinctly via Lua package paths. No runtime conflict;
  reader cost is the only cost and is acceptable.

## Open questions

None.
