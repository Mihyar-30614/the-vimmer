-- Standalone reachability harness. Invoke with:
--   nvim --headless --noplugin -l tests/reachability.lua
-- Exits 0 if every checked room's primary + alternate keystroke sequences reach target_text.
-- Exits 1 with per-failure lines on stderr otherwise.
--
-- A room (or boss phase) is checked only when its context has a `goal` field set.
-- Legacy rooms (pre-real-world redesign) encode optimal_keystrokes as fragments for
-- budget calculation; buffer-match drives wins. Those rooms are exempt from the harness.
-- Pass `--all` to force-check every room regardless of goal presence.

local function script_root()
  local src = debug.getinfo(1, "S").source:match("^@(.+)/tests/reachability%.lua$")
  return src or "."
end

local root = script_root()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local rooms = require("the-vimmer.rooms")
local api = vim.api

local TIERS = { "beginner", "warrior", "ninja" }

-- Run one keystroke sequence against a freshly-prepared buffer.
-- Returns (ok, actual_text).
local function run_sequence(ctx, sequence)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(buf, "buftype", "nofile")
  api.nvim_buf_set_option(buf, "swapfile", false)

  if type(ctx.bo) == "table" then
    for k, v in pairs(ctx.bo) do vim.bo[buf][k] = v end
  end
  if ctx.filetype and ctx.filetype ~= "" then
    vim.bo[buf].filetype = ctx.filetype
  end

  local lines = vim.split(ctx.start_text, "\n", { plain = true })
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = 0, col = 0, width = 80, height = 25,
    style = "minimal",
  })

  local cs = ctx.cursor_start or { row = 1, col = 1 }
  pcall(api.nvim_win_set_cursor, win, { cs.row, cs.col - 1 })

  -- Feed keys. 'nx' = no remapping, execute now (drain typeahead before returning).
  api.nvim_feedkeys(table.concat(sequence), "nx", false)

  local actual = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
  local target = ctx.target_text
  local function rtrim_nl(s) return (s:gsub("\n+$", "")) end
  local ok = rtrim_nl(actual) == rtrim_nl(target)

  api.nvim_win_close(win, true)
  return ok, actual
end

local force_all = false
for _, a in ipairs(arg or {}) do
  if a == "--all" then force_all = true end
end

local failures = {}
local checked = 0
local skipped = 0

local function check_ctx(label, ctx)
  if not force_all and (ctx.goal == nil or ctx.goal == "") then
    skipped = skipped + 1
    return
  end
  checked = checked + 1
  local seqs = rooms.acceptable_key_sequences(ctx)
  for i, seq in ipairs(seqs) do
    local kind = (i == 1) and "primary" or ("alternate#" .. (i - 1))
    local ok, actual = run_sequence(ctx, seq)
    if not ok then
      failures[#failures + 1] = {
        label = label, kind = kind, expected = ctx.target_text, actual = actual,
        sequence = table.concat(seq, ""),
      }
    end
  end
end

for _, tier in ipairs(TIERS) do
  for _, room in ipairs(rooms.load_tier(tier)) do
    if room.is_boss then
      for i, phase in ipairs(room.phases) do
        check_ctx(room.id .. "#phase" .. i, phase)
      end
    else
      check_ctx(room.id, room)
    end
  end
end

if #failures == 0 then
  io.stdout:write(string.format(
    "reachability: %d checked, %d skipped (no goal), all sequences pass\n",
    checked, skipped))
  os.exit(0)
else
  io.stderr:write(string.format(
    "reachability: %d failure(s) (%d checked, %d skipped)\n",
    #failures, checked, skipped))
  for _, f in ipairs(failures) do
    io.stderr:write(string.format("\n[%s %s] sequence=%q\n", f.label, f.kind, f.sequence))
    io.stderr:write("  expected:\n")
    for line in (f.expected or ""):gmatch("[^\n]*") do
      io.stderr:write("    | " .. line .. "\n")
    end
    io.stderr:write("  actual:\n")
    for line in (f.actual or ""):gmatch("[^\n]*") do
      io.stderr:write("    | " .. line .. "\n")
    end
  end
  os.exit(1)
end
