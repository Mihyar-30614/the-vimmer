# UI Module Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `lua/the-vimmer/ui.lua` (1321 lines) into a `lua/the-vimmer/ui/` directory of focused submodules behind a facade, preserving the public API exactly and adding unit tests for pure helpers.

**Architecture:** New `lua/the-vimmer/ui/` directory with `init.lua` facade re-exporting submodules. `common.lua` holds pure formatting/layout helpers; `float.lua` holds window primitives + width constants; one `<screen>.lua` per public `open_*` function. Cross-screen calls use lazy `require("the-vimmer.ui")` inside function bodies to avoid circular load. Single commit at the end covers all moves; existing tests must stay green and new `ui_common_spec.lua` covers pure helpers headlessly.

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim Lua API (`vim.api`, `vim.loop`, `vim.fn`), busted for headless tests.

**Spec:** `docs/superpowers/specs/2026-05-14-ui-module-split-design.md`

---

## File Structure

**Created:**
- `lua/the-vimmer/ui/init.lua` — facade
- `lua/the-vimmer/ui/common.lua` — pure helpers
- `lua/the-vimmer/ui/float.lua` — window primitives + width constants
- `lua/the-vimmer/ui/key_replay.lua` — `M.open_key_replay`
- `lua/the-vimmer/ui/map.lua` — `M.open_map`
- `lua/the-vimmer/ui/progress.lua` — `M.open_progress`
- `lua/the-vimmer/ui/teach.lua` — `M.open_teach`
- `lua/the-vimmer/ui/play.lua` — `M.open_play`, `M._close_play` (`_show_phase_banner` is module-local)
- `lua/the-vimmer/ui/results.lua` — `M.open_results`
- `lua/the-vimmer/ui/death.lua` — `M.open_death`
- `tests/spec/ui_common_spec.lua` — pure helper specs

**Modified:**
- `tests/spec/helpers.lua` — extra `vim.split`, `vim.trim`, `vim.fn.*` stubs for ui_common_spec

**Deleted:**
- `lua/the-vimmer/ui.lua`

**Unchanged:** `lua/the-vimmer/commands.lua` and all other modules. `require("the-vimmer.ui")` keeps working because Lua resolves it to `lua/the-vimmer/ui/init.lua` once `ui.lua` is gone.

---

## Commit Strategy

Per the spec: **one commit covering the entire refactor**. No commits between tasks. Tasks 1–12 leave the working tree dirty; Task 13 verifies + commits.

