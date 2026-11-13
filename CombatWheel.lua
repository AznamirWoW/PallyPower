-- All casting choices are prepared outside combat. Ordinary Lua only mirrors
-- the selection for icons, saved assignments and addon communications.
local wheel = [[
    if self:GetAttribute("pp-seal") and IsShiftKeyDown() then
        local enabled = not self:GetAttribute("pp-rf")
        self:SetAttribute("pp-rf", enabled)
        self:SetAttribute("spell1", enabled and self:GetAttribute("pp-rf-spell") or nil)
        self:CallMethod("PPWheelRFChanged", enabled)
        return false
    end
    local count = self:GetAttribute("pp-count") or 0
    if count == 0 then return false end
    if self:GetAttribute("pp-player") and self:GetAttribute("pp-tank-" .. (self:GetAttribute("pp-class") or 0)) ~= nil then
        return false
    end
    local current = self:GetAttribute("pp-selected") or 0
    local player = self:GetAttribute("pp-player")
    local class = self:GetAttribute("pp-class") or 0
    -- Zero inherits the class blessing. Its explicit ID is the same choice.
    if player and current == class then current = 0 end
    local index = 0
    for i = 1, count do
        if self:GetAttribute("pp-choice-" .. i) == current then index = i end
    end
    local direction = offset < 0 and 1 or -1
    if index == 0 then index = direction > 0 and 0 or 1 end
    local selected
    for i = 1, count do
        index = (index - 1 + direction) % count + 1
        selected = self:GetAttribute("pp-choice-" .. index)
        if not player or class == 0 or selected ~= class then break end
    end
    self:SetAttribute("pp-selected", selected)
    self:SetAttribute("pp-wheel-active", true)
    if self:GetAttribute("pp-seal") then
        self:SetAttribute("spell2", self:GetAttribute("pp-seal-" .. selected))
    elseif self:GetAttribute("pp-player") then
        self:RunAttribute("_pp-apply")
    else
        self:SetAttribute("macrotext1", self:GetAttribute("pp-left-" .. selected))
        self:SetAttribute("macrotext2", self:GetAttribute("pp-right-" .. selected))
        for i = 1, self:GetAttribute("pp-children") do
            local child = self:GetFrameRef("pp-child-" .. i)
            child:SetAttribute("pp-class", selected)
            child:RunAttribute("_pp-apply")
        end
    end
    self:CallMethod("PPWheelChanged", selected)
    return false
]]

local applyPlayer = [[
    local class = self:GetAttribute("pp-class") or 0
    local automatic = self:GetAttribute("pp-tank-" .. class)
    if automatic ~= nil then
        self:SetAttribute("pp-selected", automatic)
        self:SetAttribute("pp-auto-active", true)
    elseif self:GetAttribute("pp-auto-active") then
        self:SetAttribute("pp-selected", 0)
        self:SetAttribute("pp-auto-active", nil)
    end
    local normal = self:GetAttribute("pp-selected") or 0
    if automatic == nil and normal == class then
        normal = 0
        self:SetAttribute("pp-selected", 0)
    end
    if normal == 0 then normal = class end
    local left
    if self:GetAttribute("pp-normal-left") then
        left = self:GetAttribute("pp-normal-" .. normal)
    else
        left = self:GetAttribute("pp-greater-" .. class)
    end
    self:SetAttribute("spell1", left)
    self:SetAttribute("spell2", self:GetAttribute("pp-normal-" .. normal))
]]

local function install(button, player, seal)
    if button.PPWheelChanged then return end
    button:SetAttribute("pp-player", player)
    button:SetAttribute("pp-seal", seal)
    if player then button:SetAttribute("_pp-apply", applyPlayer) end
    button.PPWheelChanged = function(btn, selected)
        local pp = PallyPower
        local class = btn:GetAttribute("classID")
        if seal then
            pp:SealAssign(selected)
        elseif not class or class == 0 then
            return
        elseif player then
            local name = btn.ppWheelName
            if not name then return end
            pp:SetNormalBlessing(pp.player, class, name, selected)
        else
            PallyPower_Assignments[pp.player] = PallyPower_Assignments[pp.player] or {}
            PallyPower_Assignments[pp.player][class] = selected
            pp:SendMessage("ASSIGN " .. pp.player .. " " .. class .. " " .. selected)
            for _, child in ipairs(btn.ppWheelChildren) do
                local name, value = child.ppWheelName, child:GetAttribute("pp-selected")
                local assignments = PallyPower_NormalAssignments[pp.player]
                local personal = assignments and assignments[class]
                if (personal and personal[name] or 0) ~= value then
                    pp:SetNormalBlessing(pp.player, class, name, value)
                end
            end
        end
        if InCombatLockdown() then
            pp:ButtonsUpdate()
        else
            pp:UpdateLayout()
        end
    end
    if seal then
        button.PPWheelRFChanged = function(_, enabled)
            PallyPower.opt.rf = enabled
            PallyPower:RFAssign()
            PallyPower:ButtonsUpdate()
        end
    end
    SecureHandlerWrapScript(button, "OnMouseWheel", button, wheel)
