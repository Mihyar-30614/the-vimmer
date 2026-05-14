local M = {}

function M.new()
  local g = {
    state = "idle",        -- idle | teaching | playing | results
    current_room = nil,
    hp = 100,
    streak = 0,            -- rooms cleared in a row without dying

    keystrokes_used = 0,         -- total keys pressed this phase
    keystrokes_budget = 0,       -- ceil(#optimal_keystrokes * 1.5), or *1.0 under iron
    keystrokes_over_budget = 0,  -- count of over-budget keys this run (HP-draining)

    run_started_at = nil,
    run_seconds = nil,     -- wall-clock duration of the last run
    flawless_run = false,  -- true when cleared with keystrokes_used <= #optimal_keystrokes
    timer_death = false,   -- true when time ran out (as opposed to HP hitting 0)

    last_xp = 0,
    last_efficiency_mult = 1,    -- recorded by complete_room for HUD/results
    timer_remaining = nil, -- seconds left; nil = no time limit for this room
    power_ups = {},        -- at most 2 held at once
    boss_phase = 1,
    boss_total_phases = 0,

    _mutators = {},        -- active run modifiers (rush, glass, iron…)
  }

  -- Replace the mutator table for a new run.
  function g:set_mutators(list)
    self._mutators = {}
    for _, name in ipairs(list or {}) do
      self._mutators[name] = true
    end
  end

  -- glass mutator doubles over-budget HP cost (8 vs 5).
  function g:_over_budget_cost()
    return self._mutators.glass and 8 or 5
  end

  -- iron mutator removes the 50% grace; budget collapses to optimal length.
  function g:_budget_for(optimal_count)
    if self._mutators.iron then return optimal_count end
    return math.ceil(optimal_count * 1.5)
  end

  -- Enter the teaching screen; does NOT start the countdown.
  function g:start_room(room)
    self.current_room = room
    self.state = "teaching"
  end

  -- Return the data table for the current boss phase, or the room itself for normal rooms.
  function g:_phase_context()
    if self.current_room.is_boss then
      return self.current_room.phases[self.boss_phase] or {}
    end
    return self.current_room
  end

  -- Return the optimal keystroke list for the current phase (used by teach screen + budget calc).
  function g:_phase_optimal()
    if not self.current_room then return {} end
    return self:_phase_context().optimal_keystrokes or {}
  end

  -- Reset per-phase keystroke counters and recompute the budget.
  function g:_reset_keystroke_budget()
    self.keystrokes_used = 0
    self.keystrokes_budget = self:_budget_for(#self:_phase_optimal())
  end

  -- Transition from teaching → playing; resets all per-room state.
  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.keystrokes_over_budget = 0
    self.run_started_at = os.clock()
    self.timer_death = false
    if self.current_room.is_boss then
      self.boss_phase = 1
      self.boss_total_phases = #self.current_room.phases
      self.timer_remaining = self.current_room.time_limit
    else
      self.boss_phase = 1
      self.boss_total_phases = 0
      self.timer_remaining = self.current_room.time_limit or nil
    end
    self.state = "playing"
    self:_apply_auto_powerups()
    self:_reset_keystroke_budget()
  end

  -- Called for every keypress while state == "playing".
  -- Every key increments keystrokes_used; HP drains only for keys past the budget.
  function g:register_key(_key)
    if self.state ~= "playing" then return end
    if not self.current_room then return end
    self.keystrokes_used = self.keystrokes_used + 1
    if self.keystrokes_used > self.keystrokes_budget then
      self.keystrokes_over_budget = self.keystrokes_over_budget + 1
      self.hp = math.max(0, self.hp - self:_over_budget_cost())
    end
  end

  function g:is_dead()
    return self.hp <= 0
  end

  -- Called once per second by the UI timer loop.
  -- rush mutator burns 2 seconds per tick. Returns true when time runs out.
  function g:tick_timer()
    if self.timer_remaining == nil then return false end
    local delta = self._mutators.rush and 2 or 1
    self.timer_remaining = self.timer_remaining - delta
    if self.timer_remaining <= 0 then
      self.hp = 0
      self.timer_death = true
      return true
    end
    return false
  end

  -- Consume any queued hp_restore power-ups immediately on play start.
  function g:_apply_auto_powerups()
    for i = #self.power_ups, 1, -1 do
      if self.power_ups[i].type == "hp_restore" then
        self.hp = math.min(100, self.hp + 30)
        table.remove(self.power_ups, i)
      end
    end
  end

  -- Max 2 power-ups held at once.
  function g:grant_powerup(pu_type)
    if #self.power_ups >= 2 then return end
    self.power_ups[#self.power_ups + 1] = { type = pu_type }
  end

  -- Consume a freeze_timer power-up, adding `seconds` back to the clock.
  function g:activate_freeze(seconds)
    for i, pu in ipairs(self.power_ups) do
      if pu.type == "freeze_timer" then
        table.remove(self.power_ups, i)
        if self.timer_remaining then
          self.timer_remaining = self.timer_remaining + (seconds or 5)
        end
        return true
      end
    end
    return false
  end

  -- Move to the next boss phase; resets per-phase keystroke counters and recomputes budget.
  -- HP, timer, and the over-budget counter carry over.
  function g:advance_boss_phase()
    self.boss_phase = self.boss_phase + 1
    self:_reset_keystroke_budget()
  end

  -- Finalise the room: compute efficiency_mult, calculate XP (with optional double_xp),
  -- record wall-clock time, and apply the flawless bonus.
  function g:complete_room()
    if not self.current_room then return end
    local progress = require("the-vimmer.progress")
    local double = false
    for i = #self.power_ups, 1, -1 do
      if self.power_ups[i].type == "double_xp" then
        double = true
        table.remove(self.power_ups, i)
        break
      end
    end

    local optimal_count = #self:_phase_optimal()
    local used = self.keystrokes_used
    local mult
    if used == 0 or optimal_count == 0 then
      mult = 1
    else
      mult = optimal_count / used
      if mult < 0.5 then mult = 0.5 end
      if mult > 3 then mult = 3 end
    end
    self.last_efficiency_mult = mult

    self.last_xp = progress.calculate_xp(
      self.current_room.base_xp,
      self.hp,
      self.streak,
      mult,
      double
    )
    self.run_seconds = self.run_started_at and math.max(0, os.clock() - self.run_started_at) or nil
    self.flawless_run = (used <= optimal_count)
    if self.flawless_run then
      self.last_xp = math.floor(self.last_xp * 1.15)
    end
    self.state = "results"
  end

  function g:dismiss_results()
    self.streak = self.streak + 1
    self.state = "idle"
  end

  function g:retry_room()
    self.streak = 0
    local room = self.current_room
    self.state = "idle"
    self:start_room(room)
  end

  return g
end

return M
