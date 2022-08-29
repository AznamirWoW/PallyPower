PallyPower = {isWrath = true}
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
local sanc = 4

local pallys = {"holy", "prot", "ret"}
local available_buffers = {
  [wisdom] = {
    {pallyname = "holy", skill = 11},
    {pallyname = "prot", skill = 9},
    {pallyname = "ret", skill = 9},
  },
  [might] = {
    {pallyname = "holy", skill = 15},
    {pallyname = "prot", skill = 10},
    {pallyname = "ret", skill = 10},
  },
  [kings] = {
    {pallyname = "holy", skill = 1},
    {pallyname = "prot", skill = 1},
    {pallyname = "ret", skill = 1},
  },
  [sanc] = {}
}
local assignments = PallyPowerAutoAssignments(pallys, {kings, wisdom, sanc, might}, available_buffers)
assert(assignments[wisdom] == "holy")
assert((assignments[might] == "prot" and assignments[kings] == "ret") or (assignments[might] == "ret" and assignments[kings] == "prot"))

pallys[4] = "holy2"
available_buffers[wisdom][4] = {pallyname = "holy2", skill = 10}
available_buffers[might][4] = {pallyname = "holy2", skill = 14}
available_buffers[kings][4] = {pallyname = "holy2", skill = 1}
available_buffers[sanc][1] = {pallyname = "holy2", skill = 1}
assignments = PallyPowerAutoAssignments(pallys, {kings, wisdom, sanc, might}, available_buffers)
assert(assignments[wisdom] == "holy")
assert((assignments[might] == "prot" and assignments[kings] == "ret") or (assignments[might] == "ret" and assignments[kings] == "prot"))
assert(assignments[sanc] == "holy2")

available_buffers[wisdom][4].skill = 11
available_buffers[sanc] = {}
assignments = PallyPowerAutoAssignments(pallys, {kings, wisdom, sanc, might}, available_buffers)
assert(assignments[wisdom] == "holy2")
assert(assignments[might] == "holy")
assert(assignments[kings] == "prot" or assignments[kings] == "ret")
