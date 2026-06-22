-- Wires the full room-play flow and registers all :Vimmer* user commands.
-- start_flow is the single entry point for every room-play path (map, daily, CLI, telescope).
local M = {}

-- Lazy-load all runtime dependencies together to avoid circular require issues at startup.
local function deps()
  return {
    ui = require("the-vimmer.ui"),
    game = require("the-vimmer.game"),
    rooms = require("the-vimmer.rooms"),
    progress = require("the-vimmer.progress"),
    callbacks = require("the-vimmer.callbacks"),
  }
end

-- Build a { tier → rooms[] } table used by the map, progress, and daily screens.
local function build_rooms_by_tier(d)
  local result = {}
  for _, tier in ipairs(d.rooms.all_tiers()) do
    result[tier] = d.rooms.load_tier(tier)
  end
  return result
end

-- Detect whether any tier just became unlocked this run; returns a display name or nil.
local function check_newly_unlocked(d, prog, rooms_by_tier)
  for _, tier in ipairs(d.rooms.all_tiers()) do
    if not (prog.unlocked_tiers or {})[tier] then
      if d.progress.is_tier_unlocked(tier, prog.cleared) then
        prog.unlocked_tiers = prog.unlocked_tiers or {}
        prog.unlocked_tiers[tier] = true
        return tier:sub(1, 1):upper() .. tier:sub(2) .. " tier"
      end
    end
  end
  return nil
end

-- Entry point for playing a room (used by map, Telescope, daily, CLI).
-- flow_opts: { mutators = string[], daily = bool }
-- on_win: saves XP/PB, checks tier unlocks, grants power-ups, shows results screen.
-- on_death: resets streak, saves death stat, shows retry/map screen.
function M.start_flow(room, flow_opts)
  flow_opts = flow_opts or {}
  local d = deps()
  local prog = d.progress.load()
  local g = d.game.new()
  g.streak = prog.streak or 0

  local rooms_by_tier = build_rooms_by_tier(d)

  local function show_map()
    prog = d.progress.load()
    d.ui.open_map(prog, build_rooms_by_tier(d), M.start_flow)
  end

  local function on_win()
    local first_clear = prog.cleared[room.id] ~= true

    d.ui._close_play()
    g:complete_room()

    local prev_best = (prog.room_best or {})[room.id]
    prog.cleared[room.id] = true
    prog.total_xp = (prog.total_xp or 0) + g.last_xp
    g:dismiss_results()
    prog.streak = g.streak

    local run_s = g.run_seconds
    local new_pb = false
    if run_s and run_s > 0 then
      prog.room_best = prog.room_best or {}
      if prev_best == nil or run_s < prev_best then
        prog.room_best[room.id] = run_s
        new_pb = true
      end
    end

    d.progress.record_best_keys(prog, room.id, g.keystrokes_used)
    d.progress.record_clear_run(prog, room.id, g)
    d.progress.refresh_mutator_unlocks(prog)

    local unlocked_msg = check_newly_unlocked(d, prog, rooms_by_tier)
    d.progress.save(prog)

    local fast_clear = room.time_limit ~= nil
      and g.timer_remaining ~= nil
      and g.timer_remaining > room.time_limit * 0.5

    d.callbacks.emit("win", {
      room_id = room.id,
      xp = g.last_xp,
      streak = prog.streak,
      flawless = g.flawless_run,
      daily = flow_opts.daily == true,
    })

    local common = require("the-vimmer.ui.common")
    local phase_ctx = room.is_boss and (room.phases[g.boss_phase] or room) or room
    local baseline = common.pick_baseline(phase_ctx)
    local phase_view = d.rooms.phase_view(phase_ctx)

    d.ui.open_results(g.last_xp, g.hp, g.streak, unlocked_msg,
      function(go_map)
        if go_map then
          show_map()
          return
        end
        if flow_opts.queue and flow_opts.queue_idx then
          local nxt = flow_opts.queue[flow_opts.queue_idx + 1]
          if nxt then
            M.start_flow(nxt, { queue = flow_opts.queue, queue_idx = flow_opts.queue_idx + 1 })
          else
            show_map()
          end
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
          M.start_flow(next_room)
        else
          show_map()
        end
      end,
      {
        is_boss = room.is_boss,
        fast_clear = fast_clear,
        on_powerup = function(pu_type) g:grant_powerup(pu_type) end,
        room = room,
        first_clear = first_clear,
        is_daily = flow_opts.daily == true,
        active_mutators = flow_opts.mutators,
        run_stats = {
          keystrokes_used = g.keystrokes_used,
          keystrokes_over_budget = g.keystrokes_over_budget,
          keystrokes_budget = g.keystrokes_budget,
          efficiency_mult = g.last_efficiency_mult,
          seconds = run_s,
          flawless = g.flawless_run,
          new_personal_best = new_pb,
          prev_best_seconds = (not new_pb and prev_best) or nil,
          beaten_seconds = (new_pb and prev_best) or nil,
          keystroke_log   = g:keystroke_log_keys(),
          optimal_tokens  = baseline and baseline.tokens or nil,
          optimal_count   = baseline and baseline.expanded_count or nil,
          efficiency_hint = phase_view.efficiency_hint,
        },
      })
  end

  local function on_death()
    d.ui._close_play()
    g:retry_room()
    prog = d.progress.load()
    prog.streak = 0
    d.progress.record_death(prog, room.id)
    d.progress.save(prog)

    d.callbacks.emit("death", {
      room_id = room.id,
      timed_out = g.timer_death,
      over_budget_count = g.keystrokes_over_budget,
    })

    d.ui.open_death(room,
      function() M.start_flow(room, flow_opts) end,
      show_map,
      {
        timed_out = g.timer_death,
        over_budget_count = g.keystrokes_over_budget,
      }
    )
  end

  g:start_room(room)
  flow_opts.pb = {
    keys    = (not room.is_boss) and (prog.room_best_keys or {})[room.id] or nil,
    seconds = (prog.room_best or {})[room.id],
  }
  d.ui.open_teach(room, flow_opts, function()
    prog = d.progress.load()
    d.progress.record_attempt(prog, room.id)
    d.progress.save(prog)
    g:set_mutators(flow_opts.mutators or {})
    g:begin_play()
    d.ui.open_play(room, g, on_win, on_death)
  end)
