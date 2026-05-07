# Teach Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign `open_teach()` in `ui.lua` to reduce visual density via wider layout (60→70 chars), three clearly separated zones, dimmed tip text, and an arrow diff format replacing the old BEFORE:/AFTER: lines.

**Architecture:** Extract pure `build_diff_line()` logic to `highlights.lua` (testable without Neovim), then rewrite `open_teach()` in `ui.lua` to use it. Only `open_teach()` changes — no other functions, no new files, no new highlight groups.

**Tech Stack:** Lua, Neovim API (`nvim_buf_add_highlight` with byte offsets for multi-byte UTF-8), busted (tests)

---

## File Map

| File | Change |
|------|--------|
| `tests/spec/highlights_spec.lua` | Add `build_diff_line` tests |
| `lua/the-vimmer/highlights.lua` | Add local `visible_len()` + exported `M.build_diff_line()` |
| `lua/the-vimmer/ui.lua` | Rewrite `open_teach()` (lines 215–278) |

---

## Task 1: TDD — build_diff_line() in highlights.lua

**Files:**
- Modify: `tests/spec/highlights_spec.lua`
- Modify: `lua/the-vimmer/highlights.lua`

`build_diff_line(before_ex, after_ex, max_w)` converts `|` cursor markers to `▌`, builds the combined `before  →  after` display string, and splits to two lines if combined visible length exceeds `max_w`.

`▌` = U+258C = 3 bytes (`\xe2\x96\x8c`), 1 display char.
`→` = U+2192 = 3 bytes (`\xe2\x86\x92`), 1 display char.
`visible_len` strips multi-byte sequences to `_` before counting, giving correct display width.

- [ ] **Step 1: Add failing tests**

Append to `tests/spec/highlights_spec.lua` after the last `end`:

```lua
describe("highlights.build_diff_line", function()
  it("single line when short enough", function()
    local lines = hl.build_diff_line("|hello world", "hell|o world", 66)
    assert.equals(1, #lines)
    assert.equals("▌hello world  →  hell▌o world", lines[1])
  end)

  it("splits to two lines when combined exceeds max_w", function()
    local long = string.rep("x", 40)
    local lines = hl.build_diff_line("|" .. long, long .. "|", 66)
    assert.equals(2, #lines)
    assert.equals("▌" .. long, lines[1])
    assert.equals("→  " .. long .. "▌", lines[2])
  end)

  it("handles missing cursor marker gracefully", function()
    local lines = hl.build_diff_line("hello", "hell|o", 66)
    assert.equals(1, #lines)
    assert.equals("hello  →  hell▌o", lines[1])
  end)
end)
```

- [ ] **Step 2: Run tests — expect 3 errors**

```bash
~/.luarocks/bin/busted tests/spec/highlights_spec.lua
```

Expected: 3 errors — `attempt to call field 'build_diff_line' (a nil value)`

- [ ] **Step 3: Add visible_len() and build_diff_line() to highlights.lua**

In `lua/the-vimmer/highlights.lua`, add before `function M.combo_group`:

```lua
local function visible_len(s)
  return #(s:gsub("[\xc2-\xdf][\x80-\xbf]", "_")
            :gsub("[\xe0-\xef][\x80-\xbf][\x80-\xbf]", "_")
            :gsub("[\xf0-\xf7][\x80-\xbf][\x80-\xbf][\x80-\xbf]", "_"))
end

function M.build_diff_line(before_ex, after_ex, max_w)
  local before_disp = before_ex:gsub("|", "▌")
  local after_disp = after_ex:gsub("|", "▌")
  local combined = before_disp .. "  →  " .. after_disp
  if visible_len(combined) <= max_w then
    return { combined }
  end
  return { before_disp, "→  " .. after_disp }
end
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
~/.luarocks/bin/busted tests/spec/highlights_spec.lua
```

Expected: all tests pass, 0 failures

