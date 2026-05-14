# Real-World Rooms Redesign

**Date:** 2026-05-14
**Status:** Approved design — implementation pending

## Problem

Current rooms drill one Vim command each on tiny synthetic text (`"banana\napple\ncherry"`, `"the wrong word here"`). Two failure modes:

1. **No transfer to real work.** Players learn `ciw` on toy strings, then freeze on real code where they must also *find* the right word and *decide* `ciw` is the right tool.
2. **Drill-only rooms are dead pedagogy.** A whole room to press `w` once teaches nothing about when/why to reach for `w`.

Goal: every room becomes a realistic mini-task where the featured command is the right tool, in a real-feeling code snippet.

## Non-Goals

- New tier above ninja. Existing beginner → warrior → ninja progression maps cleanly to skill level; only content shape changes.
- New room formats beyond what current engine supports. `start_text` / `target_text` / `optimal_keystrokes` / `optimal_keystrokes_alternates` already cover scenarios.
- Multi-language curation from real OSS projects (licensing + isolation overhead). Use invented-but-realistic snippets.
- Changing XP curve, mutators, power-ups, or progression mechanics.

## Design

### Schema additions

Three new optional fields on the room table (and per-phase on boss rooms):

```lua
filetype = "typescript",                -- enables syntax highlighting in scratch buffer
cursor_start = { row = 4, col = 12 },   -- 1-indexed; defaults to {1,1}
goal = "Rename `userId` to `accountId` everywhere in this function",
```

Existing fields unchanged: `id`, `tier`, `command`, `title`, `description`, `usage_tip`, `start_text`, `target_text`, `base_xp`, `time_limit`, `optimal_keystrokes`, `optimal_keystrokes_alternates`, `bo`. Boss rooms keep `phases` / `is_boss`.

Validator (`lua/the-vimmer/rooms.lua` `M.validate`) extended to type-check the three new fields when present:
- `filetype` is a string
- `cursor_start` is a table with integer `row` and `col`, both ≥ 1
- `goal` is a string

All three are optional. Missing fields use defaults:
- `filetype` defaults to no syntax (current behavior)
- `cursor_start` defaults to `{ row = 1, col = 1 }`
- `goal` defaults to absent; UI suppresses the line

### Why each field

- **`filetype`** — real code is unreadable without syntax colors. Beginner sees Lua keywords highlighted, instantly less alien.
- **`cursor_start`** — in a 20-line snippet, cursor on line 1 col 1 wastes player time on navigation that isn't what the room teaches. Explicit start cursor frames the task.
- **`goal`** — `description` teaches the command; `goal` describes the task. Player needs both. Compare "ciw changes inner word" (description) vs "Fix the param name on line 7" (goal).

### Room blueprint

Sample warrior room teaching `ciw` (illustrates the format, not a finalized room):

```lua
return {
  id = "warrior_ciw",
  tier = "warrior",
  command = "ciw",
  title = "Rename Param: ciw",
  description = "ciw deletes word under cursor and enters insert mode. No manual selecting.",
  filetype = "typescript",
  goal = "Rename param `userId` to `accountId` (3 occurrences).",
  cursor_start = { row = 3, col = 17 },
  usage_tip = "ciw works anywhere on the word. Pair with n to jump to next match, then . to repeat.",
  start_text = [[
export function fetchUser(userId: string) {
  const cache = userCache.get(userId);
  if (!cache) return loadUser(userId);
  return cache;
}
]],
  target_text = [[
export function fetchUser(accountId: string) {
  const cache = userCache.get(accountId);
  if (!cache) return loadUser(accountId);
  return cache;
}
]],
  base_xp = 80,
  time_limit = 45,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "a", "c", "c", "o", "u", "n", "t", "I", "d", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "c", "i", "w", "a", "c", "c", "o", "u", "n", "t", "I", "d", "\27", "n", ".", "n", "." },
  },
}
```

Key shifts from old format:
- `start_text` is a real function, not `"the wrong word here"`
- `goal` tells the player what to accomplish; `description` teaches the command
- `cursor_start` lands the player on the first `userId` — no wasted navigation
- `optimal_keystrokes_alternates` covers multiple legitimate paths (cgn vs ciw+n+.)
- The room is titled `ciw` but optimal uses `cgn` — because that's the better tool for "3 occurrences of the same word". This is the real-world insight worth teaching.