end

function M.register(opts)
  opts = opts or {}
  require("the-vimmer.callbacks").set(opts.hooks)

  vim.api.nvim_create_user_command("VimmerPlay", function(cmd_opts)
    local d = deps()
    if cmd_opts.args ~= "" then
      local room = d.rooms.get_room(cmd_opts.args)
      if not room then
        vim.notify("the-vimmer: room not found: " .. cmd_opts.args, vim.log.levels.ERROR)
        return
      end
      M.start_flow(room)
    else
      local prog = d.progress.load()
      d.ui.open_map(prog, build_rooms_by_tier(d), M.start_flow)
    end
  end, { nargs = "?", desc = "Play the-vimmer (optional room id)" })

  vim.api.nvim_create_user_command("VimmerDaily", function()
    local d = deps()
    local prog = d.progress.load()
    local rooms_by_tier = build_rooms_by_tier(d)
    local daily_mod = require("the-vimmer.daily")
    local challenge_room, mutators = daily_mod.resolve_for_today(prog, rooms_by_tier)
    if not challenge_room then
      vim.notify("the-vimmer: no rooms available for daily run", vim.log.levels.WARN)
      return
    end
    d.progress.save(prog)
    M.start_flow(challenge_room, { mutators = mutators, daily = true })
  end, { desc = "Today's seeded the-vimmer challenge" })

  vim.api.nvim_create_user_command("VimmerDrill", function()
    local d = deps()
    local prog = d.progress.load()
    local rooms_by_tier = build_rooms_by_tier(d)
    local ids = d.progress.weakest_regular_room_ids(prog, rooms_by_tier, 3)
    local queue = {}
    for _, id in ipairs(ids) do
      local r = d.rooms.get_room(id)
      if r then queue[#queue + 1] = r end
    end
    if #queue == 0 then
      vim.notify("the-vimmer: no drillable rooms yet — play a few first",
        vim.log.levels.INFO)
      return
    end
    M.start_flow(queue[1], { queue = queue, queue_idx = 1 })
  end, { desc = "Drill your 3 weakest the-vimmer rooms" })

  vim.api.nvim_create_user_command("VimmerPick", function()
    local ok = require("the-vimmer.telescope").pick_room()
    if not ok then
      vim.notify("the-vimmer: install telescope.nvim to use :VimmerPick", vim.log.levels.WARN)
    end
  end, { desc = "Fuzzy-pick a the-vimmer room (Telescope)" })

  vim.api.nvim_create_user_command("VimmerProgress", function()
    local d = deps()
    d.ui.open_progress(d.progress.load(), build_rooms_by_tier(d))
  end, { desc = "Show the-vimmer progress" })

  vim.api.nvim_create_user_command("VimmerReset", function()
    deps().progress.reset()
    vim.notify("the-vimmer: progress reset", vim.log.levels.INFO)
  end, { desc = "Reset all the-vimmer progress" })
end

return M
