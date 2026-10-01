-- Pure formatting and layout helpers for the-vimmer's UI screens.
-- No side effects on Neovim state. Safe to require headlessly.
local M = {}
local icons = require("the-vimmer.ui.icons")

M.MUTATOR_TEACH = {
  iron = "Iron",
  glass = "Glass",
  rush = "Rush",
}

function M.pick_float_width(desired)
  local margin = 4
  local max_w = math.max(4, vim.o.columns - margin)
  return math.min(desired, max_w)
end

-- Measure terminal cells, preserving complete UTF-8 characters.
function M.truncate(s, max_len)
  s = s or ""
  max_len = math.max(0, max_len)
  if vim.fn.strdisplaywidth(s) <= max_len then return s end
  local suffix = max_len > 3 and "..." or ""
  local budget = max_len - #suffix
  local out = ""
  for i = 1, vim.fn.strchars(s) do
    local next_char = vim.fn.strcharpart(s, i - 1, 1)
    if vim.fn.strdisplaywidth(out .. next_char) > budget then break end
    out = out .. next_char
  end
  return out .. suffix
end

function M.reduced_motion()
  local root = package.loaded["the-vimmer"]
  return root and root.config and root.config.reduced_motion == true
end

function M.clean_title(title)
  return (title or ""):gsub("^BOSS:%s*", ""):gsub("^Phase %d+:%s*", "")
end

-- Fill a box row with left and right text separated by spaces.
-- `indent` defaults to two spaces; total row width includes border columns.
function M.spread_row(left, right, width, indent)
  indent = indent or "  "
  left = indent .. (left or "")
  right = right or ""
  local inner = width - 2
  right = M.truncate(right, math.max(0, math.floor(inner * 0.55)))
  left = M.truncate(left, math.max(0, inner - vim.fn.strdisplaywidth(right) - 1))
  local gap = inner - vim.fn.strdisplaywidth(left) - vim.fn.strdisplaywidth(right)
  if gap < 1 then gap = 1 end
  return left .. string.rep(" ", gap) .. right
end