### Tier calibration

**Beginner (~21 rooms):** 5–10 line snippets, single command focus, target requires 3–6 reps of the command.
- Snippet shape: small config, dict, simple function, short list
- Example goals: "Fix 3 typos with x", "Delete each broken `console.log` line", "Replace 4 chars with ~"
- `optimal_keystrokes` length: 8–20
- `time_limit`: usually `nil` or 60s
- `base_xp` range: 30–60

**Warrior (~19 rooms):** 10–20 line snippets, 1–2 commands chained, single real task.
- Snippet shape: full small function, test case, struct, switch block
- Example goals: "Comment out failing test", "Extract these 3 lines", "Indent block under new if"
- `optimal_keystrokes` length: 15–40
- `time_limit`: 45–90s
- `base_xp` range: 70–110

**Ninja (~17 rooms):** 20–40 line snippets, multi-command refactor, multiple valid paths emphasized.
- Snippet shape: small module, React component, struct + methods, SQL migration
- Example goals: "Rename type across file", "Sort imports", "Wrap each TODO in quotes", "Apply this transform to all 6 functions"
- `optimal_keystrokes` length: 25–80
- `time_limit`: 60–180s
- `base_xp` range: 120–180
- Heavy use of `optimal_keystrokes_alternates` — real refactors have 3–5 reasonable paths

**Bosses** keep their multi-phase format. Each phase is a tier-appropriate scenario with its own `filetype`, `cursor_start`, `goal`. `base_xp` range: 400–600.

### Coverage map

One room per existing ID. Replace content, preserve structure. No room added, no room removed, no room merged. Total: **57 rooms** (21 beginner + 19 warrior + 17 ninja).

This keeps:
- Player save data / progress (keyed by room ID) intact
- Telescope picker UX identical
- XP curve roughly stable

Files rewritten in place:

| Tier     | Rooms |
|----------|-------|
| Beginner | hjkl, hjkl2, w_motion, b_motion, e_motion, word_hop, line_boundaries, file_boundaries, insert_mode, insert2, delete_char, delete_motion, delete_yank, dd_yp, d_dollar, replace_char, toggle_case, undo_redo, join_lines, counts, boss |
| Warrior  | ciw, ci_combo, change_chain, case_ops, indent, scroll, viewport, search, star_search, f_motion, ft_chain, delete_to, percent_motion, goto_line, n_repeat, macros_intro, visual_mode, visual_block, boss |
| Ninja    | text_objects, surround_obj, registers, registers2, black_hole, marks, jump_list, inc_dec, substitute, global_delete, sort, norm_range, cgn, complex_motions, global_macro, advanced_macros, boss |

For each room, kept verbatim: `id`, `tier`. Kept or lightly tuned: `command`, `title`, `description`, `usage_tip`, `base_xp`. Fully rewritten: `start_text`, `target_text`, `optimal_keystrokes`, `optimal_keystrokes_alternates`. Added: `filetype`, `cursor_start`, `goal`, `time_limit` (where missing).

### UI changes

Small, scoped:

1. **Play screen** renders `goal` below `title` when present. Falls back to existing layout when absent.
2. **Scratch buffer** sets `vim.bo[buf].filetype = room.filetype` after populating `start_text`, when `filetype` is present.
3. **Cursor placement** moves to `room.cursor_start` after buffer populated; defaults to `{1, 1}`.

No teach-screen changes. `description` + `usage_tip` continue to teach the command on the teach screen.

### Buffer hygiene

Room buffer should isolate from the player's broader nvim config to prevent autopairs / LSP / snippets from making rooms unbeatable. Already set: `bo` overrides per room. Extend:

- `buftype=nofile` (prevent accidental writes)
- `bufhidden=wipe`
- Disable autopairs / completion via buffer-local flags (`b:minipairs_disable=1`, `b:copilot_enabled=0`, etc. as community plugins respect them)
- LSP: detach LSP clients on the room buffer

This applies to all rooms regardless of new schema fields, but is more important now that real `filetype` triggers plugin behavior.

## Testing

Three layers:

