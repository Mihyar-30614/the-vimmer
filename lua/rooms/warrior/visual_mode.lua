-- Warrior room: v/V/Ctrl-v (visual mode). Player selects "DELETE_ME" with v+e then deletes with d.
return {
  id = "warrior_visual",
  tier = "warrior",
  command = "v / V / Ctrl-v",
  title = "Visual Mode: v, V, Ctrl-v",
  description = "Select: characters (v), whole lines (V), or a rectangular block (Ctrl-v)",
  before_example = "keep this DELETE_ME keep this",
  after_example = "keep this  keep this",
  usage_tip = "v enters char-wise visual. Extend with motion keys, then d to delete selection.",
  start_text = "keep this DELETE_ME keep this",
  target_text = "keep this  keep this",
  base_xp = 80,
  optimal_keystrokes = { "w", "w", "v", "e", "d" },
}