While intermediate tasks run, `lua/the-vimmer/ui.lua` keeps existing and remains authoritative for `require("the-vimmer.ui")` (Lua's `package.loaders` prefers `<name>.lua` over `<name>/init.lua` when both exist on the same path entry, but to avoid relying on loader order, **`ui.lua` is deleted in Task 12 before any verification**).

---

### Task 1: Extend test helper stubs

**Files:**
- Modify: `tests/spec/helpers.lua`

Add stubs so `ui_common_spec.lua` can exercise helpers that call `vim.split`, `vim.trim`, and `vim.fn.strdisplaywidth/strchars/strcharpart` without a running Neovim.

- [ ] **Step 1: Read current helpers.lua**

Run: `cat tests/spec/helpers.lua`
Expected: file ends with `_G.vim = { ... }` block; no `vim.split`, no `vim.trim`, no `vim.fn.strdisplaywidth`, no `vim.fn.strchars`, no `vim.fn.strcharpart`.

- [ ] **Step 2: Add the stubs**

Replace the `_G.vim = { ... }` block in `tests/spec/helpers.lua` with this extended version (keep the surrounding `if not rawget(_G, "vim") then ... end` guard). The diff is additive — same outer shape, more fields:

```lua
if not rawget(_G, "vim") then
  _G.vim = {
    json = require("the-vimmer.json"),
    fn = {
      stdpath = function() return "/tmp" end,
      mkdir = function() end,
      glob = function(pattern, nosuf, list)
        local files = {}
        local handle = io.popen('ls ' .. pattern .. ' 2>/dev/null')
        if handle then
          for line in handle:lines() do files[#files+1] = line end
          handle:close()
        end
        return list and files or table.concat(files, "\n")
      end,
      strdisplaywidth = function(s) return #(s or "") end,
      strchars = function(s) return #(s or "") end,
      strcharpart = function(s, start, len)
        s = s or ""
        if len == nil then return s:sub(start + 1) end
        return s:sub(start + 1, start + len)
      end,
    },
    tbl_deep_extend = function(_, base, override)
      local result = {}
      for k, v in pairs(base) do result[k] = v end
      for k, v in pairs(override) do result[k] = v end
      return result
    end,
    log = { levels = { WARN = 2, INFO = 3, ERROR = 4 } },
    notify = function() end,
    trim = function(s)
      return (s or ""):match("^%s*(.-)%s*$")
    end,
    split = function(s, sep, opts)
      opts = opts or {}
      local plain = opts.plain
      local out = {}
      if s == nil or s == "" then return out end
      local i = 1
      while true do
        local a, b
        if plain then
          a, b = s:find(sep, i, true)
        else
          a, b = s:find(sep, i)
        end
        if not a then
          out[#out + 1] = s:sub(i)
          break
        end
        out[#out + 1] = s:sub(i, a - 1)
        i = b + 1
      end
      return out
    end,
  }
end
```

These stubs are ASCII-only (`strdisplaywidth = #s`); the helper specs do not assert on multi-byte width. That is an intentional non-goal from the spec.

- [ ] **Step 3: Confirm existing specs still pass**

Run: `busted tests/spec/`
Expected: same number of tests as before this task, all pass. No errors about missing `vim.split` etc. (None reference them yet, so this is a no-op check — but confirms the new code parses cleanly.)

- [ ] **Step 4: Do not commit. Move on.**

---

### Task 2: Extract `ui/common.lua`

**Files:**
- Create: `lua/the-vimmer/ui/common.lua`

Copy the twelve pure helpers from `lua/the-vimmer/ui.lua` lines 17–215 verbatim, but expose them on `M` so `ui_common_spec` (and other submodules) can reach them. Internal cross-calls (e.g. `build_optimal_lines` calls `format_key`; `add_wrapped_prefixed` calls `wrap_teach_text`) stay inside this module — promote them to local references at the top so the function bodies don't need to qualify with `M.`.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/common.lua`

```lua
-- Pure formatting and layout helpers for the-vimmer's UI screens.
-- No side effects on Neovim state. Safe to require headlessly.
local M = {}

M.MUTATOR_TEACH = {
  iron = "Iron",
  glass = "Glass",
  rush = "Rush",
}

function M.pick_float_width(desired)
  local margin = 4
  local max_w = math.max(44, vim.o.columns - margin)
  return math.min(desired, max_w)
end

function M.format_key(k)
  if k == "\27"           then return "<Esc>"
  elseif k == "\r"        then return "<CR>"
  elseif k == "\n"        then return "<CR>"
  elseif k == "\t"        then return "<Tab>"
  elseif k == " "         then return "<Spc>"
  elseif k == "\x08"      then return "<BS>"
  else return k end
end

function M.mutator_summary_line(names)
  if not names or #names == 0 then return nil end
  local parts = {}
  for _, n in ipairs(names) do
    parts[#parts + 1] = M.MUTATOR_TEACH[n] or n
  end
  return "  Mutators: " .. table.concat(parts, ", ")
end

function M.build_optimal_lines(room, inner_width)
  local result = {}
  local function wrap_seq(prefix, ks)
    local parts = {}
    for _, k in ipairs(ks or {}) do parts[#parts+1] = M.format_key(k) end
    local seq = table.concat(parts, " ")
    local full = prefix .. seq
    if #full <= inner_width then
      result[#result+1] = full
      return
    end
    local tokens = vim.split(seq, " ", { plain = true })
    local line = prefix
    for _, tok in ipairs(tokens) do
      local sep = line == prefix and "" or " "
      if #line + #sep + #tok > inner_width and line ~= prefix then
        result[#result+1] = line
        line = "    " .. tok
      else
        line = line .. sep .. tok
      end
    end
    if line ~= "" then result[#result+1] = line end
  end
  if room.is_boss then
    for i, phase in ipairs(room.phases or {}) do
      wrap_seq(string.format("  P%d: ", i), phase.optimal_keystrokes)
    end
  else
    wrap_seq("  ", room.optimal_keystrokes)
  end
  return result
end

function M.pad_row(content, width)
  local visible = content:gsub("[\xc2-\xdf][\x80-\xbf]", "_")
    :gsub("[\xe0-\xef][\x80-\xbf][\x80-\xbf]", "_")
    :gsub("[\xf0-\xf7][\x80-\xbf][\x80-\xbf][\x80-\xbf]", "_")
  local pad = width - 2 - #visible
  if pad < 0 then pad = 0 end
  return "║" .. content .. string.rep(" ", pad) .. "║"
end

function M.wrap_teach_text(text, max_display_width)
  local lines = {}
  text = vim.trim(text or "")
  if text == "" then
    return lines
  end
  local cur = ""
  local function flush_cur()
    if cur ~= "" then
      lines[#lines + 1] = cur
      cur = ""
    end
  end
  local function emit_word(word)
    local trial = cur == "" and word or (cur .. " " .. word)
    if vim.fn.strdisplaywidth(trial) <= max_display_width then
      cur = trial
      return
    end
    flush_cur()
    if vim.fn.strdisplaywidth(word) <= max_display_width then
      cur = word
      return
    end
    local rest = word
    while rest ~= "" do
      if vim.fn.strdisplaywidth(rest) <= max_display_width then
        cur = rest
        rest = ""
      else
        local take = 1
        local nchars = vim.fn.strchars(rest, true)
        for len = 1, nchars do
          local piece = vim.fn.strcharpart(rest, 0, len)
          if vim.fn.strdisplaywidth(piece) <= max_display_width then
            take = len
          else
            break
          end
        end
        if take < 1 then take = 1 end
        lines[#lines + 1] = vim.fn.strcharpart(rest, 0, take)
        rest = vim.fn.strcharpart(rest, take)
      end
    end
  end
  for word in text:gmatch("%S+") do
    emit_word(word)
  end
  flush_cur()
  return lines
end

function M.add_wrapped_prefixed(add, row, prefix, text, box_width, hl_group)
  local paras = vim.split(text or "", "\n", { plain = true })
  local started = false
  for _, para in ipairs(paras) do
    para = vim.trim(para)
    if para ~= "" then
      if started then
        add(row(""), nil)
      end
      started = true
      local inner = box_width - 2
      local pad_cols = vim.fn.strdisplaywidth(prefix)
      local budget = inner - pad_cols
      if budget < 8 then budget = math.max(4, inner) end
      local parts = M.wrap_teach_text(para, budget)
      if #parts > 0 then
        add(row(prefix .. parts[1]), hl_group)
        local indent = string.rep(" ", pad_cols)
        for i = 2, #parts do
          add(row(indent .. parts[i]), hl_group)
        end
      end
    end
  end
end

function M.make_border(width)
  return {
    top = "╔" .. string.rep("═", width - 2) .. "╗",
    sep = "╠" .. string.rep("═", width - 2) .. "╣",
    bot = "╚" .. string.rep("═", width - 2) .. "╝",
    row = function(content) return M.pad_row(content, width) end,
  }
end

function M.tier_room_bar(cleared, total, bar_len)
  bar_len = bar_len or 8
  if total <= 0 then return string.rep("░", bar_len) end
  local filled = math.floor(cleared * bar_len / total + 0.5)
  filled = math.min(bar_len, math.max(0, filled))
  return string.rep("█", filled) .. string.rep("░", bar_len - filled)
end

function M.fmt_run_seconds(s)
  return string.format("%.1fs", s)
end

function M.streak_milestone_phrase(streak_after_win)
  if streak_after_win >= 20 then return "Dungeon legend — unreal streak." end
  if streak_after_win >= 10 then return "Double digits — you're flying." end
  if streak_after_win >= 5 then return "Five deep — rhythm locked in." end
  if streak_after_win >= 3 then return "Three in a row — streak bonus territory." end
  return nil
end

function M.xp_bar(xp, bar_width)
  local max_xp = 1000
  local filled = math.min(math.floor((xp / max_xp) * bar_width), bar_width)
  return string.rep("▓", filled) .. string.rep("░", bar_width - filled)
end

return M
```

- [ ] **Step 2: Headless require check**

Run: `lua -e 'package.path = "lua/?.lua;lua/?/init.lua;" .. package.path; require("tests.spec.helpers"); local c = require("the-vimmer.ui.common"); print(type(c.format_key), type(c.make_border))'`

(`tests.spec.helpers` is not actually a require-able module path. Skip that prelude and instead source the vim shim inline.)

Replacement command:

```bash
lua -e '
package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
_G.vim = { trim = function(s) return s end, split = function() return {} end, fn = { strdisplaywidth = function(s) return #s end, strchars = function(s) return #s end, strcharpart = function(s, a, b) return s:sub(a+1, a+b) end } }
local c = require("the-vimmer.ui.common")
print(type(c.format_key), c.format_key("\27"))
'
```

Expected output:
```
function	<Esc>
```

- [ ] **Step 3: Do not commit. Move on.**

---

### Task 3: Add `tests/spec/ui_common_spec.lua`

**Files:**
- Create: `tests/spec/ui_common_spec.lua`
- Test: this file is the test

Pure-helper coverage per the spec. Tests are written against the behavior of the helpers as they exist in `ui.lua` today — copy expected outputs from a quick experiment if needed.

- [ ] **Step 1: Write the test file**

Path: `tests/spec/ui_common_spec.lua`

```lua
dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local c = require("the-vimmer.ui.common")

describe("ui.common.format_key", function()
  it("maps escape", function()
    assert.equal("<Esc>", c.format_key("\27"))
  end)
  it("maps cr and lf to <CR>", function()
    assert.equal("<CR>", c.format_key("\r"))
    assert.equal("<CR>", c.format_key("\n"))
  end)
  it("maps tab, space, backspace", function()
    assert.equal("<Tab>", c.format_key("\t"))
    assert.equal("<Spc>", c.format_key(" "))
    assert.equal("<BS>", c.format_key("\x08"))
  end)
  it("passes through plain chars", function()
    assert.equal("a", c.format_key("a"))
    assert.equal("Z", c.format_key("Z"))
  end)
end)

describe("ui.common.mutator_summary_line", function()
  it("returns nil for empty input", function()
    assert.is_nil(c.mutator_summary_line(nil))
    assert.is_nil(c.mutator_summary_line({}))
  end)
  it("renders a single known mutator with its label", function()
    assert.equal("  Mutators: Iron", c.mutator_summary_line({ "iron" }))
  end)
  it("joins multiple mutators with comma-space", function()
    assert.equal("  Mutators: Iron, Glass, Rush",
      c.mutator_summary_line({ "iron", "glass", "rush" }))
  end)
  it("falls back to the raw name for unknown mutators", function()
    assert.equal("  Mutators: foo", c.mutator_summary_line({ "foo" }))
  end)
end)

describe("ui.common.pad_row", function()
  it("pads short content out to width", function()
    local out = c.pad_row("hi", 8)
    assert.equal("║hi    ║", out)
  end)
  it("leaves content alone when it equals inner width", function()
    local out = c.pad_row("abcd", 6)
    assert.equal("║abcd║", out)
  end)
  it("does not negative-pad when content overflows", function()
    local out = c.pad_row("toolong", 6)
    assert.equal("║toolong║", out)
  end)
end)

describe("ui.common.make_border", function()
  it("returns top/sep/bot strings of the given width", function()
    local b = c.make_border(10)
    assert.equal(10, #b.top:gsub("[\128-\255]", ""):len() + select(2, b.top:gsub("[\128-\255][\128-\255]", "")) * 0) -- byte-width check
    -- Simpler: assert structure
    assert.is_truthy(b.top:match("^╔"))
    assert.is_truthy(b.top:match("╗$"))
    assert.is_truthy(b.sep:match("^╠"))
    assert.is_truthy(b.sep:match("╣$"))
    assert.is_truthy(b.bot:match("^╚"))
    assert.is_truthy(b.bot:match("╝$"))
  end)
  it("returns a row function that pads through pad_row", function()
    local b = c.make_border(8)
    assert.equal("║hi    ║", b.row("hi"))
  end)
end)

describe("ui.common.tier_room_bar", function()
  it("is all empty when nothing is cleared", function()
    assert.equal(string.rep("░", 8), c.tier_room_bar(0, 5, 8))
  end)
  it("is all filled when fully cleared", function()
    assert.equal(string.rep("█", 8), c.tier_room_bar(5, 5, 8))
  end)
  it("rounds proportional fill to nearest block", function()
    assert.equal(string.rep("█", 4) .. string.rep("░", 4),
      c.tier_room_bar(2, 4, 8))
  end)
  it("returns an all-empty bar when total is zero", function()
    assert.equal(string.rep("░", 8), c.tier_room_bar(0, 0, 8))
  end)
  it("defaults bar_len to 8 when omitted", function()
    assert.equal(8, #c.tier_room_bar(0, 0))
  end)
end)

describe("ui.common.fmt_run_seconds", function()
  it("formats with one decimal and a trailing s", function()
    assert.equal("0.0s", c.fmt_run_seconds(0))
    assert.equal("12.3s", c.fmt_run_seconds(12.3))
    assert.equal("47.0s", c.fmt_run_seconds(47))
  end)
end)

describe("ui.common.streak_milestone_phrase", function()
  it("returns nil for sub-3 streaks", function()
    assert.is_nil(c.streak_milestone_phrase(0))
    assert.is_nil(c.streak_milestone_phrase(2))
  end)
  it("returns the right phrase at each threshold", function()
    assert.equal("Three in a row — streak bonus territory.",
      c.streak_milestone_phrase(3))
    assert.equal("Five deep — rhythm locked in.",
      c.streak_milestone_phrase(5))
    assert.equal("Double digits — you're flying.",
      c.streak_milestone_phrase(10))
    assert.equal("Dungeon legend — unreal streak.",
      c.streak_milestone_phrase(20))
  end)
  it("returns the highest matching tier for streaks above 20", function()
    assert.equal("Dungeon legend — unreal streak.",
      c.streak_milestone_phrase(42))
  end)
end)

describe("ui.common.xp_bar", function()
  it("is all empty at zero xp", function()
    assert.equal(string.rep("░", 8), c.xp_bar(0, 8))
  end)
  it("is all filled at max xp (1000)", function()
    assert.equal(string.rep("▓", 8), c.xp_bar(1000, 8))
  end)
  it("clamps to width when xp exceeds max", function()
    assert.equal(string.rep("▓", 8), c.xp_bar(99999, 8))
  end)
  it("renders proportional fill", function()
    assert.equal(string.rep("▓", 4) .. string.rep("░", 4),
      c.xp_bar(500, 8))
  end)
end)

describe("ui.common.build_optimal_lines", function()
  it("returns one short line for a regular room", function()
    local room = { optimal_keystrokes = { "d", "w" } }
    local out = c.build_optimal_lines(room, 80)
    assert.equal(1, #out)
    assert.equal("  d w", out[1])
  end)
  it("renders one line per phase for a boss room", function()
    local room = {
      is_boss = true,
      phases = {
        { optimal_keystrokes = { "d", "w" } },
        { optimal_keystrokes = { "y", "y", "p" } },
      },
    }
    local out = c.build_optimal_lines(room, 80)
    assert.equal(2, #out)
    assert.equal("  P1: d w", out[1])
    assert.equal("  P2: y y p", out[2])
  end)
  it("wraps long sequences to multiple lines", function()
    local ks = {}
    for i = 1, 30 do ks[i] = "x" end
    local room = { optimal_keystrokes = ks }
    local out = c.build_optimal_lines(room, 20)
    assert.is_true(#out >= 2)
    for _, ln in ipairs(out) do
      assert.is_true(#ln <= 20)
    end
  end)
  it("handles missing keystrokes table", function()
    local room = {}
    local out = c.build_optimal_lines(room, 80)
    -- empty sequence still yields one prefix-only line
    assert.is_true(#out == 1 or #out == 0)
  end)
end)

describe("ui.common.wrap_teach_text", function()
  it("returns an empty list for empty input", function()
    assert.same({}, c.wrap_teach_text("", 20))
    assert.same({}, c.wrap_teach_text(nil, 20))
  end)
  it("keeps short text on one line", function()
    assert.same({ "hello world" }, c.wrap_teach_text("hello world", 20))
  end)
  it("wraps at word boundaries", function()
    local out = c.wrap_teach_text("one two three four five", 10)
    assert.is_true(#out >= 2)
    for _, ln in ipairs(out) do
      assert.is_true(#ln <= 10)
    end
  end)
  it("trims leading and trailing whitespace", function()
    assert.same({ "x" }, c.wrap_teach_text("   x   ", 10))
  end)
end)
```

- [ ] **Step 2: Run the new spec**

Run: `busted tests/spec/ui_common_spec.lua`
Expected: every test passes. Total assertions in the dozens.

If any assertion fails, the helper behavior differs from what the spec assumes. Investigate by running the live helper in `ui.lua` against the same input — the test's expected value is what `ui.lua` already produces, not what seems "correct in the abstract". Fix the test, not the helper.

- [ ] **Step 3: Run the full suite to confirm no collateral**

Run: `busted tests/spec/`
Expected: all previously-passing specs still pass; new `ui_common_spec` passes.

- [ ] **Step 4: Do not commit. Move on.**

---

### Task 4: Extract `ui/float.lua`

**Files:**
- Create: `lua/the-vimmer/ui/float.lua`

Window primitives + width constants, copied from `ui.lua` lines 10–14 (constants) and 217–289 (primitives). The module-private `_flash_ns` becomes public as `M.flash_ns`.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/float.lua`

```lua
-- Floating-window primitives + width constants for the-vimmer's UI screens.
-- Pulls in vim.api at require time, so this is only safe to require inside Neovim.
local M = {}
local api = vim.api

M.FLOAT_MAP_W      = 78
M.FLOAT_TEACH_W    = 86
M.FLOAT_RESULTS_W  = 78
M.FLOAT_DEATH_W    = 52
M.FLOAT_PROGRESS_W = 74

M.flash_ns = api.nvim_create_namespace("the-vimmer-flash")

function M.apply_hl(buf, highlights)
  for _, h in ipairs(highlights) do
    api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
  end
end

function M.flash(buf, group, duration, callback)
  local n = api.nvim_buf_line_count(buf)
  for i = 0, n - 1 do
    api.nvim_buf_add_highlight(buf, M.flash_ns, group, i, 0, -1)
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, M.flash_ns, 0, -1)
    end
    if callback then callback() end
  end, duration or 100)
