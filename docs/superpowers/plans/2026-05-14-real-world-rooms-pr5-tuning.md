# Real-World Rooms PR 5 — Tuning Pass

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Calibrate `time_limit` and `base_xp` across all 57 rewritten rooms (PRs 2-4) based on the actual primary keystroke counts produced during content rewrites. Spec PR 5 prescribed a playtest pass; this plan does the static portion that doesn't require human play time (time budget per keystroke, XP banding sanity-check). Anything that still needs human playtest stays out of scope.

**Architecture:** Single-file edits to `lua/rooms/<tier>/*.lua` to update `time_limit` and `base_xp`. No schema changes. No new reachability work — every edit is a number swap, verified by re-running the existing harness.

**Tech Stack:** Lua 5.1, busted, headless Neovim reachability harness.

**Tuning rules (derived from spec calibration ranges):**
- `time_limit` target: **~4 seconds per primary keystroke** for the room's primary `optimal_keystrokes` count. Floor: 45s. Ceiling: per spec tier max (beginner 60s, warrior 90s, ninja 180s).
- Beginner rooms with primary keystrokes ≤ 8 can leave `time_limit = nil` (the existing convention for trivial rooms).
- `base_xp` stays in spec bands: beginner 30–60, warrior 70–110, ninja 120–180. Bosses keep their separate higher range (300/500/700).
- Rooms with primary `optimal_keystrokes` length significantly below average for their tier may drop XP toward the band's low end; longer / harder rooms may push toward the high end. Anchor to keystroke count, not subjective difficulty.

**Audit table (snapshot, taken pre-tuning):**

```
Tier      Room                      xp    tl    keys   s/key   action
---------------------------------------------------------------------
beginner  hjkl                      30    nil   15     —       add tl=60
beginner  insert_mode               50    nil   11     —       add tl=60
beginner  insert2                   55    60    23     2.6     bump tl 60→75
warrior   ci_combo                  80    60    27     2.2     bump tl 60→90
ninja     surround_obj              125   70    20     3.5     bump tl 70→85
ninja     text_objects              130   75    25     3.0     bump tl 75→90
ninja     registers2                140   80    25     3.2     bump tl 80→100

(every other room is within 4-10 s/key, generous-enough — no change.)
```

XP audit: every regular room sits inside its tier band. Bosses are 300/500/700, separate range. No XP changes required this pass.

**Existing test gates (must remain green after each commit):**

```bash
~/.luarocks/bin/busted
nvim --headless --noplugin -l tests/reachability.lua
```

Expected after each task: `158 successes` busted, `63 checked, 0 skipped, all sequences pass` reachability.

---

## File Structure

| Path | Action | Reason |
|---|---|---|
| `lua/rooms/beginner/hjkl.lua` | Modify | add `time_limit = 60` (Task 1) |
| `lua/rooms/beginner/insert_mode.lua` | Modify | add `time_limit = 60` (Task 1) |
| `lua/rooms/beginner/insert2.lua` | Modify | bump `time_limit` 60→75 (Task 1) |
| `lua/rooms/warrior/ci_combo.lua` | Modify | bump `time_limit` 60→90 (Task 2) |
| `lua/rooms/ninja/surround_obj.lua` | Modify | bump `time_limit` 70→85 (Task 3) |
| `lua/rooms/ninja/text_objects.lua` | Modify | bump `time_limit` 75→90 (Task 3) |
| `lua/rooms/ninja/registers2.lua` | Modify | bump `time_limit` 80→100 (Task 3) |
| (no new files) | — | tuning only |

---

## Task 1: Beginner time_limit pass

**Files:**
- Modify: `lua/rooms/beginner/hjkl.lua` — add `time_limit = 60`
- Modify: `lua/rooms/beginner/insert_mode.lua` — add `time_limit = 60`
- Modify: `lua/rooms/beginner/insert2.lua` — change `time_limit = 60` to `time_limit = 75`

- [ ] **Step 1: Add `time_limit = 60` to `lua/rooms/beginner/hjkl.lua`**

Insert one line after `base_xp = 30,`:

```lua
  base_xp = 30,
  time_limit = 60,
```

- [ ] **Step 2: Add `time_limit = 60` to `lua/rooms/beginner/insert_mode.lua`**

Insert one line after `base_xp = 50,`:

```lua
  base_xp = 50,
  time_limit = 60,
```

- [ ] **Step 3: Bump `time_limit` 60 → 75 in `lua/rooms/beginner/insert2.lua`**

Replace:

```lua
  time_limit = 60,
```

with:

```lua
  time_limit = 75,
```

- [ ] **Step 4: Verify reachability + busted still pass**

Run: `nvim --headless --noplugin -l tests/reachability.lua && ~/.luarocks/bin/busted`
Expected: `reachability: 63 checked, 0 skipped, all sequences pass` and `158 successes / 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/beginner/hjkl.lua lua/rooms/beginner/insert_mode.lua lua/rooms/beginner/insert2.lua
git commit -m "tune(rooms): widen beginner time_limit on hjkl, insert_mode, insert2"
```

