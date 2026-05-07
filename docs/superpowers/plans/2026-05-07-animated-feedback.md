# Animated Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four animated feedback effects — HP damage/regen flash, keystroke crit highlight, combo pop-up text, and multi-step death/win animation — to make gameplay feel more responsive.

**Architecture:** All changes stay inside `ui.lua` and `highlights.lua`. `flash()` gains a duration param. A new `multi_flash()` helper chains sequential flash steps. `combo_group()` in `highlights.lua` is a pure function (testable without Neovim) that maps combo count to a highlight group name.

**Tech Stack:** Lua, Neovim API (`nvim_buf_add_highlight`, `nvim_buf_clear_namespace`, `vim.defer_fn`, `vim.on_key`), busted (tests)

---

## File Map

| File | Change |
|------|--------|
| `tests/spec/highlights_spec.lua` | Add `combo_group` tests |
| `lua/the-vimmer/highlights.lua` | Add `combo_group()` function + 5 new hl groups in `M.setup()` |
| `lua/the-vimmer/ui.lua` | Extend `flash()`, add `multi_flash()`, update `update_hud()`, update `start_phase()`, add `_crit_ns` in `open_play()` |

---

## Task 1: TDD — combo_group() function

**Files:**
- Modify: `tests/spec/highlights_spec.lua`
- Modify: `lua/the-vimmer/highlights.lua`

- [ ] **Step 1: Add failing tests for combo_group**

Append to `tests/spec/highlights_spec.lua` (after the existing `timer_group` tests if present, else after the last `end`):

```lua
describe("highlights.combo_group", function()
  it("returns nil below combo 5", function()
    assert.is_nil(hl.combo_group(0))
    assert.is_nil(hl.combo_group(4))
  end)

  it("returns VimmerPhase at combo 5-9", function()
    assert.equals("VimmerPhase", hl.combo_group(5))
    assert.equals("VimmerPhase", hl.combo_group(9))
  end)

  it("returns VimmerComboFire at combo 10-19", function()
    assert.equals("VimmerComboFire", hl.combo_group(10))
    assert.equals("VimmerComboFire", hl.combo_group(19))
  end)

  it("returns VimmerComboCrit at combo 20+", function()
    assert.equals("VimmerComboCrit", hl.combo_group(20))
    assert.equals("VimmerComboCrit", hl.combo_group(100))
  end)
end)
```

- [ ] **Step 2: Run tests — expect failure**

```bash
~/.luarocks/bin/busted tests/spec/highlights_spec.lua
```

Expected: 4 failures — `attempt to call a nil value (field 'combo_group')`

- [ ] **Step 3: Add combo_group() to highlights.lua**

In `lua/the-vimmer/highlights.lua`, add after `M.timer_group` (before `M.setup`):

```lua
function M.combo_group(combo)
  if combo >= 20 then return "VimmerComboCrit"
  elseif combo >= 10 then return "VimmerComboFire"
  elseif combo >= 5 then return "VimmerPhase"
  else return nil end
end
```

- [ ] **Step 4: Run tests — expect pass**

```bash
~/.luarocks/bin/busted tests/spec/highlights_spec.lua
```

Expected: all pass, 0 failures

- [ ] **Step 5: Commit**

```bash
git add tests/spec/highlights_spec.lua lua/the-vimmer/highlights.lua
git commit -m "feat: add combo_group() function with tests"
```

---

## Task 2: Add 5 new highlight groups

**Files:**
- Modify: `lua/the-vimmer/highlights.lua` — `M.setup()` function

- [ ] **Step 1: Add highlight definitions to M.setup()**

In `lua/the-vimmer/highlights.lua`, inside `M.setup()`, append after the last `hl(...)` call (after the `VimmerPhase` line):

```lua
  hl(0, "VimmerDamage",    { bg = "#5c1010", fg = "#ff8080" })
  hl(0, "VimmerRegen",     { bg = "#0d3b1a", fg = "#80ff99" })
  hl(0, "VimmerCrit",      { bg = "#5c4a00", fg = "#ffd700" })
  hl(0, "VimmerComboFire", { bold = true,    fg = "#ff8c00" })
  hl(0, "VimmerComboCrit", { bold = true,    fg = "#ff00cc" })
```

