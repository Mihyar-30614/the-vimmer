-- Optional Telescope fuzzy-picker for rooms. Returns false (not an error) when telescope.nvim
-- is absent — caller shows a fallback notify. Invoked by :VimmerPick.
local M = {}

-- Open a Telescope picker listing every room across all tiers.
-- Selecting an entry closes the picker and calls commands.start_flow with that room.
function M.pick_room()
  local ok, _ = pcall(require, "telescope")
  if not ok then return false end

  local rooms_mod = require("the-vimmer.rooms")
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local rows = {}
  for _, tier in ipairs(rooms_mod.all_tiers()) do
    for _, r in ipairs(rooms_mod.load_tier(tier)) do
      rows[#rows + 1] = {
        display = string.format("%s  [%s]  %s", r.title, r.id, tier),
        room = r,
      }
    end
  end

  pickers.new({}, {
    prompt_title = "the-vimmer rooms",
    finder = finders.new_table({
      results = rows,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = false,
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry and entry.value and entry.value.room then
          require("the-vimmer.commands").start_flow(entry.value.room)
        end
      end)
      return true
    end,
  }):find()

  return true
end

return M
