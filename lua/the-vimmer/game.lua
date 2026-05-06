local M = {}

function M.new()
  local g = {
    state = "idle",
    current_room = nil,
    hp = 100,
    streak = 0,
    last_xp = 0,
  }

  function g:start_room(room)
    self.current_room = room
    self.state = "teaching"
  end

  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.state = "playing"
  end

  function g:register_key(key)
    if self.state ~= "playing" then return end
    if not self.current_room then return end
    local optimal = self.current_room.optimal_keystrokes or {}
    for _, k in ipairs(optimal) do
      if k == key then return end
    end
    self.hp = math.max(0, self.hp - 5)
  end

  function g:is_dead()
    return self.hp <= 0
  end

  function g:complete_room()
    if not self.current_room then return end
    local progress = require("the-vimmer.progress")
    self.last_xp = progress.calculate_xp(
      self.current_room.base_xp,
      self.hp,
      self.streak
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
