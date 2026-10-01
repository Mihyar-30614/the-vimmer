-- A deliberate learning path; external room packs remain available at the end.
local M = {}
M.groups = {
  beginner = {
    { "Find your footing", "hjkl", "replace_char", "hjkl2", "counts", "line_boundaries", "file_boundaries" },
    { "Travel by words", "w_motion", "b_motion", "e_motion", "word_hop" },
    { "Shape the text", "insert_mode", "insert2", "delete_char", "delete_motion", "d_dollar", "toggle_case", "join_lines" },
    { "Keep control", "delete_yank", "dd_yp", "undo_redo" },
  },
  warrior = {
    { "Find your target", "f_motion", "delete_to", "ft_chain", "search", "n_repeat", "star_search", "percent" },
    { "Change with intent", "ciw", "ci_combo", "change_chain", "case_ops", "indent" },
    { "See the battlefield", "goto_line", "viewport", "scroll", "visual", "visual_block" },
    { "Repeat your craft", "macros" },
  },
  ninja = {
    { "Work from within", "text_objects", "surround_obj", "complex_motions", "inc_dec" },
    { "Travel and store", "marks", "jump_list", "registers", "registers2", "black_hole" },
    { "Change everywhere", "cgn", "substitute", "global_delete", "sort", "norm_range" },
    { "Automate the room", "advanced_macros", "global_macro" },
  },
  grandmaster = {
    { "Rewrite patterns", "sub_amp", "sub_captures", "amp_repeat" },
    { "Command the lines", "copy_line", "move_line", "global_move" },
    { "Build a pipeline", "norm_range", "global_normal", "filter" },
    { "See the whole", "folds" },
  },
}

function M.group_for(room)
  for _, group in ipairs(M.groups[room.tier] or {}) do
    for i = 2, #group do if room.id == room.tier .. "_" .. group[i] then return group[1] end end
  end
  return "Extra adventures"
end

function M.sort(list, tier)
  local rank, n = {}, 0
  for _, group in ipairs(M.groups[tier] or {}) do
    for i = 2, #group do n = n + 1; rank[tier .. "_" .. group[i]] = n end
  end
  table.sort(list, function(a, b)
    local ar = a.is_boss and 10000 or (rank[a.id] or 9999)
    local br = b.is_boss and 10000 or (rank[b.id] or 9999)
    if ar == br then return a.id < b.id end
    return ar < br
  end)
end

function M.next_room(prog, by_tier)
  local progress = require("the-vimmer.progress")
  for _, tier in ipairs(require("the-vimmer.rooms").all_tiers()) do
    if progress.is_tier_unlocked(tier, prog.cleared or {}) then
      local list = {}
      for _, room in ipairs(by_tier[tier] or {}) do list[#list + 1] = room end
      M.sort(list, tier)
      for _, room in ipairs(list) do
        if not room.is_boss and not prog.cleared[room.id] then return room end
      end
      for _, room in ipairs(list) do
        if room.is_boss and not prog.cleared[room.id] and progress.is_boss_unlocked(tier, prog.cleared, #list - 1) then return room end
      end
    end
  end
end

return M