---

## Task 2: Warrior time_limit pass

**Files:**
- Modify: `lua/rooms/warrior/ci_combo.lua` — change `time_limit = 60` to `time_limit = 90`

- [ ] **Step 1: Bump `time_limit` 60 → 90 in `lua/rooms/warrior/ci_combo.lua`**

Replace:

```lua
  time_limit = 60,
```

with:

```lua
  time_limit = 90,
```

- [ ] **Step 2: Verify reachability + busted still pass**

Run: `nvim --headless --noplugin -l tests/reachability.lua && ~/.luarocks/bin/busted`
Expected: `reachability: 63 checked, 0 skipped, all sequences pass` and `158 successes / 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add lua/rooms/warrior/ci_combo.lua
git commit -m "tune(rooms): widen warrior_ci_combo time_limit 60->90"
```

---

## Task 3: Ninja time_limit pass

**Files:**
- Modify: `lua/rooms/ninja/surround_obj.lua` — change `time_limit = 70` to `time_limit = 85`
- Modify: `lua/rooms/ninja/text_objects.lua` — change `time_limit = 75` to `time_limit = 90`
- Modify: `lua/rooms/ninja/registers2.lua` — change `time_limit = 80` to `time_limit = 100`

- [ ] **Step 1: Bump `time_limit` 70 → 85 in `lua/rooms/ninja/surround_obj.lua`**

Replace:

```lua
  time_limit = 70,
```

with:

```lua
  time_limit = 85,
```

- [ ] **Step 2: Bump `time_limit` 75 → 90 in `lua/rooms/ninja/text_objects.lua`**

Replace:

```lua
  time_limit = 75,
```

with:

```lua
  time_limit = 90,
```

- [ ] **Step 3: Bump `time_limit` 80 → 100 in `lua/rooms/ninja/registers2.lua`**

Replace:

```lua
  time_limit = 80,
```

with:

```lua
  time_limit = 100,
```

- [ ] **Step 4: Verify reachability + busted still pass**

Run: `nvim --headless --noplugin -l tests/reachability.lua && ~/.luarocks/bin/busted`
Expected: `reachability: 63 checked, 0 skipped, all sequences pass` and `158 successes / 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/ninja/surround_obj.lua lua/rooms/ninja/text_objects.lua lua/rooms/ninja/registers2.lua
git commit -m "tune(rooms): widen ninja time_limit on text-heavy rooms"
```

---

## Task 4: Final tier audit

**Files:**
- None (verification only).

- [ ] **Step 1: Re-run the keystroke-budget audit**

Run:

```bash
for tier in beginner warrior ninja; do
  echo "=== $tier ==="
  for f in lua/rooms/$tier/*.lua; do
    name=$(basename "$f" .lua)
    xp=$(grep -E "^\s*base_xp\s*=" "$f" | head -1 | grep -oE "[0-9]+")
    tl=$(grep -E "^\s*time_limit\s*=" "$f" | head -1 | grep -oE "[0-9]+")
    keys=$(grep -A1 -E "^\s*optimal_keystrokes\s*=" "$f" | head -1 | grep -oE "\"[^\"]*\"" | wc -l)
    printf "  %-22s xp=%s tl=%s keys=%d\n" "$name" "$xp" "${tl:--}" "$keys"
  done
done
```

Expected: every room with `time_limit` ≥ ~3.5 × `keys` (4 s/key average); no XP outside spec band.

- [ ] **Step 2: Final reachability + busted**

Run: `nvim --headless --noplugin -l tests/reachability.lua && ~/.luarocks/bin/busted`
Expected: 63 checked, 0 skipped, all pass; 158/158 busted.

- [ ] **Step 3: No final commit needed if Steps 1-2 are clean.**

If any room slipped through (e.g., an XP value outside band that wasn't caught in the original audit), fix and commit:

```bash
git add -u
git commit -m "tune(rooms): final tier audit cleanup"
```

---

## Out of scope (deferred until human playtest)

- Snippet length/density: spec says ninja rooms can be 20-40 lines; current rewrites are 5-15 lines. Bumping snippet size requires re-authoring `start_text` / `target_text` / `optimal_keystrokes` — not a number swap. Defer.
- Choice of alternate paths: some rooms have one alternate, some none. Adding more requires Vim judgment, not arithmetic. Defer.
- Real difficulty curve between rooms within a tier: only a playtest can detect "this room is harder than the one after it." No data to act on yet.

---

## Self-Review Checklist

1. **Spec coverage:**
   - PR 5 per spec = "playtest each tier end-to-end, adjust budgets and time limits where calibration is off."
   - This plan handles the static budget/time-limit portion. Playtest-driven difficulty re-ordering and snippet sizing are explicitly deferred above. ✓

2. **Placeholder scan:** Every step lists exact file path, exact old value, exact new value. No "TBD". ✓

3. **Type consistency:** All edits are `time_limit = <number>` swaps. Field already exists in `rooms.lua` validator (warrior boss row used it). ✓