end

function M.multi_flash(buf, steps, callback)
  local function run(i)
    if i > #steps then
      if callback then callback() end
      return
    end
    local group, duration = steps[i][1], steps[i][2]
    if group and api.nvim_buf_is_valid(buf) then
      local n = api.nvim_buf_line_count(buf)
      for row = 0, n - 1 do
        api.nvim_buf_add_highlight(buf, M.flash_ns, group, row, 0, -1)
      end
    end
    vim.defer_fn(function()
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_clear_namespace(buf, M.flash_ns, 0, -1)
      end
      run(i + 1)
    end, duration)
  end
  run(1)
end

function M.open_float(lines, width)
  local height = #lines
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  local row = math.max(0, math.floor((vim.o.lines - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = row, col = col,
    width = width, height = height,
    style = "minimal", border = "none",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].foldcolumn = "0"
  api.nvim_win_set_cursor(win, { math.max(1, height), 0 })
  return buf, win
end

return M
```

- [ ] **Step 2: Do not require this from busted (it touches `vim.api`).**

No headless test step. Verification happens at Task 13 (manual smoke).

- [ ] **Step 3: Do not commit. Move on.**

---

### Task 5: Extract `ui/key_replay.lua`

**Files:**
- Create: `lua/the-vimmer/ui/key_replay.lua`

Holds `M.open_key_replay`. Copy from `ui.lua` lines 293–352. Replace internal references:

- `pick_float_width` → `common.pick_float_width`
- `make_border` → `common.make_border`
- `format_key` → `common.format_key`
- `open_float` → `float.open_float`
- `apply_hl` → `float.apply_hl`

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/key_replay.lua`

```lua
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")

function M.open_key_replay(room, replay_opts)
  replay_opts = replay_opts or {}
  local phase_idx = replay_opts.phase_index
  local keys = {}
  if room.is_boss then
    local ph = room.phases[phase_idx or 1]
    if ph and ph.optimal_keystrokes then
      for _, k in ipairs(ph.optimal_keystrokes) do keys[#keys + 1] = k end
    end
  elseif room.optimal_keystrokes then
    for _, k in ipairs(room.optimal_keystrokes) do keys[#keys + 1] = k end
  end

  local width = common.pick_float_width(54)
  local b = common.make_border(width)
  local lines = {}
  local hls = {}
  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end
  add(b.top)
  add(b.row("  Key replay (primary path)"), "VimmerTitle")
  add(b.sep)
  if #keys == 0 then
    add(b.row("  (no scripted sequence)"), "VimmerLocked")
  else
    for i, k in ipairs(keys) do
      add(b.row(string.format("  %2d  %s", i, common.format_key(k))), "VimmerTitle")
    end
  end
  add(b.sep)
  add(b.row("  <q> close"), "VimmerTeachFoot")
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)
  local ns = api.nvim_create_namespace("the-vimmer-replay")

  local function close_replay()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  vim.keymap.set("n", "q", close_replay, { buffer = buf, nowait = true, silent = true })

  if #keys > 0 then
    local i = 1
    local function pulse()
      if not api.nvim_buf_is_valid(buf) then return end
      api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      float.apply_hl(buf, hls)
      if i <= #keys then
        api.nvim_buf_add_highlight(buf, ns, "VimmerCrit", 2 + i, 0, -1)
        i = i + 1
        vim.defer_fn(pulse, 170)
      end
    end
    vim.defer_fn(pulse, 120)
  end
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 6: Extract `ui/map.lua`

**Files:**
- Create: `lua/the-vimmer/ui/map.lua`

Copy `ui.lua` lines 356–525 (`M.open_map`). Same replacement scheme as Task 5. Note: this module ALSO does `require("the-vimmer.rooms")` mid-function (line 396 in the original) and `local progress = require("the-vimmer.progress")` (currently at top of `ui.lua`); both must be re-required at the top of `map.lua`.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/map.lua`

```lua
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local progress = require("the-vimmer.progress")

function M.open_map(progress_data, rooms_by_tier, on_select)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}

  local width = common.pick_float_width(float.FLOAT_MAP_W)
  local b = common.make_border(width)
  local room_title_max = math.max(24, width - 14)
  local boss_title_max = math.max(20, width - 18)
  local boss_locked_title_max = math.max(16, width - 26)
  local bar = common.xp_bar(progress_data.total_xp, 6)
  local lines = {}
  local hls = {}
  local selectable = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  local tier_colors = {
    beginner = "VimmerTierBeginner",
    warrior  = "VimmerTierWarrior",
    ninja    = "VimmerTierNinja",
  }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA" }
  local tier_prereq = { warrior = "complete boss first", ninja = "complete boss first" }
  local tiers = { "beginner", "warrior", "ninja" }

  add(b.top)
  do
    local left = "  THE VIMMER"
    local right = string.format("XP:%-5d %s", progress_data.total_xp, bar)
    local gap = width - 2 - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right)
    if gap < 1 then gap = 1 end
    add(b.row(left .. string.rep(" ", gap) .. right), "VimmerTitle")
  end
  add(b.sep)

  do
    local rooms_mod = require("the-vimmer.rooms")
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    local weak_room = weak_id and rooms_mod.get_room(weak_id)
    if weak_room then
      local wtitle = weak_room.title
      if #wtitle > 46 then wtitle = wtitle:sub(1, 43) .. "..." end
      add(b.row("  ► Drill: " .. wtitle), "VimmerXP")
      selectable[#selectable + 1] = { line = #lines, room = weak_room }
      add(b.row(""))
    end
  end

  for ti, tier in ipairs(tiers) do
    local all_tier_rooms = rooms_by_tier[tier] or {}
    local tier_rooms = {}
    local boss_room = nil
    for _, room in ipairs(all_tier_rooms) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms+1] = room end
    end

    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      add(b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      local cleared_ct = 0
      local total_ct = #tier_rooms
      for _, room in ipairs(tier_rooms) do
        if progress_data.cleared[room.id] then cleared_ct = cleared_ct + 1 end
      end
      local bar_mini = common.tier_room_bar(cleared_ct, total_ct, 8)
      local boss_hint = ""
      if boss_room then
        local boss_cleared = progress_data.cleared[boss_room.id]
        local boss_unlocked = progress.is_boss_unlocked(tier, progress_data.cleared, total_ct)
        if boss_cleared then boss_hint = "  boss OK"
        elseif boss_unlocked then boss_hint = "  boss!"
        else
          local need = math.ceil(math.max(total_ct, 1) * 0.8)
          boss_hint = string.format("  %d/%d for boss", cleared_ct, need)
        end
      end
      add(b.row(string.format("  [%s]  %d/%d  %s%s",
        tier_labels[tier], cleared_ct, total_ct, bar_mini, boss_hint)), tier_colors[tier])
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, room_title_max))
        if cleared then
          add(b.row(label), "VimmerCleared")
        else
          add(b.row(label))
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
      if boss_room then
        local boss_cleared = progress_data.cleared[boss_room.id]
        local boss_unlocked = progress.is_boss_unlocked(tier, progress_data.cleared, #tier_rooms)
        if boss_cleared then
          add(b.row("   ✓ ⚔  " .. boss_room.title:sub(1, boss_title_max)), "VimmerCleared")
        elseif boss_unlocked then
          add(b.row("   ► ⚔  " .. boss_room.title:sub(1, boss_title_max)), "VimmerBoss")
          selectable[#selectable+1] = { line = #lines, room = boss_room }
        else
          add(b.row("     ⚔  " .. boss_room.title:sub(1, boss_locked_title_max) .. "  [80% first]"), "VimmerLocked")
        end
      end
    end
    if ti < #tiers then add(b.row("")) end
  end

  add(b.sep)
  add(b.row("  <Enter> play   j/k navigate   <q> quit"))
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  local _sel_ns = api.nvim_create_namespace("the-vimmer-sel")
  local cur_idx = 1

  local function update_selection()
    api.nvim_buf_clear_namespace(buf, _sel_ns, 0, -1)
    if #selectable == 0 then return end
    if selectable[cur_idx] then
      api.nvim_buf_add_highlight(buf, _sel_ns, "VimmerSelected",
        selectable[cur_idx].line - 1, 0, -1)
      api.nvim_win_set_cursor(win, { selectable[cur_idx].line, 0 })
    end
  end

  update_selection()

  local function map_key(key, fn)
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, silent = true })
  end

  map_key("j", function()
    if #selectable == 0 then return end
    cur_idx = math.min(cur_idx + 1, #selectable)
    update_selection()
  end)

  map_key("k", function()
    if #selectable == 0 then return end
    cur_idx = math.max(cur_idx - 1, 1)
    update_selection()
  end)

  map_key("<CR>", function()
    if #selectable == 0 then return end
    if selectable[cur_idx] then
      local room = selectable[cur_idx].room
      api.nvim_win_close(win, true)
      on_select(room)
    end
  end)

  map_key("q", function()
    api.nvim_win_close(win, true)
  end)

  map_key("<Esc>", function()
    api.nvim_win_close(win, true)
  end)
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 7: Extract `ui/progress.lua`

**Files:**
- Create: `lua/the-vimmer/ui/progress.lua`

Copy `ui.lua` lines 528–662 (`M.open_progress`). Same replacement scheme as Task 6. Be careful: this file's own require path is `the-vimmer.ui.progress`, and it requires `the-vimmer.progress` (a different module) at the top — keep both straight.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/progress.lua`

```lua
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
local progress = require("the-vimmer.progress")

function M.open_progress(progress_data, rooms_by_tier)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}
  progress_data.streak = progress_data.streak or 0

  local width = common.pick_float_width(float.FLOAT_PROGRESS_W)
  local b = common.make_border(width)
  local bar = common.xp_bar(progress_data.total_xp, 8)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines + 1] = content
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end

  local tiers = { "beginner", "warrior", "ninja" }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA" }
  local tier_colors = {
    beginner = "VimmerTierBeginner",
    warrior = "VimmerTierWarrior",
    ninja = "VimmerTierNinja",
  }
  local tier_prereq = { warrior = "beat beginner boss", ninja = "beat warrior boss" }

  add(b.top)
  add(b.row("  THE VIMMER — PROGRESS"), "VimmerTitle")
  add(b.sep)

  do
    local left = "  Total XP"
    local right = string.format("%d  %s", progress_data.total_xp, bar)
    local gap = width - 2 - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right)
    if gap < 1 then gap = 1 end
    add(b.row(left .. string.rep(" ", gap) .. right), "VimmerXP")
  end

  add(b.row(string.format("  Run streak: %d", progress_data.streak)), "VimmerTierWarrior")

  do
    local weak_id = progress.weakest_regular_room_id(progress_data, rooms_by_tier)
    if weak_id then
      local wr = require("the-vimmer.rooms").get_room(weak_id)
      if wr then
        local t = wr.title
        if #t > 54 then t = t:sub(1, 51) .. "..." end
        add(b.row("  Suggested drill: " .. t), "VimmerLocked")
      end
    end
  end

  do
    local muts = progress_data.unlocked_mutators or {}
    local names = {}
    for k, v in pairs(muts) do
      if v then names[#names + 1] = k end
    end
    table.sort(names)
    if #names > 0 then
      add(b.sep)
      add(b.row("  Mutators unlocked: " .. table.concat(names, ", ")), "VimmerTeachFoot")
    end
  end

  local cleared_total, room_total = 0, 0
  for _, tier in ipairs(tiers) do
    for _, r in ipairs(rooms_by_tier[tier] or {}) do
      if not r.is_boss then
        room_total = room_total + 1
        if progress_data.cleared[r.id] then cleared_total = cleared_total + 1 end
      end
    end
  end

  add(b.sep)
  add(b.row(string.format("  Regular rooms: %d / %d cleared", cleared_total, room_total)), "VimmerTitle")
  add(b.sep)

  for _, tier in ipairs(tiers) do
    local all_tier = rooms_by_tier[tier] or {}
    local tier_rooms = {}
    local boss_room = nil
    for _, room in ipairs(all_tier) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms + 1] = room end
    end

    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      add(b.row(string.format(
        "  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      local cleared_ct = 0
      local total_ct = #tier_rooms
      for _, room in ipairs(tier_rooms) do
        if progress_data.cleared[room.id] then cleared_ct = cleared_ct + 1 end
      end
      local mini = common.tier_room_bar(cleared_ct, total_ct, 10)
      local boss_txt = "—"
      if boss_room then
        local bc = progress_data.cleared[boss_room.id]
        local bu = progress.is_boss_unlocked(tier, progress_data.cleared, total_ct)
        if bc then boss_txt = "boss cleared"
        elseif bu then boss_txt = "boss ready"
        else
          local need = math.ceil(math.max(total_ct, 1) * 0.8)
          boss_txt = string.format("%d/%d for boss", need, total_ct)
        end
      end
      add(b.row(string.format(
        "  [%s]  %d/%d  %s   %s",
        tier_labels[tier], cleared_ct, total_ct, mini, boss_txt)),
        tier_colors[tier])
    end
  end

  add(b.sep)
  add(b.row("  <q> or <Esc> close"), "VimmerTeachFoot")
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  local function close_progress()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end

  vim.keymap.set("n", "q", close_progress, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close_progress, { buffer = buf, nowait = true, silent = true })
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 8: Extract `ui/teach.lua`

**Files:**
- Create: `lua/the-vimmer/ui/teach.lua`

Copy `ui.lua` lines 667–781 (`M.open_teach`). Same replacement scheme. The internal `M.open_key_replay` call (line 775 in original) becomes `require("the-vimmer.ui").open_key_replay(...)` — lazy require inside the function body, per the spec.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/teach.lua`

```lua
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
-- NOTE: do NOT top-level-require "the-vimmer.ui" — circular load.

function M.open_teach(room, flow_opts_or_cb, maybe_cb)
  local flow_opts, on_begin
  if type(flow_opts_or_cb) == "function" then
    on_begin = flow_opts_or_cb
    flow_opts = {}
  else
    flow_opts = flow_opts_or_cb or {}
    on_begin = maybe_cb
  end

  local hl = require("the-vimmer.highlights")
  local width = common.pick_float_width(float.FLOAT_TEACH_W)
  local b = common.make_border(width)
  local lines = {}
  local hls = {}
  local diff_rows = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  if room.is_boss then
    common.add_wrapped_prefixed(add, b.row, "  ⚔ BOSS: ", room.command:gsub("\n", " ↵ "), width, "VimmerBoss")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      common.add_wrapped_prefixed(add, b.row, string.format("  PHASE %d: ", i), phase.tip or "", width, "VimmerCommand")
      common.add_wrapped_prefixed(add, b.row, "  BEFORE: ", phase.start_text:gsub("\n", " ↵ "), width, "VimmerLocked")
      common.add_wrapped_prefixed(add, b.row, "  AFTER:  ", phase.target_text:gsub("\n", " ↵ "), width, "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
  else
    common.add_wrapped_prefixed(add, b.row, "  ", room.command:gsub("\n", " ↵ "), width, "VimmerCommand")
    common.add_wrapped_prefixed(add, b.row, "  ", room.description:gsub("\n", " ↵ "), width, "VimmerTitle")
    add(b.sep)
    local inner_example_w = width - 4
    local diff_lines = hl.build_diff_line(room.before_example, room.after_example, inner_example_w)
    for _, dl in ipairs(diff_lines) do
      diff_rows[#diff_rows+1] = #lines
      add(b.row("  " .. dl), "VimmerExample")
    end
    add(b.sep)
    common.add_wrapped_prefixed(add, b.row, "  ", room.usage_tip or "", width, "VimmerTeachTip")
  end

  local any_alt = false
  if room.is_boss then
    for _, ph in ipairs(room.phases or {}) do
      local al = ph.optimal_keystrokes_alternates
      if type(al) == "table" and #al > 0 then any_alt = true break end
    end
  elseif room.optimal_keystrokes_alternates and #room.optimal_keystrokes_alternates > 0 then
    any_alt = true
  end
  if any_alt then
    add(b.sep)
    add(b.row("  Multiple valid key paths — scoring accepts alternates."), "VimmerTeachFoot")
  end

  if flow_opts.daily then
    add(b.sep)
    add(b.row("  Daily challenge — mutators unlock from lifetime XP."), "VimmerXP")
  end

  local ms = common.mutator_summary_line(flow_opts.mutators or {})
  if ms then
    add(b.sep)
    add(b.row(ms), "VimmerTimerWarn")
  end

  add(b.sep)
  add(b.row("  <Enter> begin   <r> replay keys   <q> close"), "VimmerTeachFoot")
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

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

  vim.keymap.set("n", "r", function()
    require("the-vimmer.ui").open_key_replay(room, { phase_index = room.is_boss and 1 or nil })
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true, silent = true })
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 9: Extract `ui/play.lua`

**Files:**
- Create: `lua/the-vimmer/ui/play.lua`

Copy `ui.lua` lines 783–1075. The module-level state vars (`_play_ns`, `_play_tab`, `_timer_handle`) stay at module scope. `M._show_phase_banner` becomes a module-local `show_phase_banner` (removed from the facade per spec). `flash`/`multi_flash` calls become `float.flash`/`float.multi_flash`.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/play.lua`

```lua
local M = {}
local api = vim.api
local float = require("the-vimmer.ui.float")

-- Module-level play state. Only one play session can be active at a time.
local _play_ns = nil
local _play_tab = nil
local _timer_handle = nil

local function show_phase_banner(win, phase_num, callback)
  local label = string.format("  ── PHASE %d ──  ", phase_num)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, { label })
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  local win_width = api.nvim_win_get_width(win)
  local col = math.max(0, math.floor((win_width - #label) / 2))
  local banner_win = api.nvim_open_win(buf, false, {
    relative = "win", win = win,
    row = 2, col = col,
    width = #label, height = 1,
    style = "minimal", border = "none",
  })
  api.nvim_buf_add_highlight(buf, 0, "VimmerPhase", 0, 0, -1)
  vim.defer_fn(function()
    if api.nvim_win_is_valid(banner_win) then
      api.nvim_win_close(banner_win, true)
    end
    callback()
  end, 800)
end

function M.open_play(room, game_state, on_win, on_death)
  M._close_play()
  local hl = require("the-vimmer.highlights")
  local initial_time = room.time_limit
  local HUD_W = 24
  local _hud_ns = api.nvim_create_namespace("the-vimmer-hud")
  local hud_feedback_line = nil

  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")

  local hud_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(hud_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(hud_buf, "modifiable", false)

  vim.cmd("tabnew")
  _play_tab = api.nvim_get_current_tabpage()
  local left_win = api.nvim_get_current_win()

  vim.cmd("botright vsplit")
  local hud_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(hud_win, hud_buf)
  api.nvim_win_set_width(hud_win, HUD_W)
  vim.wo[hud_win].winfixwidth    = true
  vim.wo[hud_win].number         = false
  vim.wo[hud_win].relativenumber = false
  vim.wo[hud_win].signcolumn     = "no"
  vim.wo[hud_win].wrap           = false
  vim.wo[hud_win].cursorline     = false
  vim.wo[hud_win].statusline     = " "
  vim.wo[hud_win].winbar         = "%#VimmerTitle# ── STATUS ──%*"

  api.nvim_set_current_win(left_win)
  local top_win = left_win
  api.nvim_win_set_buf(top_win, target_buf)

  vim.cmd("belowright split")
  local play_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(play_win, play_buf)
  api.nvim_set_current_win(play_win)

  vim.wo[top_win].winbar  = "%#VimmerCleared# ── TARGET ──%*"
  vim.wo[play_win].winbar = "%#VimmerTierWarrior# ── EDIT HERE ──%*"

  local pu_icons_map = { hp_restore = "♥", freeze_timer = "❄", double_xp = "★" }

  local function update_hud()
    if not api.nvim_buf_is_valid(hud_buf) then return end
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    local hp_grp = hl.hp_group(game_state.hp)

    local lines = { "", " HP", " " .. hp_bar, string.format(" %d / 100", game_state.hp), "" }
    local hls = {
      { hp_grp, 2, 1, -1 },
      { hp_grp, 3, 1, -1 },
    }

    if hud_feedback_line then
      lines[#lines + 1] = " " .. hud_feedback_line
      hls[#hls + 1] = { "VimmerDeath", #lines - 1, 1, -1 }
      lines[#lines + 1] = ""
    end

    if game_state.timer_remaining then
      local mins = math.floor(game_state.timer_remaining / 60)
      local secs = game_state.timer_remaining % 60
      local t_grp = hl.timer_group(game_state.timer_remaining, initial_time)
      lines[#lines+1] = string.format(" ⏱  %d:%02d", mins, secs)
      hls[#hls+1] = { t_grp, #lines - 1, 1, -1 }
      if initial_time and game_state.timer_remaining <= math.max(5, math.floor(initial_time * 0.15)) then
        lines[#lines+1] = " HURRY — time low!"
        hls[#hls+1] = { "VimmerTimerDanger", #lines - 1, 1, -1 }
      end
      lines[#lines+1] = ""
    end

    lines[#lines+1] = string.format(" Streak  %d", game_state.streak)

    do
      local used = game_state.keystrokes_used or 0
      local budget = game_state.keystrokes_budget or 0
      local over = used > budget
      lines[#lines+1] = string.format(" Keys %d / %d", used, budget)
      hls[#hls+1] = { over and "VimmerDamage" or "VimmerTitle", #lines - 1, 1, -1 }
      if over then
        lines[#lines+1] = " OVER BUDGET — HP draining"
        hls[#hls+1] = { "VimmerTimerDanger", #lines - 1, 1, -1 }
      end
    end

    local pu_str = ""
    for _, pu in ipairs(game_state.power_ups) do
      pu_str = pu_str .. (pu_icons_map[pu.type] or "?")
    end
    if pu_str ~= "" then
      lines[#lines+1] = ""
      lines[#lines+1] = " " .. pu_str
    end

    lines[#lines+1] = ""
    lines[#lines+1] = " " .. string.rep("─", HUD_W - 2)
    lines[#lines+1] = ""

    local cmd = " " .. room.command
    local max_w = HUD_W - 1
    while #cmd > max_w do
      lines[#lines+1] = cmd:sub(1, max_w)
      cmd = " " .. cmd:sub(max_w + 1)
    end
    lines[#lines+1] = cmd

    api.nvim_buf_set_option(hud_buf, "modifiable", true)
    api.nvim_buf_set_lines(hud_buf, 0, -1, false, lines)
    api.nvim_buf_clear_namespace(hud_buf, _hud_ns, 0, -1)
    for _, h in ipairs(hls) do
      api.nvim_buf_add_highlight(hud_buf, _hud_ns, h[1], h[2], h[3], h[4])
    end
    api.nvim_buf_set_option(hud_buf, "modifiable", false)
  end

  local function hud_pulse_feedback(msg)
    hud_feedback_line = msg
    update_hud()
    local saved = msg
    vim.defer_fn(function()
      if hud_feedback_line == saved then
        hud_feedback_line = nil
        update_hud()
      end
    end, 950)
  end

  local function start_timer()
    if not game_state.timer_remaining then return end
    _timer_handle = vim.loop.new_timer()
    _timer_handle:start(1000, 1000, vim.schedule_wrap(function()
      if game_state.state ~= "playing" then
        if _timer_handle then _timer_handle:stop() end
        return
      end
      local dead = game_state:tick_timer()
      update_hud()
      if dead then
        if _timer_handle then _timer_handle:stop() end
        vim.cmd("stopinsert")
        float.multi_flash(play_buf, {
          { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
        }, on_death)
      end
    end))
  end

  local function start_phase(phase_data)
    local target_lines = vim.split(phase_data.target_text, "\n")

    api.nvim_buf_set_option(target_buf, "modifiable", true)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
    api.nvim_buf_set_option(target_buf, "modifiable", false)

    api.nvim_buf_set_lines(play_buf, 0, -1, false, vim.split(phase_data.start_text, "\n"))

    local ns = api.nvim_create_namespace("the-vimmer-keys-" .. tostring(game_state.boss_phase))
    _play_ns = ns

    vim.on_key(function(key)
      if not api.nvim_win_is_valid(play_win) then
        vim.on_key(nil, ns); return
      end
      if api.nvim_get_current_win() ~= play_win then return end

      local hp_before = game_state.hp
      game_state:register_key(key)
      local lost_hp = game_state.hp < hp_before
      update_hud()

      if lost_hp then
        hud_pulse_feedback(string.format(
          "-%d HP  (over budget)", hp_before - game_state.hp))
        float.flash(play_buf, "VimmerDamage", 80)
      end

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.cmd("stopinsert")
        vim.schedule(function()
          float.multi_flash(play_buf, {
            { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
          }, on_death)
        end)
        return
      end

      vim.schedule(function()
        if not api.nvim_buf_is_valid(play_buf) then return end
        if _play_ns ~= ns then return end
        local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
        local target = table.concat(target_lines, "\n")
        if vim.trim(current) == vim.trim(target) then
          vim.on_key(nil, ns)
          _play_ns = nil
          vim.cmd("stopinsert")
          local is_last = not room.is_boss or game_state.boss_phase >= game_state.boss_total_phases
          if is_last then
            float.multi_flash(play_buf, {
              { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 }
            }, on_win)
          else
            float.multi_flash(play_buf, {
              { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 }
            }, function()
              game_state:advance_boss_phase()
              local next_phase = game_state.boss_phase
              show_phase_banner(play_win, next_phase, function()
                start_phase(room.phases[next_phase])
              end)
            end)
          end
        end
      end)
    end, ns)

    vim.keymap.set("n", "<Tab>", function()
      if game_state:activate_freeze(5) then update_hud() end
    end, { buffer = play_buf, nowait = true, silent = true })
  end

  update_hud()
  local first_phase = room.is_boss and room.phases[1] or room
  start_phase(first_phase)
  start_timer()
end

function M._close_play()
  if _play_ns then
    vim.on_key(nil, _play_ns)
    _play_ns = nil
  end
  if _timer_handle then
    _timer_handle:stop()
    _timer_handle:close()
    _timer_handle = nil
  end
  if _play_tab and api.nvim_tabpage_is_valid(_play_tab) then
    pcall(function()
      local tab = _play_tab
      _play_tab = nil
      vim.cmd(api.nvim_tabpage_get_number(tab) .. "tabclose")
    end)
  end
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 10: Extract `ui/results.lua`

**Files:**
- Create: `lua/the-vimmer/ui/results.lua`

Copy `ui.lua` lines 1081–1264 (`M.open_results`). Same replacement scheme; uses `common.mutator_summary_line`, `common.streak_milestone_phrase`, `common.fmt_run_seconds`, `common.build_optimal_lines`, `common.pick_float_width`, `common.make_border`, `float.open_float`, `float.FLOAT_RESULTS_W`.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/results.lua`

```lua
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")

function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue, opts)
  opts = opts or {}
  local is_boss = opts.is_boss
  local fast_clear = opts.fast_clear
  local on_powerup = opts.on_powerup

  local width = common.pick_float_width(float.FLOAT_RESULTS_W)
  local b = common.make_border(width)
  local optimal_inner = math.max(32, width - 4)
  local all_lines = {}
  local hls = {}

  local function add(content, group)
    all_lines[#all_lines+1] = content
    if group then hls[#hls+1] = { group, #all_lines - 1, 0, -1 } end
  end

  add(b.top)
  if is_boss then
    add(b.row("  ⚔ BOSS CLEARED!"), "VimmerBoss")
  else
    add(b.row("  ROOM CLEARED!"), "VimmerWin")
  end
  if opts.first_clear then
    add(b.row("  First clear — new muscle memory unlocked."), "VimmerCleared")
  end
  if opts.is_daily then
    add(b.row("  Daily challenge run"), "VimmerXP")
  end
  do
    local ml = common.mutator_summary_line(opts.active_mutators or {})
    if ml then add(b.row(ml), "VimmerTimerWarn") end
  end
  add(b.sep)
  add(b.row(string.format("  XP Earned:     +%d", xp_earned)), "VimmerXP")
  if opts.run_stats and opts.run_stats.flawless then
    add(b.row("  Flawless sequence — +15% XP baked in."), "VimmerCleared")
  end
  add(b.row(string.format("  HP Remaining:  %d / 100", hp_remaining)), "VimmerTitle")
  add(b.row(string.format("  Streak:        %d", streak)), "VimmerTierWarrior")
  do
    local phrase = common.streak_milestone_phrase(streak)
    if phrase then add(b.row("  " .. phrase), "VimmerXP") end
  end

  local rs = opts.run_stats
  if rs then
    local used = rs.keystrokes_used or 0
    local over = rs.keystrokes_over_budget or 0
    local budget = rs.keystrokes_budget or 0
    local mult = rs.efficiency_mult or 1
    local show_keys = used > 0
    local show_time = rs.seconds ~= nil and rs.seconds > 0
    if show_keys or show_time then
      add(b.sep)
      if show_keys then
        add(b.row(string.format(
          "  Keystrokes: %d used  ·  budget %d  ·  %d over",
          used, budget, over)), "VimmerTitle")
        add(b.row(string.format(
          "  Efficiency multiplier: x%.2f", mult)), "VimmerXP")
      end
      if show_time then
        local t = common.fmt_run_seconds(rs.seconds)
        if rs.new_personal_best then
          if rs.beaten_seconds then
            add(b.row(string.format(
              "  Personal best: %s (was %s)",
              t, common.fmt_run_seconds(rs.beaten_seconds))), "VimmerXP")
          else
            add(b.row(string.format("  Personal best: %s", t)), "VimmerXP")
          end
        elseif rs.prev_best_seconds then
          add(b.row(string.format(
            "  Time: %s  ·  room best %s",
            t, common.fmt_run_seconds(rs.prev_best_seconds))), "VimmerTitle")
        else
          add(b.row(string.format("  Time: %s", t)), "VimmerTitle")
        end
      end
    end
  end

  if opts.room then
    add(b.sep)
    add(b.row("  Optimal sequence:"), "VimmerTitle")
    for _, ln in ipairs(common.build_optimal_lines(opts.room, optimal_inner)) do
      add(b.row(ln), "VimmerCommand")
    end
  end

  if unlocked_tier then
    local tier_name = unlocked_tier:lower()
    local tier_grp = ({ warrior = "VimmerTierWarrior", ninja = "VimmerTierNinja" })[tier_name]
      or "VimmerTierBeginner"
    add(b.sep)
    add(b.row("  NEW TIER UNLOCKED:"), "VimmerTitle")
    add(b.row("  " .. unlocked_tier), tier_grp)
  end

  local powerup_section_start = nil
  if fast_clear and on_powerup then
    add(b.sep)
    add(b.row("  ⚡ FAST CLEAR! Choose a power-up:"), "VimmerXP")
    powerup_section_start = #all_lines + 1
    add(b.row("    ♥  +30 HP next room"))
    add(b.row("    ❄  Freeze timer 5s"))
    add(b.row("    ★  Double XP next room"))
  end

  add(b.sep)
  local footer_line = #all_lines + 1
  if fast_clear and on_powerup then
    add(b.row("  j/k choose   <Enter> pick"))
  else
    add(b.row("  <Enter> next room   <q> map"))
  end
  add(b.bot)

  local empty = {}
  for _ = 1, #all_lines do empty[#empty+1] = "" end
  local buf, win = float.open_float(empty, width)

  local revealed = 0

  local function reveal_next()
    if not api.nvim_buf_is_valid(buf) then return end
    revealed = revealed + 1
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, revealed - 1, revealed, false, { all_lines[revealed] })
    api.nvim_buf_set_option(buf, "modifiable", false)
    for _, h in ipairs(hls) do
      if h[2] == revealed - 1 then
        api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
      end
    end
    if revealed < #all_lines then
      vim.defer_fn(reveal_next, 80)
    else
      if fast_clear and on_powerup and powerup_section_start then
        local pu_types = { "hp_restore", "freeze_timer", "double_xp" }
        local sel_ns = api.nvim_create_namespace("the-vimmer-pu-sel")
        local cur = 1
        local function update_pu_sel()
          api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
          local line = powerup_section_start + cur - 2
          api.nvim_buf_add_highlight(buf, sel_ns, "VimmerSelected", line, 0, -1)
        end
        update_pu_sel()
        vim.keymap.set("n", "j", function()
          cur = math.min(cur + 1, 3); update_pu_sel()
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "k", function()
          cur = math.max(cur - 1, 1); update_pu_sel()
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "<CR>", function()
          on_powerup(pu_types[cur])
          api.nvim_buf_set_option(buf, "modifiable", true)
          api.nvim_buf_set_lines(buf, footer_line - 1, footer_line, false,
            { b.row("  <Enter> next room   <q> map") })
          api.nvim_buf_set_option(buf, "modifiable", false)
          api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
          vim.keymap.del("n", "j", { buffer = buf })
          vim.keymap.del("n", "k", { buffer = buf })
          vim.keymap.set("n", "<CR>", function()
            api.nvim_win_close(win, true); on_continue(false)
          end, { buffer = buf, nowait = true, silent = true })
          vim.keymap.set("n", "q", function()
            api.nvim_win_close(win, true); on_continue(true)
          end, { buffer = buf, nowait = true, silent = true })
        end, { buffer = buf, nowait = true, silent = true })
      else
        vim.keymap.set("n", "<CR>", function()
          api.nvim_win_close(win, true); on_continue(false)
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "q", function()
          api.nvim_win_close(win, true); on_continue(true)
        end, { buffer = buf, nowait = true, silent = true })
      end
    end
  end

  vim.defer_fn(reveal_next, 80)
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 11: Extract `ui/death.lua`

**Files:**
- Create: `lua/the-vimmer/ui/death.lua`

Copy `ui.lua` lines 1268–1319 (`M.open_death`). Same replacement scheme. The `M.open_key_replay` call (line 1312 in original) becomes lazy `require("the-vimmer.ui").open_key_replay(...)`.

- [ ] **Step 1: Create the file**

Path: `lua/the-vimmer/ui/death.lua`

```lua
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local float  = require("the-vimmer.ui.float")
-- NOTE: do NOT top-level-require "the-vimmer.ui" — circular load.

function M.open_death(room, on_retry, on_map, death_opts)
  death_opts = death_opts or {}
  local width = common.pick_float_width(float.FLOAT_DEATH_W)
  local b = common.make_border(width)
  local death_optimal_inner = math.max(28, width - 4)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("        YOU DIED"), "VimmerDeath")
  add(b.sep)
  if death_opts.timed_out then
    add(b.row("  Time ran out"), "VimmerTimerDanger")
  else
    add(b.row("  HP reached zero"), "VimmerDeath")
  end
  local over_budget = death_opts.over_budget_count or 0
  if over_budget > 0 then
    add(b.row(string.format("  Over-budget keys: %d", over_budget)), "VimmerLocked")
  end
  add(b.row("  Streak lost"))
  add(b.sep)
  add(b.row("  Optimal sequence:"), "VimmerTitle")
  for _, ln in ipairs(common.build_optimal_lines(room, death_optimal_inner)) do
    add(b.row(ln), "VimmerCommand")
  end
  add(b.sep)
  add(b.row("  <Enter> retry   <r> replay keys   <q> map"))
  add(b.bot)

  local buf, win = float.open_float(lines, width)
  float.apply_hl(buf, hls)

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_retry()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "r", function()
    require("the-vimmer.ui").open_key_replay(room, { phase_index = room.is_boss and 1 or nil })
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
    on_map()
  end, { buffer = buf, nowait = true, silent = true })
