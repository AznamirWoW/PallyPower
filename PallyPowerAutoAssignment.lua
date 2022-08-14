local function is_wrath()
  return PallyPower.isWrath
end

local wisdom = 1
local might = 2
local kings = 3
local salv = 4
local light = 5
local sanc = 6

if is_wrath() then
  sanc = 4
  salv = nil
  light = nil
end

local function table_contains(t, val)
  for _, v in pairs(t) do
    if v == val then
      return true
    end
  end
  return false
end

local function is_talented_buff(buff)
  if is_wrath() then
    return buff == sanc
  end

  return table_contains({kings, sanc}, buff)
end

local function is_improvable_buff(buff)
  return table_contains({might, wisdom}, buff)
end

local function should_reset_skill(buff)
  return not is_wrath() and (buff == salv or buff == light)
end

local function get_preferred_imp_buff(buff_prio)
  for _, buff in ipairs(buff_prio) do
    if buff == wisdom or buff == might then
      return buff
    end
  end

  return nil
end

local function get_remaining_buffs(pallys, preferred_buffs, assignments)
  local remaining_buffs = {}
  local assigned_buffs = {}
  local num_assignments = 0
  for buff, _ in pairs(assignments) do
    table.insert(assigned_buffs, buff)
    num_assignments = num_assignments + 1
  end

  for _, buff in ipairs(preferred_buffs) do
    if num_assignments < #pallys and not table_contains(assigned_buffs, buff) then
      table.insert(remaining_buffs, buff)
      num_assignments = num_assignments + 1
    end
  end

  return remaining_buffs
end

local function get_assigned_buff(buffer, assignments)
  for buff, b in pairs(assignments) do
    if b == buffer then
      return buff
    end
  end

  return nil
end

local function get_buffer_skill(buffer, buff_buffers)
  for _, b in ipairs(buff_buffers) do
    if b.pallyname == buffer then
      return b.skill
    end
  end

  return 0
end

local function recalc_buff_skills(pallys, orig_buffers)
  local new_buffers = {}
  for buff, buffers in ipairs(orig_buffers) do
    new_buffers[buff] = {}
    for _, buffer in ipairs(buffers) do
      if table_contains(pallys, buffer.pallyname) then
        local effective_skill = buffer.skill
        if should_reset_skill(buff) then
          effective_skill = 1
        end
        table.insert(new_buffers[buff], {pallyname = buffer.pallyname, skill = effective_skill})
      end
    end
  end

  return new_buffers
end

local function calc_imp_skills(pallys, buffers, pref_imp_buff)
  local imp_skills = {}
  for _, pally in ipairs(pallys) do
    local wisdom_skill = get_buffer_skill(pally, buffers[wisdom])
    local might_skill = get_buffer_skill(pally, buffers[might])
    if pref_imp_buff == wisdom then
      wisdom_skill = wisdom_skill * 2
    else
      might_skill = might_skill * 2
    end

    imp_skills[pally] = wisdom_skill + might_skill
  end

  return imp_skills
end

local function filter_available(buff_prio, available_buffers)
  local available_buffs = {}
  for _, buff in ipairs(buff_prio) do
    if #available_buffers[buff] > 0 then
      table.insert(available_buffs, buff)
    end
  end

  return available_buffs
end

local function remove_talented(buff_prio)
  local untalented = {}
  for _, buff in ipairs(buff_prio) do
    if not is_talented_buff(buff) then
      table.insert(untalented, buff)
    end
  end

  return untalented
end

local function get_buff_position(buff_prio, buff)
  for i, b in ipairs(buff_prio) do
    if b == buff then
      return i
    end
  end

  return -1
end

local function will_get_buff(buff, buff_prio, num_pallys)
  local buff_pos = get_buff_position(buff_prio, buff)
  if buff_pos == -1 then
    return false
  end

  return buff_pos <= num_pallys
end

local function get_most_skilled_buffer(buffers, buff, assignments)
  local candidates = {}
  for _, candidate in ipairs(buffers[buff]) do
    if not is_talented_buff(get_assigned_buff(candidate.pallyname, assignments)) then
      table.insert(candidates, candidate)
      most_skilled = candidate
    end
  end


  if #candidates == 0 then
    return nil
  elseif #candidates == 1 then
    return candidates[1].pallyname
  end

  table.sort(candidates, function(a, b) return a.skill > b.skill  end)
  local most_skilled = candidates[1]

  -- swapping only works assuming both players can do both buffs
  if is_improvable_buff(buff) and table_contains(assignments, most_skilled.pallyname) then
    local current = get_assigned_buff(most_skilled.pallyname, assignments)
    local skill_at_current = get_buffer_skill(most_skilled.pallyname, buffers[current])

    -- find someone unassigned that has the same skill at the current buff
    local backup_buffer
    for _, candidate in ipairs(buffers[current]) do
      if not table_contains(assignments, candidate.pallyname) and candidate.skill == skill_at_current then
        backup_buffer = candidate
      end
    end

    if backup_buffer ~= nil then
      assignments[current] = backup_buffer.pallyname
      return most_skilled.pallyname
    end

    local next_available_most_skilled
    for i = 2, #candidates, 1 do
      if next_available_most_skilled == nil and not table_contains(assignments, candidates[i].pallyname) then
        next_available_most_skilled = candidates[i]
      end
    end

    if next_available_most_skilled == nil then
      return nil
    end

    most_skilled = next_available_most_skilled
  end

  return most_skilled.pallyname
