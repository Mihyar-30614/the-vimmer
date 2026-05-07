# Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add colors, animated win/death screens, redesigned layouts, and a death float to the-vimmer — making the game feel vibrant and alive.

**Architecture:** New `highlights.lua` module owns all highlight group definitions and the pure `hp_group(hp)` function. `ui.lua` gains `apply_hl`, `flash`, and `open_death` helpers; all screens widen to 60 chars and receive highlight passes after line writes. Flash + defer-based animation drives win reveal and death effects.

**Tech Stack:** Lua 5.1, Neovim API (`nvim_buf_add_highlight`, `nvim_buf_set_extmark`, `vim.defer_fn`), busted (test runner at `/home/mihyar/.luarocks/bin/busted`)

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Create | `lua/the-vimmer/highlights.lua` | All hl group definitions + `hp_group(hp)` |
| Create | `tests/spec/highlights_spec.lua` | Tests for `hp_group` |
| Modify | `lua/the-vimmer/init.lua` | Call `highlights.setup()` on plugin load |
| Modify | `lua/the-vimmer/ui.lua` | All screen changes, helpers, open_death |
| Modify | `lua/the-vimmer/commands.lua` | Wire open_death, remove vim.notify from on_death |

---

### Task 1: Create `highlights.lua`

**Files:**
- Create: `lua/the-vimmer/highlights.lua`

- [ ] **Step 1: Create the file**

```lua
local M = {}

function M.hp_group(hp)
  if hp > 60 then return "VimmerHP_high"
  elseif hp > 30 then return "VimmerHP_mid"
  else return "VimmerHP_low" end
end

function M.setup()
  local hl = vim.api.nvim_set_hl
  hl(0, "VimmerTitle",        { bold = true, fg = "#ffffff" })
  hl(0, "VimmerTierBeginner", { bold = true, fg = "#8be9fd" })
  hl(0, "VimmerTierWarrior",  { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTierNinja",    { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerCleared",      { fg = "#50fa7b" })
  hl(0, "VimmerLocked",       { fg = "#6272a4" })
  hl(0, "VimmerSelected",     { bold = true, reverse = true })
  hl(0, "VimmerXP",           { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerHP_high",      { fg = "#50fa7b" })
  hl(0, "VimmerHP_mid",       { fg = "#ffb86c" })
  hl(0, "VimmerHP_low",       { fg = "#ff5555" })
  hl(0, "VimmerWin",          { bg = "#50fa7b", fg = "#282a36" })
  hl(0, "VimmerDeath",        { bold = true, fg = "#ff5555" })
  hl(0, "VimmerCommand",      { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerExample",      { fg = "#8be9fd" })
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add lua/the-vimmer/highlights.lua
git commit -m "feat: add highlights module with group definitions"
```

---

### Task 2: Test `hp_group`

**Files:**
- Create: `tests/spec/highlights_spec.lua`

- [ ] **Step 1: Write the failing test**

`hp_group` doesn't exist yet so this is just confirming the interface. Note: `highlights.lua` must NOT be called with `setup()` here — that calls `vim.api` which isn't stubbed in tests. Only call `hp_group`.

```lua
-- tests/spec/highlights_spec.lua
dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local hl = require("the-vimmer.highlights")

describe("highlights.hp_group", function()
  it("returns VimmerHP_high above 60", function()
    assert.equals("VimmerHP_high", hl.hp_group(100))
    assert.equals("VimmerHP_high", hl.hp_group(61))
  end)

  it("returns VimmerHP_mid between 31 and 60 inclusive", function()
    assert.equals("VimmerHP_mid", hl.hp_group(60))
    assert.equals("VimmerHP_mid", hl.hp_group(31))
  end)

  it("returns VimmerHP_low at 30 and below", function()
    assert.equals("VimmerHP_low", hl.hp_group(30))
    assert.equals("VimmerHP_low", hl.hp_group(0))
  end)
end)
```

- [ ] **Step 2: Run the tests**

```
/home/mihyar/.luarocks/bin/busted
```

Expected: `44 successes / 0 failures / 0 errors`

- [ ] **Step 3: Commit**

```bash
git add tests/spec/highlights_spec.lua
git commit -m "test: add hp_group unit tests"
```

---

### Task 3: Wire highlights into `init.lua`

**Files:**
- Modify: `lua/the-vimmer/init.lua:5`

- [ ] **Step 1: Add `highlights.setup()` call**

