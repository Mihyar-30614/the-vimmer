local M = {}

function M.new()
  local g = {
    state = "idle",
    current_room = nil,
    hp = 100,
    streak = 0,
    last_xp = 0,
    combo = 0,
    combo_mult = 1,
    correct_streak = 0,
    timer_remaining = nil,
    power_ups = {},
    boss_phase = 1,
    boss_total_phases = 0,
  }

  function g:start_room(room)
    self.current_room = room
    self.state = "teaching"
  end

  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.combo = 0
    self.combo_mult = 1
    self.correct_streak = 0
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
  end

  function g:_phase_optimal()
    if not self.current_room then return {} end
    if self.current_room.is_boss then
      local phase = self.current_room.phases[self.boss_phase]
      return phase and phase.optimal_keystrokes or {}
    end
    return self.current_room.optimal_keystrokes or {}
  end

  function g:register_key(key)
    if self.state ~= "playing" then return end
    if not self.current_room then return end
    local optimal = self:_phase_optimal()
    local is_correct = false
    for _, k in ipairs(optimal) do
      if k == key then is_correct = true; break end
    end
    if is_correct then
      self.combo = self.combo + 1
      self.correct_streak = self.correct_streak + 1
      if self.correct_streak % 3 == 0 then
        self.hp = math.min(100, self.hp + 2)
      end
    else
      self.combo = 0
      self.correct_streak = 0
      self.hp = math.max(0, self.hp - 5)
    end
    self.combo_mult = self.combo >= 10 and 3 or self.combo >= 5 and 2 or 1
  end

  function g:is_dead()
    return self.hp <= 0
  end

  function g:tick_timer()
    if self.timer_remaining == nil then return false end
    self.timer_remaining = self.timer_remaining - 1
    if self.timer_remaining <= 0 then
      self.hp = 0
      return true
    end
    return false
  end

  function g:_apply_auto_powerups()
    for i = #self.power_ups, 1, -1 do
      if self.power_ups[i].type == "hp_restore" then
        self.hp = math.min(100, self.hp + 30)
        table.remove(self.power_ups, i)
      end
    end
  end

  function g:grant_powerup(pu_type)
    if #self.power_ups >= 2 then return end
    self.power_ups[#self.power_ups + 1] = { type = pu_type }
  end

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

  function g:advance_boss_phase()
    self.boss_phase = self.boss_phase + 1
    self.combo = 0
    self.combo_mult = 1
    self.correct_streak = 0
  end

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
    self.last_xp = progress.calculate_xp(
      self.current_room.base_xp,
      self.hp,
      self.streak,
      self.combo_mult,
      double
    )
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