- [ ] **Step 5: Run full suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add tests/spec/highlights_spec.lua lua/the-vimmer/highlights.lua
git commit -m "feat: add build_diff_line() to highlights with tests"
```

---

## Task 2: Rewrite open_teach()

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — replace `function M.open_teach` (lines 215–278)

Changes:
- Width 60 → 70
- Normal rooms: remove `COMMAND:` label prefix; remove `BEFORE:`/`AFTER:` lines; add arrow diff via `build_diff_line`; add `╠═╣` separator after diff; dim tip with `VimmerLocked`; remove old hardcoded pipe highlight (lines 259–268)
- Boss rooms: width only (keep BEFORE:/AFTER: — boss phases are multi-line buffer contents, no cursor markers)
- Char-level highlights: scan diff line bytes for `▌` (`\xe2\x96\x8c`) → `VimmerCrit` and `→` (`\xe2\x86\x92`) → `VimmerXP`

No automated test possible (requires Neovim API). Manual verification listed in Step 3.

- [ ] **Step 1: Replace open_teach() entirely**

In `lua/the-vimmer/ui.lua`, replace the entire `function M.open_teach(room, on_begin)` block (from `function M.open_teach` through the closing `end` before `local _play_ns`) with:

```lua
function M.open_teach(room, on_begin)
  local hl = require("the-vimmer.highlights")
  local width = 70
  local b = make_border(width)
  local lines = {}
  local hls = {}
  local diff_rows = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  if room.is_boss then
    add(b.row("  ⚔ BOSS: " .. room.command:gsub("\n", " ↵ ")), "VimmerBoss")
    add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      add(b.row(string.format("  PHASE %d: %s", i, phase.tip or "")), "VimmerCommand")
      add(b.row("  BEFORE: " .. phase.start_text:gsub("\n", " ↵ ")), "VimmerLocked")
      add(b.row("  AFTER:  " .. phase.target_text:gsub("\n", " ↵ ")), "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
  else
    add(b.row("  " .. room.command:gsub("\n", " ↵ ")), "VimmerCommand")
    add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
    add(b.sep)
    local diff_lines = hl.build_diff_line(room.before_example, room.after_example, 66)
    for _, dl in ipairs(diff_lines) do
      diff_rows[#diff_rows+1] = #lines
      add(b.row("  " .. dl))
    end
    add(b.sep)
    local tip = room.usage_tip
    while #tip > 66 do
      local cut = tip:sub(1, 66):match("^(.+) ")
      add(b.row("  " .. (cut or tip:sub(1, 66))), "VimmerLocked")
      tip = tip:sub(#(cut or tip:sub(1, 66)) + 2)
    end
    if #tip > 0 then add(b.row("  " .. tip), "VimmerLocked") end
  end
  add(b.sep)
  add(b.row("  <Enter> to begin   <q> back"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  for _, row in ipairs(diff_rows) do
    local line = lines[row + 1]
    local pos = 1
    while pos <= #line do
      local b1 = line:byte(pos)
      if b1 == 0xe2 then
        local b2 = line:byte(pos + 1) or 0
        local b3 = line:byte(pos + 2) or 0
        if b2 == 0x96 and b3 == 0x8c then
          api.nvim_buf_add_highlight(buf, 0, "VimmerCrit", row, pos - 1, pos + 2)
          pos = pos + 3
        elseif b2 == 0x86 and b3 == 0x92 then
          api.nvim_buf_add_highlight(buf, 0, "VimmerXP", row, pos - 1, pos + 2)
          pos = pos + 3
        else
          pos = pos + 1
        end
      else
        pos = pos + 1
      end
    end
  end

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_begin()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true, silent = true })
end
```

- [ ] **Step 2: Run test suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass

- [ ] **Step 3: Manual smoke test in Neovim**

```vim
:VimmerPlay beginner_hjkl
```

Verify:
- Window is wider (70 chars)
- Command `h / j / k / l` appears bold yellow, no `COMMAND:` prefix
- Description appears below in white
- Separator line
- Arrow diff: `▌move right to reach the end  →  move right to reach the end` (or similar) — `▌` in gold, `→` in yellow
- Separator line
- Tip text in muted gray/blue (`VimmerLocked` color)
- `<Enter>` starts play, `<q>` closes

Also test a boss room:
```vim
:VimmerPlay beginner_boss
```

Verify:
- Window is wider (70 chars)
- `⚔ BOSS:` header still shows
- Phases still show `BEFORE:` / `AFTER:` labels (unchanged format)

- [ ] **Step 4: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: redesign teach screen with arrow diff and visual hierarchy"
```

---

## Verification

After both tasks complete:

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass (95+ successes), 0 failures, 0 errors.