Replace the entire file (it's tiny):

```lua
local M = {}

function M.setup(opts)
  opts = opts or {}
  require("the-vimmer.highlights").setup()
  require("the-vimmer.commands").register()
end

return M
```

- [ ] **Step 2: Run tests to confirm nothing broke**

```
/home/mihyar/.luarocks/bin/busted
```

Expected: `44 successes / 0 failures / 0 errors`

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/init.lua
git commit -m "feat: call highlights.setup() on plugin load"
```

---

### Task 4: Add `apply_hl`, `flash`, and `_flash_ns` to `ui.lua`

**Files:**
- Modify: `lua/the-vimmer/ui.lua` (after line 45, after `open_float`)

- [ ] **Step 1: Insert helpers after `open_float`**

After the closing `end` of `open_float` (line 45), insert:

```lua
local _flash_ns = api.nvim_create_namespace("the-vimmer-flash")

local function apply_hl(buf, highlights)
  for _, h in ipairs(highlights) do
    api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
  end
end

local function flash(buf, group, callback)
  local n = api.nvim_buf_line_count(buf)
  for i = 0, n - 1 do
    api.nvim_buf_add_highlight(buf, _flash_ns, group, i, 0, -1)
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, _flash_ns, 0, -1)
    end
    callback()
  end, 100)
end
```

- [ ] **Step 2: Run tests**

```
/home/mihyar/.luarocks/bin/busted
```

Expected: `44 successes / 0 failures / 0 errors`

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add apply_hl and flash helpers to ui"
```

---

### Task 5: Widen all screens from 50 to 60

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Update `open_map` width**

In `open_map`, change:
```lua
  local width = 50
```
to:
```lua
  local width = 60
```

- [ ] **Step 2: Update `open_teach` width and wrap**

In `open_teach`, change:
```lua
  local width = 50
```
to:
```lua
  local width = 60
```

And change the wrap guard (two occurrences in the while loop):
```lua
  while #tip > 46 do
    local cut = tip:sub(1, 46):match("^(.+) ")
    lines[#lines+1] = b.row("  " .. (cut or tip:sub(1, 46)))
    tip = tip:sub(#(cut or tip:sub(1, 46)) + 2)
  end
```
to:
```lua
  while #tip > 56 do
    local cut = tip:sub(1, 56):match("^(.+) ")
    lines[#lines+1] = b.row("  " .. (cut or tip:sub(1, 56)))
    tip = tip:sub(#(cut or tip:sub(1, 56)) + 2)
  end
```

- [ ] **Step 3: Update `open_results` width**

In `open_results`, change:
```lua
  local width = 50
```
to:
```lua
  local width = 60
```

- [ ] **Step 4: Run tests**

```
/home/mihyar/.luarocks/bin/busted
```