- [ ] **Step 2: Run full test suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass (the `M.setup()` call is not exercised in unit tests since it needs Neovim API, so no test failures)

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/highlights.lua
git commit -m "feat: add VimmerDamage/Regen/Crit/ComboFire/ComboCrit highlight groups"
```

---

## Task 3: Extend flash() and add multi_flash()

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — `flash()` function (line ~37), add `multi_flash()` after it

- [ ] **Step 1: Replace flash() with duration-aware version**

In `lua/the-vimmer/ui.lua`, replace the entire `flash` function (lines 37–48):

```lua
-- OLD:
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

```lua
-- NEW:
local function flash(buf, group, duration, callback)
  local n = api.nvim_buf_line_count(buf)
  for i = 0, n - 1 do
    api.nvim_buf_add_highlight(buf, _flash_ns, group, i, 0, -1)
  end
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, _flash_ns, 0, -1)
    end
    if callback then callback() end
  end, duration or 100)
end
```

- [ ] **Step 2: Add multi_flash() immediately after flash()**

In `lua/the-vimmer/ui.lua`, after the `flash` function and before `open_float`, insert:

```lua
local function multi_flash(buf, steps, callback)
  local function run(i)
    if i > #steps then
      if callback then callback() end
      return
    end
    local group, duration = steps[i][1], steps[i][2]
    if group and api.nvim_buf_is_valid(buf) then
      local n = api.nvim_buf_line_count(buf)
      for row = 0, n - 1 do
        api.nvim_buf_add_highlight(buf, _flash_ns, group, row, 0, -1)
      end
    end
    vim.defer_fn(function()
      if api.nvim_buf_is_valid(buf) then
        api.nvim_buf_clear_namespace(buf, _flash_ns, 0, -1)
      end
      run(i + 1)
    end, duration)
  end
  run(1)
end
```

- [ ] **Step 3: Run test suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: extend flash() with duration param, add multi_flash() helper"
```

---

## Task 4: Replace win/death flash call sites with multi_flash

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — 4 call sites inside `open_play()`

- [ ] **Step 1: Replace timer death flash (line ~403)**

In `start_timer()`, replace:

```lua
        flash(play_buf, "VimmerDeath", on_death)
