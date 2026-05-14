-- Ninja room: <C-o> / <C-i> (jump-list back/forward). Optimal uses only <C-o> because <C-i>
-- is the Tab byte and the play tab maps Tab to the freeze powerup. Tip flags the conflict.
return {
  id = "ninja_jump_list",
  tier = "ninja",
  command = "<C-o> / <C-i>",
  title = "Jump History: <C-o>, <C-i>",
  description = "<C-o> jumps to older position in the jump list; <C-i> jumps to newer",
  before_example = "After /search or G, back-track without retyping",
  after_example = "Cursor returns to prior location",
  usage_tip = "Like browser back/forward. <C-i> = Tab; the play tab maps Tab to freeze powerup, so use <C-i> in your real editor.",
  start_text = "anchor top\nfiller\nfiller\nfiller\nfiller\nfiller\nanchor bottom",
  target_text = "anchor top\nfiller\nfiller\nfiller\nfiller\nfiller\nanchor bottom",
  base_xp = 95,
  time_limit = 30,
  optimal_keystrokes = { "G", "\x0f" },
}