1. **Schema validator tests** (extend `tests/spec/rooms_spec.lua`):
   - `filetype` must be string when present
   - `cursor_start` must be `{row=int>=1, col=int>=1}` when present
   - `goal` must be string when present
   - All three optional; rooms without them still validate

2. **Per-room reachability test** (new harness):
   - Spin up headless nvim buffer with `start_text` and `bo` overrides
   - Place cursor at `cursor_start` (or `{1,1}`)
   - Feed `optimal_keystrokes` via `nvim_feedkeys` with `'nx'` mode (no remapping, execute now)
   - Assert resulting buffer text equals `target_text` (line-by-line, trailing newline normalized)
   - Repeat for each `optimal_keystrokes_alternates` entry

   Catches: typos in keystroke sequences, off-by-one cursor starts, wrong escape encoding, sequences that work in author's head but not in nvim.

   CI-blocking. Run on every PR.

3. **Existing tests** (untouched): room loading from filesystem, dedup, runtime-path scanning. These continue to pass because schema additions are optional.

## Rollout

Five PRs, in order. Each independently shippable.

| PR | Scope |
|----|-------|
| 1 | Schema additions: validator, defaults, UI rendering of `goal`/`filetype`/`cursor_start`, reachability harness, buffer hygiene. No room changes. All existing rooms continue to load and pass tests. |
| 2 | Beginner rewrite: 21 rooms. Each room gets new `start_text`/`target_text`/`optimal_keystrokes`/`optimal_keystrokes_alternates`, plus `filetype`/`cursor_start`/`goal`. Reachability tests added per room. |
| 3 | Warrior rewrite: 19 rooms, same shape as PR 2. |
| 4 | Ninja rewrite: 17 rooms, same shape as PR 2. |
| 5 | XP / `time_limit` tuning pass: playtest each tier end-to-end, adjust budgets and time limits where calibration is off. |

Schema additions in PR 1 are backward-compatible: new fields are optional, so old rooms keep loading. Each subsequent PR can land independently without breaking earlier tiers.

## Risks and mitigations

- **Reachability bugs.** Hand-written keystroke sequences are easy to get wrong — typos, missed Escapes, wrong-mode chains. *Mitigation:* reachability harness is mandatory; CI blocks merge of any room whose primary sequence or alternates don't reach `target_text` from `start_text`.

- **Difficulty drift.** Real code is harder than toy text. Players may struggle on rooms they previously cleared. *Mitigation:* IDs and progress data carry over so re-clearing isn't catastrophic; PR 5 tunes `time_limit` and `base_xp` generously after playtest.

- **Snippet authenticity vs command isolation.** Too-real code can distract from the command being taught. *Mitigation:* every room is reviewed against the question "does cursor start + goal isolate this command as the obviously right tool?" before commit. If a snippet teaches three commands at once, it's the wrong snippet for this room.

- **Filetype triggers user plugins.** Setting `filetype = "typescript"` activates LSP, autopairs, snippets, etc. on the room buffer, potentially breaking the keystroke sequence. *Mitigation:* buffer hygiene work in PR 1 — `buftype=nofile`, detach LSP, set buffer-local disable flags for common plugins.

- **Boss room phases need same schema treatment.** Easy to forget when extending the validator. *Mitigation:* validator covers `BOSS_REQUIRED` plus per-phase optional fields; phase-level tests in the reachability harness.

## Plan decomposition

This spec covers all five PRs but is too large for a single implementation plan. The implementation plan that follows this spec scopes to **PR 1 only**: schema additions, UI rendering of new fields, buffer hygiene, and the reachability harness. PRs 2–4 (per-tier room rewrites) each get their own implementation plan after PR 1 lands, since per-room content is the bulk of the work and benefits from playtest feedback between tiers. PR 5 (tuning) is a follow-up plan after PR 4.

## Success criteria

- All 57 rooms rewritten with real-looking code, explicit goals, calibrated to tier.
- Every primary `optimal_keystrokes` sequence reaches `target_text` in CI.
- Every `optimal_keystrokes_alternates` entry also reaches `target_text` in CI.
- No regression in load time, validator strictness, or progress data compatibility.
- Playtest run end-to-end at each tier completes without unbeatable rooms.