-- One-line map summary under the title bar.
function M.map_stats_line(cleared, total, streak, width)
  local parts = { string.format("%d/%d rooms cleared", cleared or 0, total or 0) }
  if (streak or 0) > 0 then
    parts[#parts + 1] = string.format("streak %d", streak)
  end
  return M.spread_row(table.concat(parts, " · "), "", width)
end

-- Tier header: name left, progress + mini bar + boss hint right.
function M.map_tier_header(label, cleared, total, bar_len, boss_hint, width)
  bar_len = bar_len or 8
  local bar = M.tier_room_bar(cleared, total, bar_len)
  local right = string.format("%d/%d  %s", cleared, total, bar)
  if boss_hint and boss_hint ~= "" then right = right .. "  " .. boss_hint end
  return M.spread_row(label, right, width)
end

function M.map_boss_hint(boss_room, boss_cleared, boss_unlocked, cleared_ct, total_ct)
  if not boss_room then return "" end
  if boss_cleared then return "boss ✓" end
  if boss_unlocked then return "boss ready" end
  local need = math.ceil(math.max(total_ct, 1) * 0.8)
  return string.format("%d/%d → boss", cleared_ct, need)
end

-- Inner divider row (does not use the heavy ╠ sep).
function M.map_divider(width, indent)
  indent = indent or "  "
  local dashes = math.max(4, width - 2 - vim.fn.strdisplaywidth(indent))
  return indent .. string.rep("─", dashes)
end

function M.map_room_row(icon, title, title_max, indent)
  indent = indent or "    "
  return indent .. icon .. "  " .. M.truncate(title, title_max)
end

-- ── game chrome (shared HUD / menu styling) ────────────────────────────────

function M.bar_fill(value, max, bar_len, fill, empty)
  bar_len = bar_len or 8
  fill = fill or "█"
  empty = empty or "░"
  if icons.mode() == "ascii" then fill, empty = "#", "-" end
  local filled = 0
  if max and max > 0 then
    filled = math.floor((value or 0) / max * bar_len + 0.5)
  end
  filled = math.min(bar_len, math.max(0, filled))
  return string.rep(fill, filled) .. string.rep(empty, bar_len - filled)
end

function M.bracket_bar(value, max, bar_len, fill, empty)
  return "[" .. M.bar_fill(value, max, bar_len, fill, empty) .. "]"
end

function M.game_level(xp)
  return math.floor((xp or 0) / 120) + 1
end

-- Centered section divider: ── ══ TITLE ══ ──
function M.game_section(title, width, indent)
  indent = indent or "  "
  local edge = icons.mode() == "ascii" and "==" or "══"
  local decor = edge .. " " .. title .. " " .. edge
  local dash = icons.mode() == "ascii" and "-" or "─"
  local inner = width - 2 - vim.fn.strdisplaywidth(indent)
  local decor_w = vim.fn.strdisplaywidth(decor)
  if decor_w >= inner then
    return indent .. M.truncate(decor, inner)
  end
  local pad = inner - decor_w
  local left = math.floor(pad / 2)
  return indent .. string.rep(dash, left) .. decor .. string.rep(dash, pad - left)
end

function M.game_footer(bindings)
  local parts = {}
  for _, bind in ipairs(bindings or {}) do
    parts[#parts + 1] = string.format("[%s] %s", bind[1], bind[2])
  end
  return "  " .. table.concat(parts, " ")
end

-- Menu row with optional selection cursor (▶) and status icon.
function M.game_menu_row(selected, icon, title, title_max, indent)
  indent = indent or "  "
  local cur = selected and icons.get("cursor") or " "
  return indent .. cur .. " " .. (icon or "·") .. "  " .. M.truncate(title or "", title_max)
end

function M.game_hud_row(width, xp, streak, cleared, total)
  local remaining = 120 - ((xp or 0) % 120)
  local left = string.format("XP %s %d to LV %d", M.xp_bar(xp, 6), remaining, M.game_level(xp) + 1)
  local right = string.format("%d/%d clear", cleared or 0, total or 0)
  if (streak or 0) > 0 then right = right .. "  " .. icons.get("streak") .. " " .. streak end
  return M.spread_row(left, right, width)
end

function M.play_hud_section(title)
  return " " .. title
end

-- Mission first; compact combat stats leave room for the editing task.
function M.build_play_hud(ctx)
  local lines, hls = {}, {}
  local width = math.max(4, (ctx.width or 28) - 2)
  local function add(text, group)
    lines[#lines + 1] = M.truncate(text, width + 1)
    if group then hls[#hls + 1] = { group, #lines - 1, 0, -1 } end
  end
  add(" MISSION", "VimmerSection")
  for _, ln in ipairs(M.wrap_teach_text(ctx.goal or "Match the target above.", width)) do
    add(" " .. ln, "VimmerTitle")
  end
  if ctx.command then
    for _, ln in ipairs(M.wrap_teach_text(ctx.command, width)) do add(" " .. ln, "VimmerCommand") end
  end
  add("")
  add(" COMBAT", "VimmerSection")
  add(string.format(" HP %d/100 %s", ctx.display_hp or 0, ctx.hp_bar or ""), ctx.hp_group or "VimmerHP_high")
  add(string.format(" KEYS %d/%d  STREAK %d", ctx.keys_used or 0, ctx.keys_budget or 0, ctx.streak or 0), "VimmerTeachTip")
  if ctx.practice then add(" PRACTICE: no HP loss", "VimmerCleared") end
  if ctx.timer_remaining and ctx.initial_time then
    add(string.format(" TIMER %d:%02d", math.floor(ctx.timer_remaining / 60), ctx.timer_remaining % 60), ctx.timer_group)
  end
  if ctx.boss_phase then add(string.format(" PHASE %d / %d", ctx.boss_phase, ctx.boss_total), "VimmerBoss") end
  if ctx.feedback then add(" " .. ctx.feedback, "VimmerDeath") end
  if ctx.power_up_str then add(" " .. ctx.power_up_str, "VimmerXP") end
  add("")
  add(" [F1] hint / replay", "VimmerTeachFoot")
  add(" [F2] leave room", "VimmerTeachFoot")
  return lines, hls
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

-- Expand a list of optimal-keystroke tokens into single keys so they can be
-- counted against the player's raw key log. A `<...>` chunk (e.g. "<Esc>")
-- counts as one key; every other character counts as one key.
-- "ciw" -> {"c","i","w"}; "<Esc>" -> {"<Esc>"}.
function M.expand_keys(tokens)
  local out = {}
  for _, tok in ipairs(tokens or {}) do
    local i, n = 1, #tok
    while i <= n do
      if tok:sub(i, i) == "<" then
        local close = tok:find(">", i, true)
        if close then
          out[#out + 1] = tok:sub(i, close)
          i = close + 1
        else
          out[#out + 1] = tok:sub(i, i)
          i = i + 1
        end
      else
        out[#out + 1] = tok:sub(i, i)
        i = i + 1
      end
    end
  end
  return out
end

-- Choose the accepted key sequence with the fewest expanded keystrokes (the
-- most efficient path) for a room or boss-phase context. Returns
-- { tokens = <token list>, expanded_count = <int> } or nil if none exist.
-- Ties resolve to the first sequence (primary path).
function M.pick_baseline(ctx)
  local seqs = require("the-vimmer.rooms").acceptable_key_sequences(ctx)
  local best_tokens, best_count = nil, nil
  for _, seq in ipairs(seqs) do
    local count = #M.expand_keys(seq)
    if best_count == nil or count < best_count then
      best_tokens, best_count = seq, count
    end
  end
  if not best_tokens then return nil end
  return { tokens = best_tokens, expanded_count = best_count }
end

-- Wrap a list of already-formatted key strings into lines no wider than
-- `inner_width`, indenting continuation lines by 4 spaces. Returns a line array.
function M.wrap_keys(parts, inner_width)
  local lines = {}
  local line = "    "
  for _, tok in ipairs(parts or {}) do
    local sep = line == "    " and "" or " "
    if #line + #sep + #tok > inner_width and line ~= "    " then
      lines[#lines + 1] = line
      line = "    " .. tok
    else
      line = line .. sep .. tok
    end
  end
  if line ~= "    " then lines[#lines + 1] = line end
  return lines
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

-- Box-drawing glyph sets for floating panels. "sharp" is the original double-line
-- look; "rounded" uses light arcs for a softer frame.
M.BORDER = {
  sharp = {
    tl = "╔", tr = "╗", bl = "╚", br = "╝",
    h = "═", ml = "╠", mr = "╣", v = "║",
  },
  rounded = {
    tl = "╭", tr = "╮", bl = "╰", br = "╯",
    h = "─", ml = "├", mr = "┤", v = "│",
  },
}

function M.current_border_style()
  local ok, root = pcall(require, "the-vimmer")
  if ok and root and type(root.config) == "table" and root.config.border then
    return root.config.border
  end
  return "sharp"
end

function M.border_glyphs(style)
  style = style or M.current_border_style()
  if icons.mode() == "ascii" then
    return { tl = "+", tr = "+", bl = "+", br = "+", h = "-", ml = "+", mr = "+", v = "|" }
  end
  return M.BORDER[style] or M.BORDER.sharp
end

function M.pad_row(content, width, glyphs)
  glyphs = glyphs or M.border_glyphs()
  if icons.mode() == "ascii" then
    content = content:gsub("·", "/"):gsub("—", "-"):gsub("–", "-")
      :gsub("→", "->"):gsub("↵", "\\n"):gsub("▌", "|")
  end
  content = M.truncate(content, math.max(0, width - 2))
  local pad = math.max(0, width - 2 - vim.fn.strdisplaywidth(content))
  return glyphs.v .. content .. string.rep(" ", pad) .. glyphs.v
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

function M.make_border(width, style)
  local g = M.border_glyphs(style)
  local inner = string.rep(g.h, width - 2)
  return {
    top = g.tl .. inner .. g.tr,
    sep = g.ml .. inner .. g.mr,
    bot = g.bl .. inner .. g.br,
    row = function(content) return M.pad_row(content, width, g) end,
  }
end

function M.tier_room_bar(cleared, total, bar_len)
  return M.bracket_bar(cleared, total, bar_len or 8, "█", "░")
end

function M.fmt_run_seconds(s)
  return string.format("%.1fs", s)
end

-- Format a "  PB: N keys · M:SS" line from a pb table { keys, seconds }.
-- Omits a missing side; returns nil when neither is present.
function M.pb_line(pb)
  if type(pb) ~= "table" then return nil end
  local parts = {}
  if pb.keys and pb.keys > 0 then
    parts[#parts + 1] = string.format("%d keys", pb.keys)
  end
  if pb.seconds and pb.seconds > 0 then
    parts[#parts + 1] = M.fmt_run_seconds(pb.seconds)
  end
  if #parts == 0 then return nil end
  return "  PB: " .. table.concat(parts, " · ")
end

function M.streak_milestone_phrase(streak_after_win)
  if streak_after_win >= 20 then return "Dungeon legend — unreal streak." end
  if streak_after_win >= 10 then return "Double digits — you're flying." end
  if streak_after_win >= 5 then return "Five deep — rhythm locked in." end
  if streak_after_win >= 3 then return "Three in a row — streak bonus territory." end
  return nil
end

function M.xp_bar(xp, bar_width)
  return M.bracket_bar((xp or 0) % 120, 120, bar_width, "▓", "░")
end

return M
