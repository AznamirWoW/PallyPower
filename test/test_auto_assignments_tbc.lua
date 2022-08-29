PallyPower = {isWrath = false}
function tContains(t, val)
  for _, v in pairs(t) do
    if v == val then
      return true
    end
  end
  return false
end

dofile ("./PallyPowerAutoAssignment.lua")

local wisdom = 1
local might = 2
local kings = 3
local salv = 4
local light = 5
local sanc = 6

local pallys = {"holy", "prot", "ret"}
local available_buffers = {
  [wisdom] = {
    {pallyname = "holy", skill = 9},
    {pallyname = "prot", skill = 7},
    {pallyname = "ret", skill = 7},
  },
  [might] = {
    {pallyname = "holy", skill = 13},
    {pallyname = "prot", skill = 8},
    {pallyname = "ret", skill = 8},
  },
  [kings] = {
    {pallyname = "holy", skill = 1},
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [salv] = {
    {pallyname = "holy", skill = 38},
    {pallyname = "prot", skill = -17},
    {pallyname = "ret", skill = -17},
  },
  [light] = {
    {pallyname = "holy", skill = 10},
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [sanc] = {
    {pallyname = "prot", skill = 6},
  },
}

local assignments = PallyPowerAutoAssignments(pallys, {salv, might, kings, sanc, light}, available_buffers)
assert(assignments[might] == "holy")
assert((assignments[salv] == "prot" and assignments[kings] == "ret") or (assignments[kings] == "prot" and assignments[salv] == "ret"))

-- prot pally doesn't have kings anymore
available_buffers[kings] = {
  {pallyname = "holy", skill = 1},
  {pallyname = "ret", skill = 1},
}
assignments = PallyPowerAutoAssignments(pallys, {salv, might, kings, sanc, light}, available_buffers)
assert(assignments[might] == "holy")
assert(assignments[salv] == "prot" and assignments[kings] == "ret")

pallys = {"prot", "ret"}
available_buffers = {
  [wisdom] = {
    {pallyname = "prot", skill = 7},
    {pallyname = "ret", skill = 7},
  },
  [might] = {
    {pallyname = "prot", skill = 13},
    {pallyname = "ret", skill = 8},
  },
  [kings] = {
    {pallyname = "prot", skill = 1},
  },
  [salv] = {
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [light] = {
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [sanc] = {
    {pallyname = "prot", skill = 1},
  },
}

assignments = PallyPowerAutoAssignments(pallys, {might, kings}, available_buffers)
assert(assignments[might] == "ret")
assert(assignments[kings] == "prot")
assignments = PallyPowerAutoAssignments(pallys, {kings, sanc, might}, available_buffers)
assert(assignments[kings] == "prot")
assert(assignments[might] == "ret")
assert(assignments[sanc] == nil)

pallys = {"prot"}
assignments = PallyPowerAutoAssignments(pallys, {might, kings}, available_buffers)
assert(assignments[might] == "prot")
assignments = PallyPowerAutoAssignments(pallys, {kings, sanc}, available_buffers)
assert(assignments[kings] == "prot")
assert(assignments[sanc] == nil)
assignments = PallyPowerAutoAssignments(pallys, {sanc, kings}, available_buffers)
assert(assignments[kings] == nil)
assert(assignments[sanc] == "prot")

pallys = {"prot", "ret"}
available_buffers[kings] = {{pallyname = "ret", skill = 1}}
assignments = PallyPowerAutoAssignments(pallys, {kings, sanc}, available_buffers)
assert(assignments[kings] == "ret")
assert(assignments[sanc] == "prot")

pallys = {"prot", "ret"}
available_buffers = {
  [wisdom] = {
    {pallyname = "prot", skill = 7},
    {pallyname = "ret", skill = 7},
  },
  [might] = {
    {pallyname = "prot", skill = 13},
    {pallyname = "ret", skill = 8},
  },
  [kings] = {
    {pallyname = "prot", skill = 1},
  },
  [salv] = {
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [light] = {
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [sanc] = {
    {pallyname = "prot", skill = 1},
  },
}

assignments = PallyPowerAutoAssignments(pallys, {wisdom, might}, available_buffers)
assert(assignments[might] == "prot")
assert(assignments[wisdom] == "ret")
-- different order, same outcome
assignments = PallyPowerAutoAssignments(pallys, {might, wisdom}, available_buffers)
assert(assignments[might] == "prot")
assert(assignments[wisdom] == "ret")

available_buffers[kings] = {}
assignments = PallyPowerAutoAssignments(pallys, {might, kings, sanc}, available_buffers)
assert(assignments[might] == "ret")
assert(assignments[sanc] == "prot")

pallys = {"holy1", "holy2", "prot1", "prot2", "ret"}
available_buffers = {
  [wisdom] = {
    {pallyname = "holy1", skill = 9},
    {pallyname = "holy2", skill = 9},
    {pallyname = "prot1", skill = 7},
    {pallyname = "prot2", skill = 7},
    {pallyname = "ret", skill = 7},
  },
  [might] = {
    {pallyname = "holy1", skill = 13},
    {pallyname = "holy2", skill = 12},
    {pallyname = "prot1", skill = 8},
    {pallyname = "prot2", skill = 9},
    {pallyname = "ret", skill = 8},
  },
  [kings] = {
    {pallyname = "holy1", skill = 1},
    {pallyname = "prot1", skill = 1},
    {pallyname = "ret", skill = 1}
  },
  [salv] = {
    {pallyname = "holy1", skill = 1},
    {pallyname = "holy2", skill = 1},
    {pallyname = "prot1", skill = 1},
    {pallyname = "prot2", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [light] = {
    {pallyname = "holy1", skill = 1},
    {pallyname = "holy2", skill = 1},
    {pallyname = "prot1", skill = 1},
    {pallyname = "prot2", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [sanc] = {
    {pallyname = "prot1", skill = 1},
  }
}
assignments = PallyPowerAutoAssignments(pallys, {salv, kings, wisdom, might, sanc, light}, available_buffers)
assert(assignments[salv] == "prot2")
assert(assignments[kings] == "ret")
assert(assignments[wisdom] == "holy2")
assert(assignments[might] == "holy1")
assert(assignments[sanc] == "prot1")

available_buffers[sanc][1].pallyname = "prot2"
assignments = PallyPowerAutoAssignments(pallys, {salv, kings, wisdom, might, sanc, light}, available_buffers)
assert((assignments[salv] == "prot1" and assignments[kings] == "ret") or (assignments[salv] == "ret" and assignments[kings] == "prot1"))
assert(assignments[wisdom] == "holy2")
assert(assignments[might] == "holy1")
assert(assignments[sanc] == "prot2")

-- different order, same outcome
assignments = PallyPowerAutoAssignments(pallys, {sanc, salv, might, wisdom, kings, light}, available_buffers)
assert((assignments[salv] == "prot1" and assignments[kings] == "ret") or (assignments[salv] == "ret" and assignments[kings] == "prot1"))
assert(assignments[wisdom] == "holy2")
assert(assignments[might] == "holy1")
assert(assignments[sanc] == "prot2")

pallys = {"holy", "prot"}
available_buffers = {
  [wisdom] = {
    {pallyname = "holy", skill = 9},
    {pallyname = "prot", skill = 7},
  },
  [might] = {
    {pallyname = "holy", skill = 13},
    {pallyname = "prot", skill = 8},
  },
  [kings] = {},
  [salv] = {
    {pallyname = "holy", skill = 1},
    {pallyname = "prot", skill = 1},
  },
  [light] = {
    {pallyname = "holy", skill = 1},
    {pallyname = "prot", skill = 1},
  },
  [sanc] = {},
}
assignments = PallyPowerAutoAssignments(pallys, {sanc, kings, might, wisdom, light}, available_buffers)
assert(assignments[might] == "holy")
assert(assignments[wisdom] == "prot")
assignments = PallyPowerAutoAssignments(pallys, {wisdom, kings, sanc, might, light, salv}, available_buffers)
assert(assignments[wisdom] == "holy")
assert(assignments[might] == "prot")
