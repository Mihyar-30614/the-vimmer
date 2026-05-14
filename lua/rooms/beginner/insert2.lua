-- Beginner room: A/o/O insert variants. Player appends "!" to 3 lines using A + j repeat.
return {
  id = "beginner_insert2",
  tier = "beginner",
  command = "a / A / o / O",
  title = "Insert Variants",
  description = "A = append at end of line. o = open line below. O = open line above.",
  before_example = "hello|",
  after_example = "hello!",
  usage_tip = "A puts you at end of line in insert mode. o opens a new line below.",
  start_text = "alpha\nbeta\ngamma",
  target_text = "alpha!\nbeta!\ngamma!",
  base_xp = 50,
  time_limit = 60,
  optimal_keystrokes = { "A", "!", "\27", "j", "A", "!", "\27", "j", "A", "!", "\27" },
}
