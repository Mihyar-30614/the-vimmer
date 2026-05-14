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
