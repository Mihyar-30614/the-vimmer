-- Floating-window primitives + width constants for the-vimmer's UI screens.
-- Pulls in vim.api at require time, so this is only safe to require inside Neovim.
local M = {}
local api = vim.api
local common = require("the-vimmer.ui.common")
local panels = {}

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
  if panels[buf] then panels[buf].highlights = highlights; M.refresh_frame(buf) end
end

function M.flash(buf, group, duration, callback)
  if common.reduced_motion() then if callback then callback() end; return end
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
  if common.reduced_motion() then if callback then callback() end; return end
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

-- Preserve the transition callback API without flashing the full editor.
function M.multi_overlay_flash(steps, callback)
  -- Transitions should never interrupt the entire editor. Local play cues and
  -- the results count-up carry the celebration.
  if callback then callback() end
end

-- Tall panels scroll under a persistent frame. Keep the original buffer line
-- numbers so callers can highlight and navigate their content normally.
local function scratch(lines)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  return buf
end

local function style(win)
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].scrolloff = 0
  vim.wo[win].winhighlight = "Normal:VimmerNormal,NormalFloat:VimmerNormal,EndOfBuffer:VimmerNormal"
end

function M.refresh_frame(buf)
  local p = panels[buf]
  if not p then return end
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
  local height = math.min(#lines, math.max(1, vim.o.lines - 2))
  local width = math.min(p.width, math.max(4, vim.o.columns - 4))
  local row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1)
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  api.nvim_win_set_config(p.win, { relative = "editor", row = row, col = col, width = width, height = height })
  p.header, p.footer = 0, 0
  if #lines > height and height >= 8 then
    p.header, p.footer = 3, 3
    for index, part in ipairs({ { first = 1, row = row }, { first = #lines - 2, row = row + height - 3 } }) do
      local view = {}
      for i = part.first, part.first + 2 do view[#view + 1] = lines[i] end
      local frame = p.frames[index]
      if not frame or not api.nvim_win_is_valid(frame.win) then
        local frame_buf = scratch(view)
        local frame_win = api.nvim_open_win(frame_buf, false, {
          relative = "editor", row = part.row, col = col, width = width, height = 3,
          style = "minimal", focusable = false, zindex = p.zindex + 1,
        })
        style(frame_win)
        frame = { win = frame_win, buf = frame_buf }
        p.frames[index] = frame
      else
        vim.bo[frame.buf].modifiable = true
        api.nvim_buf_set_lines(frame.buf, 0, -1, false, view)
        vim.bo[frame.buf].modifiable = false
        api.nvim_win_set_config(frame.win, { relative = "editor", row = part.row, col = col, width = width, height = 3 })
      end
      local frame_buf = frame.buf
      api.nvim_buf_clear_namespace(frame_buf, 0, 0, -1)
      for _, h in ipairs(p.highlights or {}) do
        if h[2] >= part.first - 1 and h[2] < part.first + 2 then
          api.nvim_buf_add_highlight(frame_buf, 0, h[1], h[2] - part.first + 1, h[3], h[4])
        end
      end
    end
  else
    for _, frame in ipairs(p.frames) do
      if api.nvim_win_is_valid(frame.win) then api.nvim_win_close(frame.win, true) end
    end
    p.frames = {}
  end
end

function M.resize_float(buf, width)
  if panels[buf] then panels[buf].width = width end
  M.refresh_frame(buf)
end

function M.ensure_visible(win, line)
  if not api.nvim_win_is_valid(win) then return end
  local p = panels[api.nvim_win_get_buf(win)]
  api.nvim_win_set_cursor(win, { line, 0 })
  if not p or p.header == 0 then return end
  api.nvim_win_call(win, function()
    local view = vim.fn.winsaveview()
    local h = api.nvim_win_get_height(win)
    if line < view.topline + p.header then view.topline = math.max(1, line - p.header) end
    if line >= view.topline + h - p.footer then view.topline = math.max(1, line - h + p.footer + 1) end
    vim.fn.winrestview(view)
  end)
end

function M.open_float(lines, width, opts)
  opts = opts or {}
  local buf = scratch(lines)
  local zindex = 50
  for _, other in ipairs(api.nvim_list_wins()) do
    local config = api.nvim_win_get_config(other)
    if config.relative ~= "" then zindex = math.max(zindex, (config.zindex or 50) + 2) end
  end
  local win = api.nvim_open_win(buf, true, {
    relative = "editor", row = 0, col = 0, width = math.max(4, width), height = 1,
    style = "minimal", border = "none", zindex = zindex,
  })
  style(win)
  panels[buf] = { win = win, width = width, frames = {}, zindex = zindex }
  M.refresh_frame(buf)
  M.ensure_visible(win, math.min(4, #lines))
  local group = api.nvim_create_augroup("VimmerPanel" .. buf, { clear = true })
  api.nvim_create_autocmd("WinClosed", { group = group, pattern = tostring(win), once = true, callback = function()
    local p = panels[buf]
    panels[buf] = nil
    if p then for _, frame in ipairs(p.frames) do
      if api.nvim_win_is_valid(frame.win) then api.nvim_win_close(frame.win, true) end
    end end
    pcall(api.nvim_del_augroup_by_id, group)
  end })
  api.nvim_create_autocmd("VimResized", { group = group, callback = function()
    if not api.nvim_win_is_valid(win) then return end
    if opts.on_resize then opts.on_resize() else M.refresh_frame(buf) end
  end })
  api.nvim_create_autocmd("CursorMoved", { group = group, buffer = buf, callback = function()
    if api.nvim_get_current_win() ~= win then return end
    local p = panels[buf]
    if p and p.header > 0 then
      local line = api.nvim_win_get_cursor(win)[1]
      line = math.max(4, math.min(api.nvim_buf_line_count(buf) - 3, line))
      M.ensure_visible(win, line)
    end
  end })
  -- Normal-mode scrolling remains available in lessons, results and help.
  vim.keymap.set("n", "<Esc>", function()
    if api.nvim_win_is_valid(win) then api.nvim_win_close(win, true) end
  end, { buffer = buf, silent = true })
  return buf, win
end

return M
