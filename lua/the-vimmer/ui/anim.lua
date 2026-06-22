-- Animation primitives for the-vimmer's UI ("juice").
--
-- Split into a pure core (lerp / easing / frame computation / bar rendering)
-- that is safe to require headlessly and unit-test, and thin runtime drivers
-- (tween / count_up) that schedule frames with vim.defer_fn. Every on-screen
-- effect rides the same driver and returns a cancel handle so timers can be
-- stopped when a buffer or window goes away.
local M = {}

-- ── pure core ──────────────────────────────────────────────────────────────

function M.lerp(a, b, t)
  return a + (b - a) * t
end

-- Decelerating ease: fast start, slow finish. t in [0,1].
function M.ease_out_quad(t)
  return 1 - (1 - t) * (1 - t)
end

-- Eased sequence of integer values for a counter rolling `from` -> `to`.
-- Returns exactly `steps` frames; the last frame is always `to`.
function M.count_frames(from, to, steps)
  if steps == nil or steps < 1 then return { to } end
  local out = {}
  for i = 1, steps do
    local t = i / steps
    out[i] = math.floor(M.lerp(from, to, M.ease_out_quad(t)) + 0.5)
  end
  out[steps] = to
  return out
end

-- Render a fill bar. opts.fill / opts.empty glyphs, opts.round =
-- "nearest" (default) | "ceil" | "floor". Clamps to [0, width].
function M.bar(value, max, width, opts)
  opts = opts or {}
  local fill = opts.fill or "█"
  local empty = opts.empty or "░"
  local filled = 0
  if max and max > 0 then
    local raw = value / max * width
    local r = opts.round or "nearest"
    if r == "ceil" then filled = math.ceil(raw)
    elseif r == "floor" then filled = math.floor(raw)
    else filled = math.floor(raw + 0.5) end
  end
  if filled < 0 then filled = 0 end
  if filled > width then filled = width end
  return string.rep(fill, filled) .. string.rep(empty, width - filled)
end

-- A short sparkle sequence for the win burst. Each frame is a single-byte
-- ASCII string of exactly `width` chars (so terminals/fonts can't break it).
function M.burst_frames(count, width)
  local glyphs = { " ", ".", "+", "*" }
  local frames = {}
  for i = 1, count do
    local chars = {}
    for p = 1, width do
      chars[p] = glyphs[((p + i) % #glyphs) + 1]
    end
    frames[i] = table.concat(chars)
  end
  return frames
end

-- ── runtime drivers (need Neovim) ───────────────────────────────────────────

-- Drive `on_frame(eased_t, t)` across a duration. Returns { cancel = fn }.
function M.tween(opts)
  local duration = opts.duration_ms or 400
  local fps = opts.fps or 30
  local steps = math.max(1, math.floor(duration / 1000 * fps))
  local interval = math.max(16, math.floor(duration / steps))
  local ease = opts.ease or M.ease_out_quad
  local cancelled = false
  local i = 0
  local function step()
    if cancelled then return end
    i = i + 1
    local t = i / steps
    if t > 1 then t = 1 end
    if opts.on_frame then opts.on_frame(ease(t), t) end
    if i < steps then
      vim.defer_fn(step, interval)
    elseif opts.on_done then
      opts.on_done()
    end
  end
  vim.defer_fn(step, interval)
  return { cancel = function() cancelled = true end }
end

-- Roll an integer counter from `from` to `to`, calling on_value(int) per frame.
-- Returns { cancel = fn }.
function M.count_up(opts)
  local fps = opts.fps or 30
  local duration = opts.duration_ms or 500
  local steps = math.max(1, math.floor(duration / 1000 * fps))
  local frames = M.count_frames(opts.from or 0, opts.to or 0, steps)
  local interval = math.max(16, math.floor(duration / #frames))
  local cancelled = false
  local i = 0
  local function step()
    if cancelled then return end
    i = i + 1
    if opts.on_value then opts.on_value(frames[i]) end
    if i < #frames then
      vim.defer_fn(step, interval)
    elseif opts.on_done then
      opts.on_done()
    end
  end
  vim.defer_fn(step, interval)
  return { cancel = function() cancelled = true end }
end

-- Play a list of frame strings on one buffer line. `render(frame_str)` returns
-- the full line text to write. Used for the win-burst sparkle. Settles on the
-- last frame. Returns { cancel = fn }.
function M.play_frames(buf, line0, frames, render, interval_ms, on_done)
  local api = vim.api
  interval_ms = interval_ms or 70
  local cancelled = false
  local i = 0
  local function step()
    if cancelled then return end
    if not api.nvim_buf_is_valid(buf) then return end
    i = i + 1
    local was = api.nvim_buf_get_option(buf, "modifiable")
    api.nvim_buf_set_option(buf, "modifiable", true)
    pcall(api.nvim_buf_set_lines, buf, line0, line0 + 1, false, { render(frames[i]) })
    api.nvim_buf_set_option(buf, "modifiable", was)
    if i < #frames then
      vim.defer_fn(step, interval_ms)
    elseif on_done then
      on_done()
    end
  end
  vim.defer_fn(step, interval_ms)
  return { cancel = function() cancelled = true end }
end

return M
