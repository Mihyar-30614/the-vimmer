# Fold map groups — design

## Goal

Let the player collapse/expand tier groups on the world map so the screen stays
focused on what they care about. Pressing `za` folds the tier under the cursor;
folded tiers hide their rooms behind a single header line.

## Scope

- File: `lua/the-vimmer/ui/map.lua` only. Game logic, progress, and other UI
  screens are untouched.
- Session-only fold state. No changes to the saved progress data.

## Behavior

### Keys (map screen)

| Key      | Action                                                            |
|----------|-------------------------------------------------------------------|
| `j` / `k`| Move selection over nav items (headers + rooms + quick-play).      |
| `za`     | Toggle fold of the tier the current item belongs to.              |
| `zM`     | Fold all unlocked tiers.                                           |
| `zR`     | Expand all tiers.                                                  |
| `<CR>`   | On a tier header: toggle its fold. On a room/boss: play it.       |
| `q`/`<Esc>` | Close map (unchanged).                                          |

### Selection model

Replace the current `selectable` list (which held only uncleared rooms +
unlocked bosses) with a uniform `nav` list. Every actionable row is a nav item,
tagged by `kind`:

- `tier` — an **unlocked** tier header. Foldable. `<CR>`/`za` toggle fold.
- `room` — any room, **cleared or not**. Carries its parent `tier` id.
  `<CR>` plays it (replay allowed for cleared rooms).
- `quick` — the quick-play weak-room entry. Standalone, not tied to a tier,
  not foldable.

Locked tier headers remain non-navigable (nothing to fold, no playable rooms);
they render exactly as today.

A folded tier contributes **only** its `tier` item to `nav`. An expanded tier
contributes its `tier` item followed by all its `room` items (cleared,
uncleared, and boss).

### Fold state

- Local table `folds = { beginner=bool, warrior=bool, ninja=bool, grandmaster=bool }`,
  created when the map opens. Not persisted.
- Initial value per unlocked tier: **folded if fully cleared** (every regular
  room cleared AND the boss cleared, when a boss exists), otherwise expanded.
- Locked tiers have no fold entry (not foldable).

### Visual

- Expanded tier header: prefix `▾`, same content as today (roman · label,
  progress bar, boss hint).
- Folded tier header: prefix `▸`, same right-side progress bar/hint so the
  player still sees completion at a glance; rooms below are omitted.
- The fold marker replaces nothing material — it's prepended to the existing
  header row. Use plain `▸`/`▾` glyphs (consistent with the existing icon set
  approach; no new icon registry entries required unless one already fits).

## Architecture

`open_map` today builds `lines`/`hls`/`selectable` in a single inline pass and
opens a static float sized to the line count. Split that into:

1. **`build_view(folds, progress_data, rooms_by_tier, width)`** — pure function
   returning `{ lines, hls, nav }`. Contains all the current line-building logic
   (header, HUD, quick play, per-tier loop), now consulting `folds[tier]` to
   decide whether to emit room rows, and pushing nav items instead of the old
   `selectable` entries. No side effects, no buffer access.

2. **`render()`** — closure over `buf`, `win`, and current state. Calls
   `build_view`, rewrites buffer lines (toggling `modifiable`), **resizes and
   recenters** the float window (line count changes on fold via
   `nvim_win_set_config` with new `height`/`row`/`col`), re-applies static
   highlights, then restores selection.

3. **Selection restore across re-render** — `render()` takes an optional target
   (e.g. the tier id or nav item to land on). After a fold toggle, keep the
   cursor on the same tier's header so the view doesn't jump. Clamp `cur_idx`
   to `#nav`.

The existing `update_selection`/`write_menu_row` highlight logic is reused;
it must now also highlight a selected `tier` header row (full-line
`VimmerSelected`), not just menu rows.

## Window resize detail

`float.open_float` sizes height to `#lines` and centers once. Folding changes
`#lines`, so `render()` recomputes:

```
height = #lines
row = max(0, floor((vim.o.lines - height) / 2))
col = max(0, floor((vim.o.columns - width) / 2))
nvim_win_set_config(win, { relative="editor", row=row, col=col,
                           width=width, height=height })
```

Width is fixed (already chosen at open), so it carries through unchanged.

## Edge cases

- **Empty nav** (no unlocked tiers, no quick play): keep the existing
  `#selectable == 0` guards — j/k/`<CR>`/`za` no-op.
- **Fold a tier whose only nav presence is the header** (already folded):
  `za` expands it. `zR`/`zM` operate on all unlocked tiers regardless of cursor.
- **Cursor on a `quick` item when `za` pressed**: no parent tier → no-op.
- **All tiers folded then `j`/`k`**: moves over the header nav items only.

## Testing

- Game logic, progress, and room loading are unchanged → existing busted suite
  (`tests/spec/`) must stay green. Run `~/.luarocks/bin/busted tests/spec/`.
- Map UI is not unit-tested (requires a live Neovim UI). Manual verification:
  1. Open map with a fully-cleared beginner tier → it starts folded (`▸`),
     rooms hidden, progress bar still shown.
  2. `j`/`k` onto the folded header, `za` → expands (`▾`), rooms appear, window
     recenters.
  3. `za` again → collapses; cursor stays on the header.
  4. Navigate to a cleared room, `<CR>` → it replays.
  5. `zM` folds every unlocked tier; `zR` expands all.
  6. Locked tiers unaffected (no fold marker, not selectable).

## Out of scope

- Persisting fold state across sessions.
- Folding the quick-play or HUD sections.
- Per-room folding.