end

local function get_least_skilled_imp_buffer(buff_buffers, imp_buffers, current_assignments)
  local least_skilled
  for _, candidate in ipairs(buff_buffers) do
    if not table_contains(current_assignments, candidate.pallyname) then
      if least_skilled == nil or imp_buffers[candidate.pallyname] < imp_buffers[least_skilled] then
        least_skilled = candidate.pallyname
      end
    end
  end

  return least_skilled
end

local function assign_talented_buffers(buff_prio, buffers, num_pallys, imp_buffers)
  -- talented buffs, so if they are needed they will get special treatment
  local assignments = {}
  local needs_sanc = will_get_buff(sanc, buff_prio, num_pallys)

  -- in wrath everyone gets kings, so the only talented buff is sanc
  if is_wrath() and needs_sanc then
    return {[sanc] = get_least_skilled_imp_buffer(buffers[sanc], imp_buffers, assignments)}
  end

  local needs_kings = will_get_buff(kings, buff_prio, num_pallys)

  if needs_kings and needs_sanc then
    if #buffers[kings] == 1 and #buffers[sanc] == 1 then
      if buffers[kings][1].pallyname == buffers[sanc][1].pallyname then
        if get_buff_position(buff_prio, kings) < get_buff_position(buff_prio, sanc) then
          assignments[kings] = get_least_skilled_imp_buffer(buffers[kings], imp_buffers, assignments)
        else
          assignments[sanc] = get_least_skilled_imp_buffer(buffers[sanc], imp_buffers, assignments)
        end
      else
        assignments[kings] = get_least_skilled_imp_buffer(buffers[kings], imp_buffers, assignments)
        assignments[sanc] = get_least_skilled_imp_buffer(buffers[sanc], imp_buffers, assignments)
      end
    elseif #buffers[kings] > 1 and #buffers[sanc] == 1 then
      assignments[sanc] = get_least_skilled_imp_buffer(buffers[sanc], imp_buffers, assignments)
      assignments[kings] = get_least_skilled_imp_buffer(buffers[kings], imp_buffers, assignments)
    else
      -- #buffers[kings] == 1 and #buffers[sanc] > 1 or both > 1.
      -- either way we can assign kings first and there will be someone to do sanc
      assignments[kings] = get_least_skilled_imp_buffer(buffers[kings], imp_buffers, assignments)
      assignments[sanc] = get_least_skilled_imp_buffer(buffers[sanc], imp_buffers, assignments)
    end
  elseif needs_kings and not needs_sanc then
    assignments[kings] = get_least_skilled_imp_buffer(buffers[kings], imp_buffers, assignments)
  elseif needs_sanc and not needs_kings then
    assignments[sanc] = get_least_skilled_imp_buffer(buffers[sanc], imp_buffers, assignments)
  end

  return assignments
end

function PallyPowerAutoAssignments(pallys, preferred_buffs, orig_buffers)
  local buffers = recalc_buff_skills(pallys, orig_buffers)
  local buff_prio = filter_available(preferred_buffs, buffers)
  local pref_imp_buff = get_preferred_imp_buff(buff_prio)
  local imp_skills = calc_imp_skills(pallys, buffers, buff_prio, pref_imp_buff)
  local assignments = {}

  for buff, buffer in pairs(assign_talented_buffers(buff_prio, buffers, #pallys, imp_skills)) do
    assignments[buff] = buffer
  end

  buff_prio = remove_talented(buff_prio)
  buff_prio = get_remaining_buffs(pallys, buff_prio, assignments)

  for _, buff in ipairs(buff_prio) do
    local buffer
    if is_improvable_buff(buff) then
      buffer = get_most_skilled_buffer(buffers, buff, assignments)
    else
      buffer = get_least_skilled_imp_buffer(buffers[buff], imp_skills, assignments)
    end

    if buffer == nil then
      return nil
    end

    assignments[buff] = buffer
  end

  -- make sure a pally is assigned to only one buff, and some nil checks, otherwise return nil
  local verify = {}
  for buff, buffer  in pairs(assignments) do
    if buff == nil or buffer == nil then
      return nil
    end
    if table_contains(verify, buffer) then
      return nil
    end

    table.insert(verify, buffer)
  end

  return assignments
end
