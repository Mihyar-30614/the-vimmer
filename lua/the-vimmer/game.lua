local M = {}

local rooms_mod = require("the-vimmer.rooms")

local function step_sequence_states(active, sequences, key)
  local out = {}
  local sig_seen = {}
  for _, st in ipairs(active) do
    local seq = sequences[st.seq_idx]
    if seq and #seq > 0 then
      local next_i = st.pos + 1
      if seq[next_i] == key then
        local new_pos = (next_i == #seq) and 0 or next_i
        local sig = st.seq_idx .. ":" .. new_pos
        if not sig_seen[sig] then
          sig_seen[sig] = true
          out[#out + 1] = { seq_idx = st.seq_idx, pos = new_pos }
        end
      end
    end
  end
  return out
end

function M.new()
  local g = {
    state = "idle",
    current_room = nil,
    hp = 100,
    streak = 0,
    keys_correct = 0,
    keys_wrong = 0,
    run_started_at = nil,
    run_seconds = nil,
    flawless_run = false,
    timer_death = false,

    last_xp = 0,
    combo = 0,
    combo_mult = 1,
    correct_streak = 0,
    timer_remaining = nil,
    power_ups = {},
    boss_phase = 1,
    boss_total_phases = 0,

    _acceptable_sequences = {},
    _seq_active = {},
    _mutators = {},
  }

  function g:set_mutators(list)
    self._mutators = {}
    for _, name in ipairs(list or {}) do
      self._mutators[name] = true
    end
  end

  function g:_wrong_hp_cost()
    return self._mutators.glass and 8 or 5
  end

  function g:start_room(room)
    self.current_room = room
    self.state = "teaching"
  end

  function g:_phase_context()
    if self.current_room.is_boss then
      return self.current_room.phases[self.boss_phase] or {}
    end
    return self.current_room
  end

  function g:_reset_sequence_states()
    local ctx = self:_phase_context()
    self._acceptable_sequences = rooms_mod.acceptable_key_sequences(ctx)
    self._seq_active = {}
    for i = 1, #self._acceptable_sequences do
      self._seq_active[#self._seq_active + 1] = { seq_idx = i, pos = 0 }
    end
  end

  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.combo = 0
    self.combo_mult = 1
    self.correct_streak = 0
    self.keys_correct = 0
    self.keys_wrong = 0
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
    self:_reset_sequence_states()
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
    local sequences = self._acceptable_sequences or {}
    if #sequences == 0 then
      self.combo = 0
      self.correct_streak = 0
      self.keys_wrong = self.keys_wrong + 1
      self.hp = math.max(0, self.hp - self:_wrong_hp_cost())
      self.combo_mult = self.combo >= 10 and 3 or self.combo >= 5 and 2 or 1
      return
    end

    local next_active = step_sequence_states(self._seq_active, sequences, key)
    if #next_active > 0 then
      self._seq_active = next_active
      self.combo = self.combo + 1
      self.correct_streak = self.correct_streak + 1
      self.keys_correct = self.keys_correct + 1
      if not self._mutators.iron and self.correct_streak % 3 == 0 then
        self.hp = math.min(100, self.hp + 2)
      end
    else
      self.combo = 0
      self.correct_streak = 0
      self.keys_wrong = self.keys_wrong + 1
      self.hp = math.max(0, self.hp - self:_wrong_hp_cost())
      self:_reset_sequence_states()
    end
    self.combo_mult = self.combo >= 10 and 3 or self.combo >= 5 and 2 or 1
  end

  function g:is_dead()
    return self.hp <= 0
  end

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
    self:_reset_sequence_states()
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
    self.run_seconds = self.run_started_at and math.max(0, os.clock() - self.run_started_at) or nil
    self.flawless_run = self.keys_wrong == 0
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