Expected: `44 successes / 0 failures / 0 errors`

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: widen all UI screens from 50 to 60 chars"
```

---

### Task 6: Colorize `open_map`

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — replace `open_map` body

- [ ] **Step 1: Replace `open_map` with colorized version**

Replace the entire `open_map` function (lines 47–131):

```lua
function M.open_map(progress_data, rooms_by_tier, on_select)
  progress_data = progress_data or {}
  progress_data.total_xp = progress_data.total_xp or 0
  progress_data.cleared = progress_data.cleared or {}

  local width = 60
  local b = make_border(width)
  local bar = xp_bar(progress_data.total_xp, 6)
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
  local tier_prereq = { warrior = "complete 80% of beginner", ninja = "complete 80% of warrior" }
  local tiers = { "beginner", "warrior", "ninja" }

  add(b.top)
  add(b.row(string.format("  THE VIMMER                     XP:%-5d %s",
    progress_data.total_xp, bar)), "VimmerTitle")
  add(b.sep)

  for ti, tier in ipairs(tiers) do
    local tier_rooms = rooms_by_tier[tier] or {}
    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      add(b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      add(b.row(string.format("  [%s]", tier_labels[tier])), tier_colors[tier])
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, 46))
        if cleared then
          add(b.row(label), "VimmerCleared")
        else
          add(b.row(label))
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
    end
    if ti < #tiers then add(b.row("")) end
  end

  add(b.sep)
  add(b.row("  <Enter> play   j/k navigate   <q> quit"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  local _sel_ns = api.nvim_create_namespace("the-vimmer-sel")
  local cur_idx = 1

  local function update_selection()
    api.nvim_buf_clear_namespace(buf, _sel_ns, 0, -1)
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
    cur_idx = math.min(cur_idx + 1, #selectable)
    update_selection()
  end)

  map_key("k", function()
    cur_idx = math.max(cur_idx - 1, 1)
    update_selection()
  end)

  map_key("<CR>", function()
    if selectable[cur_idx] then
      local room = selectable[cur_idx].room
      api.nvim_win_close(win, true)
      on_select(room)
    end
  end)

  map_key("q", function()
    api.nvim_win_close(win, true)
  end)
end
```

- [ ] **Step 2: Manual test** — Run `:VimmerPlay` in Neovim. Verify:
  - Map opens at width 60
  - Title row is white/bold
  - Tier headers are cyan/orange/pink
  - Cleared rooms are green
  - Locked tiers are grey
  - Selected room has reverse highlight; j/k moves it

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: colorize map screen with tier and room highlights"
```

---

### Task 7: Colorize `open_teach`

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — replace `open_teach` body

- [ ] **Step 1: Replace `open_teach` with colorized version**

Replace the entire `open_teach` function (lines 133–167 in the original; find it by `function M.open_teach`):

```lua
function M.open_teach(room, on_begin)
  local width = 60
  local b = make_border(width)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("  COMMAND: " .. room.command:gsub("\n", " ↵ ")), "VimmerCommand")
  add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
  add(b.sep)
  add(b.row("  BEFORE:  " .. room.before_example:gsub("\n", " ↵ ")), "VimmerLocked")
  add(b.row("  AFTER:   " .. room.after_example:gsub("\n", " ↵ ")), "VimmerCleared")
  add(b.row(""))
  local tip = room.usage_tip
  while #tip > 56 do
    local cut = tip:sub(1, 56):match("^(.+) ")
    add(b.row("  " .. (cut or tip:sub(1, 56))))
    tip = tip:sub(#(cut or tip:sub(1, 56)) + 2)
  end
  if #tip > 0 then add(b.row("  " .. tip)) end
  add(b.sep)
  add(b.row("  <Enter> to begin   <q> back"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  -- highlight | cursor marker in BEFORE and AFTER rows (line indices 4 and 5)
  for _, li in ipairs({ 4, 5 }) do
    local row = lines[li + 1]  -- lines is 1-indexed; li is 0-indexed
    if row then
      local pipe = row:find("|", 1, true)
      if pipe then
        api.nvim_buf_add_highlight(buf, 0, "VimmerExample", li, pipe - 1, pipe)
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

- [ ] **Step 2: Manual test** — Run `:VimmerPlay`, select any room. Verify:
  - Command key is bold yellow
  - Description is white
  - BEFORE row is grey/dim
  - AFTER row is green
  - `|` cursor marker glows cyan in BEFORE/AFTER

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: colorize teach screen with command and example highlights"
```

---

### Task 8: Update play screen — winbar headers and HP color

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — update `open_play`

- [ ] **Step 1: Add winbar headers after windows are set up**

In `open_play`, after these existing lines:
```lua
  api.nvim_set_current_win(play_win)
```
add:
```lua
  vim.wo[top_win].winbar  = "%#VimmerCleared# ── TARGET ──%*"
  vim.wo[play_win].winbar = "%#VimmerTierWarrior# ── EDIT HERE ──%*"
```

- [ ] **Step 2: Update `update_hud` to use color groups**

Replace the existing `update_hud` function inside `open_play`:
```lua
  local function update_hud()
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    vim.wo[play_win].statusline = string.format(
      " HP [%s] %d  |  Streak %d  |  %s",
      hp_bar, game_state.hp, game_state.streak, room.command
    )
  end
```
with:
```lua
  local function update_hud()
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    local hp_grp = require("the-vimmer.highlights").hp_group(game_state.hp)
    vim.wo[play_win].statusline = string.format(
      " %%#%s#HP [%s] %d%%*  |  Streak %d  |  %s",
      hp_grp, hp_bar, game_state.hp, game_state.streak, room.command
    )
  end
```

- [ ] **Step 3: Add flash on win and death inside the `vim.on_key` callback**

Find the win detection block inside `open_play`:
```lua
    vim.schedule(function()
      if not api.nvim_buf_is_valid(play_buf) then return end
      local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
      local target = table.concat(target_lines, "\n")
      if vim.trim(current) == vim.trim(target) then
        vim.on_key(nil, ns)
        on_win(game_state.hp)
      end
    end)
```
Replace with:
```lua
    vim.schedule(function()
      if not api.nvim_buf_is_valid(play_buf) then return end
      local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
      local target = table.concat(target_lines, "\n")
      if vim.trim(current) == vim.trim(target) then
        vim.on_key(nil, ns)
        flash(play_buf, "VimmerWin", function() on_win(game_state.hp) end)
      end
    end)
```

Find the death detection block inside `open_play`:
```lua
    if game_state:is_dead() then
      vim.on_key(nil, ns)
      vim.schedule(function() on_death() end)
      return
    end
```
Replace with:
```lua
    if game_state:is_dead() then
      vim.on_key(nil, ns)
      vim.schedule(function() flash(play_buf, "VimmerDeath", on_death) end)
      return
    end
```

- [ ] **Step 4: Manual test** — Run `:VimmerPlay` and enter a room. Verify:
  - "── TARGET ──" winbar appears above top split (green)
  - "── EDIT HERE ──" winbar appears above play split (orange)
  - HP bar in statusline starts green; make mistakes to watch it turn orange then red
  - Completing the room flashes green briefly before the results screen
  - Dying (100 wrong keys) flashes red briefly

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add winbar headers and HP color to play screen"
```

---

### Task 9: Animate `open_results`

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — replace `open_results` body

- [ ] **Step 1: Replace `open_results` with animated version**

Replace the entire `open_results` function (find it by `function M.open_results`):

```lua
function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue)
  local width = 60
  local b = make_border(width)
  local all_lines = {}
  local hls = {}

  local function add(content, group)
    all_lines[#all_lines+1] = content
    if group then hls[#hls+1] = { group, #all_lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("  ROOM CLEARED!"), "VimmerWin")
  add(b.sep)
  add(b.row(string.format("  XP Earned:     +%d", xp_earned)), "VimmerXP")
  add(b.row(string.format("  HP Remaining:  %d / 100", hp_remaining)), "VimmerTitle")
  add(b.row(string.format("  Streak:        %d", streak)), "VimmerTierWarrior")

  if unlocked_tier then
    local tier_name = unlocked_tier:lower()
    local tier_grp = ({ warrior = "VimmerTierWarrior", ninja = "VimmerTierNinja" })[tier_name]
      or "VimmerTierBeginner"
    add(b.sep)
    add(b.row("  NEW TIER UNLOCKED:"), "VimmerTitle")
    add(b.row("  " .. unlocked_tier), tier_grp)
  end

  add(b.sep)
  add(b.row("  <Enter> next room   <q> map"))
  add(b.bot)

  local empty = {}
  for _ = 1, #all_lines do empty[#empty+1] = "" end
  local buf, win = open_float(empty, width)

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
      vim.keymap.set("n", "<CR>", function()
        api.nvim_win_close(win, true)
        on_continue(false)
      end, { buffer = buf, nowait = true, silent = true })
      vim.keymap.set("n", "q", function()
        api.nvim_win_close(win, true)
        on_continue(true)
      end, { buffer = buf, nowait = true, silent = true })
    end
  end

  vim.defer_fn(reveal_next, 80)
end
```

- [ ] **Step 2: Manual test** — Complete a room. Verify:
  - Results screen lines build up one-by-one with a brief delay between each
  - "ROOM CLEARED!" row is highlighted green
  - XP number is gold, streak is orange
  - `<Enter>` and `q` only work after all lines are revealed
  - If a new tier is unlocked the tier name appears in its tier color

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: animate results screen with line-by-line reveal"
```

---

### Task 10: Add `open_death` to `ui.lua`

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — add `open_death` before `return M`

- [ ] **Step 1: Add `open_death` at end of `ui.lua`, before `return M`**

```lua
function M.open_death(room, on_retry, on_map)
  local width = 40
  local b = make_border(width)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  add(b.row("        YOU DIED"), "VimmerDeath")
  add(b.sep)
  add(b.row("  HP reached zero"))
  add(b.row("  Streak lost"))
  add(b.sep)
  add(b.row("  <Enter> retry   <q> map"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_retry()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
    on_map()
  end, { buffer = buf, nowait = true, silent = true })
end
```

- [ ] **Step 2: Run tests**

```
/home/mihyar/.luarocks/bin/busted
```

Expected: `44 successes / 0 failures / 0 errors`

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add open_death float to ui"
```

---

### Task 11: Wire `open_death` into `commands.lua`

**Files:**
- Modify: `lua/the-vimmer/commands.lua:80-88`

- [ ] **Step 1: Replace `on_death` body**

Find and replace the `on_death` function inside `start_flow`:

Old:
```lua
  local function on_death()
    d.ui._close_play()
    g:retry_room()
    prog.streak = 0
    d.progress.save(prog)
    vim.notify("the-vimmer: 0 HP — retrying room...", vim.log.levels.INFO)
    start_flow(room)
  end
```

New:
```lua
  local function on_death()
    d.ui._close_play()
    g:retry_room()
    prog.streak = 0
    d.progress.save(prog)
    d.ui.open_death(room,
      function() start_flow(room) end,
      show_map
    )
  end
```

- [ ] **Step 2: Run tests**

```
/home/mihyar/.luarocks/bin/busted
```

Expected: `44 successes / 0 failures / 0 errors`

- [ ] **Step 3: Manual test** — In Neovim, run `:VimmerPlay` and intentionally drain HP to 0 (press random keys repeatedly). Verify:
  - Red flash on play buffer
  - Play tab closes
  - "YOU DIED" float opens with red title
  - `<Enter>` restarts the teach screen for the same room
  - `q` returns to map

- [ ] **Step 4: Commit**

```bash
git add lua/the-vimmer/commands.lua
git commit -m "feat: replace vim.notify death with open_death float"
```
