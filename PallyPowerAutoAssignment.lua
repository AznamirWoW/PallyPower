PallyPowerAutoAssignmentBuffs = PallyPower.isWrath and {
  wisdom = 1,
  might = 2,
  kings = 3,
  sanc = 4,
} or {
  wisdom = 1,
  might = 2,
  kings = 3,
  salv = 4,
  light = 5,
  sanc = 6,
  sac = 7,
}

local kings = PallyPowerAutoAssignmentBuffs.kings
local sanc = PallyPowerAutoAssignmentBuffs.sanc
local wisdom = PallyPowerAutoAssignmentBuffs.wisdom
local might = PallyPowerAutoAssignmentBuffs.might

local function table_contains(t, val)
  for _, v in pairs(t) do
    if v == val then
      return true
    end
  end
  return false
end

local function get_preferred_imp_buff(buff_prio)
  for _, buff in ipairs(buff_prio) do
    if buff == wisdom or buff == might then
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
        if buff == PallyPowerAutoAssignmentBuffs.salv or buff == PallyPowerAutoAssignmentBuffs.light then
          effective_skill = 1
        end
        table.insert(new_buffers[buff], {pallyname = buffer.pallyname, skill = effective_skill})
      end
    end
  end

  return new_buffers
end

local function calc_imp_skills(pallys, buffers, buff_prio)
  local pref_imp_buff = get_preferred_imp_buff(buff_prio)
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

local function get_most_skilled_buffer(buff_buffers, current_assignments)
  local most_skilled
  for _, candidate in ipairs(buff_buffers) do
    if not table_contains(current_assignments, candidate.pallyname) then
      if most_skilled == nil or candidate.skill > most_skilled.skill then
        most_skilled = candidate
      end
    end
  end

  if most_skilled ~= nil then
    return most_skilled.pallyname
  end

  return nil
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
  local needs_kings = will_get_buff(kings, buff_prio, num_pallys)
  local needs_sanc = will_get_buff(sanc, buff_prio, num_pallys)
  local assignments = {}

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
  local imp_skills = calc_imp_skills(pallys, buffers, buff_prio)
  local assignments = {}
  local num_assignments = 0

  for buff, buffer in pairs(assign_talented_buffers(buff_prio, buffers, #pallys, imp_skills)) do
    assignments[buff] = buffer
    num_assignments = num_assignments + 1
  end

  for _, buff in ipairs(buff_prio) do
    if num_assignments < #pallys and assignments[buff] == nil then
      local buffer
      if buff == might or buff == wisdom then
        buffer = get_most_skilled_buffer(buffers[buff], assignments)
      else
        buffer = get_least_skilled_imp_buffer(buffers[buff], imp_skills, assignments)
      end

      if buffer ~= nil then
        assignments[buff] = buffer
        num_assignments = num_assignments + 1
      end
    end
  end

  return assignments
end