end

local function choices(button, values)
    button:SetAttribute("pp-count", #values)
    for i, value in ipairs(values) do button:SetAttribute("pp-choice-" .. i, value) end
    button:SetAttribute("pp-wheel-active", nil)
end

local function addTarget(macros, id, spell, target)
    if not spell then return end
    local entry = macros[id]
    if not entry then
        entry = {spell = spell, targets = {}}
        macros[id] = entry
    end
    -- Keep each macro at a rank appropriate for every target it can select.
    if entry.spell == spell then entry.targets[#entry.targets + 1] = target end
end

local function castMacro(entry)
    if entry then return "/cast " .. table.concat(entry.targets) .. " " .. entry.spell end
end

local function tankBlessing(pp, class, unit, blessing)
    if not unit or not IsInRaid() then return end
    local raidIndex = unit.unitid:match("^raid(%d+)$")
    local role = raidIndex and select(10, GetRaidRosterInfo(tonumber(raidIndex)))
    return pp:GetTankBlessing(class, role, unit.name, blessing)
end

function PallyPower:PrepareCombatWheel()
    if InCombatLockdown() or not self.isForever or not self.classButtons then return end
    local sealButton = self.rfButton
    install(sealButton, false, true)
    local seals = {0} -- preserve the existing "no seal" selection
    for id = 1, self.isWrath and 9 or 11 do
        local name, _, _, _, _, _, spellID = PPAPI.GetSpellInfo(self.Seals[id])
        if spellID and PPAPI.IsSpellKnown(spellID) then
            seals[#seals + 1] = id
            sealButton:SetAttribute("pp-seal-" .. id, name)
        else
            sealButton:SetAttribute("pp-seal-" .. id, nil)
        end
    end
    choices(sealButton, seals)
    sealButton:SetAttribute("pp-selected", self.opt.seal or 0)
    sealButton:SetAttribute("pp-rf", self.opt.rf and true or false)
    sealButton:SetAttribute("pp-rf-spell", self:GetRFSpellName())
    -- The existing left-click convention uses normal blessings until a Greater
    -- Blessing has been learned. Freeze that decision for the combat interval.
    local normalLeft = self:UseNormalForLeftClick()
    for cb, button in ipairs(self.classButtons) do
        install(button, false)
        local class = button:GetAttribute("classID")
        local classChoices = {}
        if class and class > 0 then
            for id = 1, 6 do
                if self:CanBuff(self.player, id) and self:NeedsBuff(class, id, nil, true) then
                    classChoices[#classChoices + 1] = id
                end
            end
        end
        choices(button, classChoices)
        local assigned = class and PallyPower_Assignments[self.player]
        local classSelection = assigned and assigned[class] or 0
        button:SetAttribute("pp-selected", classSelection)
        local childCount = 0
        button.ppWheelChildren = {}
        local leftMacros, rightMacros = {}, {}
        for pb, child in ipairs(self.playerButtons[cb]) do
            install(child, true)
            local playerID = child:GetAttribute("playerID")
            local unit = class and class > 0 and playerID and playerID > 0 and self:GetUnit(class, playerID)
            child.ppWheelName = unit and unit.name or nil
            local playerChoices = {0} -- zero clears the personal override
            child:SetAttribute("pp-class", classSelection)
            child:SetAttribute("pp-normal-left", normalLeft)
            child:SetAttribute("pp-auto-active", nil)
            local personal = class and PallyPower_NormalAssignments[self.player]
            personal = personal and personal[class]
            child:SetAttribute("pp-selected", unit and personal and personal[unit.name] or 0)
            if unit then
                childCount = childCount + 1
                button.ppWheelChildren[childCount] = child
                SecureHandlerSetFrameRef(button, "pp-child-" .. childCount, child)
            end
            for id = 0, 7 do
                child:SetAttribute("pp-tank-" .. id, tankBlessing(self, class, unit, id))
                local normal, greater
                if unit and id > 0 and self:CanBuff(self.player, id) then
                    normal, greater = self:GetAssignableBlessings(class, unit, id, id)
                    if normal and self:NeedsBuff(class, id, unit.name, true) then
                        playerChoices[#playerChoices + 1] = id
                    end
                end
                child:SetAttribute("pp-normal-" .. id, normal)
                child:SetAttribute("pp-greater-" .. id, greater)
                if unit and id > 0 then
                    local target = "[@" .. unit.name .. ",help,nodead]"
                    -- A prepared list supplies fallback targets when someone
                    -- dies. Range and buff-state decisions stay outside combat.
                    addTarget(rightMacros, id, normal, target)
                    local left = normalLeft and normal or greater
                    addTarget(leftMacros, id, left, target)
                end
            end
            choices(child, unit and playerChoices or {})
        end
        button:SetAttribute("pp-children", childCount)
        for id = 1, 6 do
            button:SetAttribute("pp-left-" .. id, castMacro(leftMacros[id]))
            button:SetAttribute("pp-right-" .. id, castMacro(rightMacros[id]))
        end
    end
end