```

With:

```lua
        multi_flash(play_buf, {
          { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
        }, on_death)
```

- [ ] **Step 2: Replace on_key death flash (line ~431)**

In `start_phase()` `vim.on_key` callback, replace:

```lua
        vim.schedule(function() flash(play_buf, "VimmerDeath", on_death) end)
```

With:

```lua
        vim.schedule(function()
          multi_flash(play_buf, {
            { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
          }, on_death)
        end)
```

- [ ] **Step 3: Replace on_key win flash — last phase (line ~446)**

Replace:

```lua
            flash(play_buf, "VimmerWin", function() on_win() end)
```

With:

```lua
            multi_flash(play_buf, {
              { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 }
            }, on_win)
```

- [ ] **Step 4: Replace on_key win flash — boss phase advance (lines ~448–454)**

Replace:

```lua
            flash(play_buf, "VimmerWin", function()
              game_state:advance_boss_phase()
              local next_phase = game_state.boss_phase
              M._show_phase_banner(play_win, next_phase, function()
                start_phase(room.phases[next_phase])
              end)
            end)
```

With:

```lua
            multi_flash(play_buf, {
              { "VimmerWin", 150 }, { "VimmerCrit", 150 }, { "VimmerWin", 150 }
            }, function()
              game_state:advance_boss_phase()
              local next_phase = game_state.boss_phase
              M._show_phase_banner(play_win, next_phase, function()
                start_phase(room.phases[next_phase])
              end)
            end)
```

- [ ] **Step 5: Run test suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: replace win/death flash with multi-step animation sequences"
```

---

## Task 5: HP damage/regen flash + keystroke crit highlight

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — `open_play()` setup + `start_phase()` `vim.on_key` callback

- [ ] **Step 1: Add _crit_ns namespace in open_play()**

In `open_play()`, after the `_hud_ns` line (line ~290), add:

```lua
  local _crit_ns = api.nvim_create_namespace("the-vimmer-crit")
```

Result:

```lua
  local _hud_ns = api.nvim_create_namespace("the-vimmer-hud")
  local _crit_ns = api.nvim_create_namespace("the-vimmer-crit")
```

- [ ] **Step 2: Replace the register_key block in vim.on_key callback**

In `start_phase()`, inside `vim.on_key`, replace:

```lua
      game_state:register_key(key)
      update_hud()

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.schedule(function()
          multi_flash(play_buf, {
            { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
          }, on_death)
        end)
        return
      end
```

With:

```lua
      local prev_streak = game_state.correct_streak
      game_state:register_key(key)
      local is_correct = game_state.correct_streak > prev_streak
      local regen_tick = is_correct and (game_state.correct_streak % 3 == 0)
      update_hud()

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.schedule(function()
          multi_flash(play_buf, {
            { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
          }, on_death)
        end)
        return
      end

      if not is_correct then
        flash(play_buf, "VimmerDamage", 80)
      elseif regen_tick then
        flash(play_buf, "VimmerRegen", 80)
      end

      if is_correct and api.nvim_win_is_valid(play_win) then
        local row = api.nvim_win_get_cursor(play_win)[1] - 1
        api.nvim_buf_add_highlight(play_buf, _crit_ns, "VimmerCrit", row, 0, -1)
        vim.defer_fn(function()
          if api.nvim_buf_is_valid(play_buf) then
            api.nvim_buf_clear_namespace(play_buf, _crit_ns, 0, -1)
          end
        end, 120)
      end
```

- [ ] **Step 3: Run test suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add HP damage/regen flash and keystroke crit highlight"
```

---

## Task 6: Combo pop-up text in HUD

**Files:**
- Modify: `lua/the-vimmer/ui.lua` — `update_hud()` combo section (lines ~356–359)

- [ ] **Step 1: Replace combo section in update_hud()**

In `update_hud()`, replace:

```lua
    if game_state.combo_mult > 1 then
      lines[#lines+1] = string.format(" Combo  x%d", game_state.combo_mult)
      hls[#hls+1] = { "VimmerPhase", #lines - 1, 1, -1 }
    end
```

With:

```lua
    local combo_grp = hl.combo_group(game_state.combo)
    if combo_grp then
      local combo_text
      if game_state.combo >= 20 then
        combo_text = " 💀 UNSTOPPABLE"
      elseif game_state.combo >= 10 then
        combo_text = " 🔥 ON FIRE!"
      else
        combo_text = string.format(" ⚡ x%d COMBO!", game_state.combo_mult)
      end
      lines[#lines+1] = combo_text
      hls[#hls+1] = { combo_grp, #lines - 1, 1, -1 }
    end
```

- [ ] **Step 2: Run test suite — expect no regressions**

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected: all tests pass

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: add combo pop-up text in HUD (x2 COMBO, ON FIRE, UNSTOPPABLE)"
```

---

## Verification

After all tasks complete, run:

```bash
~/.luarocks/bin/busted tests/spec/
```

Expected output: all suites pass, 0 failures, 0 errors.

Manual smoke test in Neovim:
1. `:VimmerPlay beginner_hjkl` — press wrong key → red flash on play buffer
2. Press 3 correct keys in a row → green flash (regen)
3. Press correct key → gold line highlight (120ms)
4. Clear room quickly → green/gold/green win animation
5. Let HP reach 0 → red/pause/dark-red death animation
6. Play any room, build combo to 5 → HUD shows `⚡ x2 COMBO!`
7. Build combo to 10 → HUD shows `🔥 ON FIRE!`
8. Build combo to 20 → HUD shows `💀 UNSTOPPABLE`