end

return M
```

- [ ] **Step 2: Do not commit. Move on.**

---

### Task 12: Create facade + delete old `ui.lua`

**Files:**
- Create: `lua/the-vimmer/ui/init.lua`
- Delete: `lua/the-vimmer/ui.lua`

This is the cutover step. Until both happen, `require("the-vimmer.ui")` resolves to the old `ui.lua`.

- [ ] **Step 1: Create the facade**

Path: `lua/the-vimmer/ui/init.lua`

```lua
-- Facade for the the-vimmer.ui submodules.
--
-- IMPORTANT: submodules must NOT top-level-require this file. Cross-screen
-- calls (e.g. teach → key_replay, death → key_replay) must use lazy
-- `require("the-vimmer.ui").open_<name>(...)` inside function bodies. A
-- top-level require here would trigger a circular load — init.lua is still
-- mid-require when the submodule loads, so the submodule would see an
-- empty table.
local M = {}

local function merge(name)
  for k, v in pairs(require("the-vimmer.ui." .. name)) do
    M[k] = v
  end
end

merge("key_replay")
merge("map")
merge("progress")
merge("teach")
merge("play")
merge("results")
merge("death")

return M
```

- [ ] **Step 2: Delete the old monolith**

Run: `rm lua/the-vimmer/ui.lua`
Expected: file gone. `git status` should show the deletion plus the new `lua/the-vimmer/ui/` tree.

- [ ] **Step 3: Do not commit. Move to Task 13 for verification.**

---

### Task 13: Verify + commit

**Files:** all changes from prior tasks.

This is the only commit step. Everything below must pass before committing.

- [ ] **Step 1: Run the full busted suite**

Run: `busted tests/spec/`
Expected: all specs pass — original specs (`game_spec`, `rooms_spec`, `progress_spec`, `highlights_spec`) plus the new `ui_common_spec`.

If any spec fails, the refactor has a regression. Diagnose against the line-range mapping in this plan — almost always the cause is a missed `common.` or `float.` qualifier on an internal call.

- [ ] **Step 2: Headless require smoke**

Run:
```bash
lua -e '
package.path = "lua/?.lua;lua/?/init.lua;" .. package.path
_G.vim = {
  trim = function(s) return s end,
  split = function() return {} end,
  fn = { strdisplaywidth = function(s) return #s end, strchars = function(s) return #s end, strcharpart = function(s,a,b) return s:sub(a+1,a+b) end },
  json = require("the-vimmer.json"),
}
local c = require("the-vimmer.ui.common")
assert(type(c.format_key) == "function", "common.format_key missing")
assert(type(c.make_border) == "function", "common.make_border missing")
print("ui.common ok")
'
```
Expected output: `ui.common ok`.

Note: `ui.float`, `ui.key_replay`, `ui.map`, etc. cannot be required headlessly — they touch `vim.api.nvim_create_namespace` etc. They are verified in Step 3.

- [ ] **Step 3: Manual smoke in Neovim**

In a Neovim session with the plugin loaded (e.g. `nvim --clean -u tests/minimal_init.lua` if one exists, or your regular dev config):

1. `:VimmerMap` — map screen renders; j/k navigates; `<Enter>` starts a room.
2. From map, pick a regular room → teach screen renders → `r` opens key replay → `<q>` closes replay → `<Enter>` starts play → solve the room → results screen renders with the line-by-line reveal → `<Enter>` returns to map.
3. From map, pick a boss room → teach renders for boss → `<Enter>` starts play → solve phase 1 → phase banner shows → solve phase 2 → results screen reflects boss clear.
4. Take damage until death (or let timer expire) → death screen renders → `r` opens key replay from death → `<q>` returns to map.
5. `:VimmerProgress` — progress screen renders with all tiers, mutators, suggested drill.

All screens must look pixel-identical to behavior before the refactor. Any visual difference is a bug.

- [ ] **Step 4: Stage and commit**

Run:
```bash
git add lua/the-vimmer/ui lua/the-vimmer/ui.lua tests/spec/helpers.lua tests/spec/ui_common_spec.lua
git status
```
Expected: `lua/the-vimmer/ui.lua` shown as deleted; new `lua/the-vimmer/ui/` files shown as added; `tests/spec/helpers.lua` shown as modified; `tests/spec/ui_common_spec.lua` shown as added.

Run:
```bash
git commit -m "$(cat <<'EOF'
refactor(ui): split ui.lua into per-screen submodules

Replaces the 1321-line lua/the-vimmer/ui.lua with a lua/the-vimmer/ui/
directory: common.lua (pure helpers), float.lua (window primitives +
width constants), and one file per screen (key_replay, map, progress,
teach, play, results, death) behind an init.lua facade.

Public API unchanged for commands.lua. _show_phase_banner becomes
module-local in play.lua (no external callers). Adds ui_common_spec
covering pure helpers headlessly.
EOF
)"
```
Expected: commit lands on top of the current head with the message above.

- [ ] **Step 5: Final sanity**

Run: `git log --oneline -3`
Expected: top entry is the refactor commit; second is `faccd86 docs: ui module split (sub-project 6b) design spec`.

Run: `git status`
Expected: clean working tree.

---

## Self-Review Notes

Coverage check:

- Spec "Module layout" → Tasks 2–12 create every listed file.
- Spec "common.lua" exports → Task 2 covers all 13 (incl. `MUTATOR_TEACH`).
- Spec "float.lua" exports → Task 4 covers all 9.
- Spec "Screen modules" mapping table → Tasks 5–11 follow line ranges exactly.
- Spec "Cross-screen calls" → Tasks 8 (teach) and 11 (death) use lazy require; Task 12's init.lua explains the rule in a comment.
- Spec "Tests" table → Task 3's `ui_common_spec.lua` covers every named helper.
- Spec "Verification" → Task 13 runs busted, headless require, and the manual smoke list.
- Spec "Edge cases / `_show_phase_banner` becomes module-local" → Task 9 implements; spec Goals section already updated.

Placeholders: none in tasks. No "TODO", "fill in", or "implement as needed".

Type consistency: all submodule calls use the same prefixes — `common.foo` for pure helpers, `float.foo` for primitives, `require("the-vimmer.ui").open_*` for lazy cross-screen calls. No naming drift.

Scope: one commit, ~10 new files, one deletion, one test helper edit, one new spec. Plan length matches scope.
