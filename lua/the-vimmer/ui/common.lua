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
  -- Strip UTF-8 multi-byte sequences down to one byte each to estimate display width.
  -- Decimal escapes (not \xHH) so the patterns parse under plain Lua 5.1 as well as LuaJIT.
  local visible = content:gsub("[\194-\223][\128-\191]", "_")
    :gsub("[\224-\239][\128-\191][\128-\191]", "_")
    :gsub("[\240-\247][\128-\191][\128-\191][\128-\191]", "_")
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
