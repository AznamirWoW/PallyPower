PallyPower = {isWrath = false}

dofile ("./PallyPowerAutoAssignment.lua")

local kings = PallyPowerAutoAssignmentBuffs.kings
local sanc = PallyPowerAutoAssignmentBuffs.sanc
local wisdom = PallyPowerAutoAssignmentBuffs.wisdom
local might = PallyPowerAutoAssignmentBuffs.might
local salv = PallyPowerAutoAssignmentBuffs.salv
local light = PallyPowerAutoAssignmentBuffs.light

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