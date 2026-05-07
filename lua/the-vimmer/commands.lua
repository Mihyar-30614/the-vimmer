local M = {}

local function deps()
  return {
    ui = require("the-vimmer.ui"),
    game = require("the-vimmer.game"),
    rooms = require("the-vimmer.rooms"),
    progress = require("the-vimmer.progress"),
  }
end

local function build_rooms_by_tier(d)
  local result = {}
  for _, tier in ipairs(d.rooms.all_tiers()) do
    result[tier] = d.rooms.load_tier(tier)
  end
  return result
end

local function check_newly_unlocked(d, prog, rooms_by_tier)
  for _, tier in ipairs(d.rooms.all_tiers()) do
    if not (prog.unlocked_tiers or {})[tier] then
      local total = #(rooms_by_tier[tier] or {})
      if d.progress.is_tier_unlocked(tier, prog.cleared, total) then
        prog.unlocked_tiers = prog.unlocked_tiers or {}
        prog.unlocked_tiers[tier] = true
        return tier:sub(1,1):upper() .. tier:sub(2) .. " tier"
      end
    end
  end
  return nil
end

local function start_flow(room)
  local d = deps()
  local prog = d.progress.load()
  local g = d.game.new()
  g.streak = prog.streak or 0

  local rooms_by_tier = build_rooms_by_tier(d)

  local function show_map()
    prog = d.progress.load()
    d.ui.open_map(prog, build_rooms_by_tier(d), start_flow)
  end

  local function on_win()
    d.ui._close_play()
    g:complete_room()

    prog.cleared[room.id] = true
    prog.total_xp = (prog.total_xp or 0) + g.last_xp
    g:dismiss_results()
    prog.streak = g.streak
    local unlocked_msg = check_newly_unlocked(d, prog, rooms_by_tier)
    d.progress.save(prog)

    local fast_clear = room.time_limit ~= nil
      and g.timer_remaining ~= nil
      and g.timer_remaining > room.time_limit * 0.5

    d.ui.open_results(g.last_xp, g.hp, g.streak, unlocked_msg,
      function(go_map)
        if go_map then
          show_map()
          return
        end
        local tier_rooms = d.rooms.load_tier(room.tier)
        local next_room = nil
        for i, r in ipairs(tier_rooms) do
          if r.id == room.id and tier_rooms[i + 1] then
            next_room = tier_rooms[i + 1]
            break
          end
        end
        if next_room then
          start_flow(next_room)
        else
          show_map()
        end
      end,
      {
        is_boss = room.is_boss,
        fast_clear = fast_clear,
        on_powerup = function(pu_type) g:grant_powerup(pu_type) end,
      })
  end

  local function on_death()
    d.ui._close_play()
    g:retry_room()
    prog.streak = 0
    d.progress.save(prog)
    d.ui.open_death(room,
      function() start_flow(room) end,
      show_map
    )
  end

  g:start_room(room)
  d.ui.open_teach(room, function()
    g:begin_play()
    d.ui.open_play(room, g, on_win, on_death)
  end)
end

function M.register()
  vim.api.nvim_create_user_command("VimmerPlay", function(opts)
    local d = deps()
    if opts.args ~= "" then
      local room = d.rooms.get_room(opts.args)
      if not room then
        vim.notify("the-vimmer: room not found: " .. opts.args, vim.log.levels.ERROR)
        return
      end
      start_flow(room)
    else
      local prog = d.progress.load()
      d.ui.open_map(prog, build_rooms_by_tier(d), start_flow)
    end
  end, { nargs = "?", desc = "Play the-vimmer (optional room id)" })

  vim.api.nvim_create_user_command("VimmerProgress", function()
    local prog = deps().progress.load()
    local count = 0
    for _ in pairs(prog.cleared) do count = count + 1 end
    vim.notify(string.format(
      "the-vimmer | XP: %d | Cleared: %d | Streak: %d",
      prog.total_xp, count, prog.streak
    ), vim.log.levels.INFO)
  end, { desc = "Show the-vimmer progress" })

  vim.api.nvim_create_user_command("VimmerReset", function()
    deps().progress.reset()
    vim.notify("the-vimmer: progress reset", vim.log.levels.INFO)
  end, { desc = "Reset all the-vimmer progress" })
end

return M
