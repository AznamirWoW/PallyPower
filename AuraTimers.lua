-- Native countdowns for a single known aura. Class-minimum timers continue
-- using readable/cached data; none of this code compares secret durations.
local formatter, severityCurve, bindingTemplate

local function available()
    return C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
        and C_DurationUtil.CreateDuration and C_CurveUtil and C_CurveUtil.CreateColorCurve
        and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
        and Enum.DurationTextBindingProperty and Enum.NumericRuleFormatRounding
end

local function resources()
    if formatter then return end
    -- Same m:ss format and red -> yellow -> green gradient as FormatTime /
    -- GetSeverityColor. The native binding does the arithmetic on secret time.
    formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:AddBreakpoint({
        threshold = 0, format = "%d:%02d",
        components = {
            {div = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down},
            {mod = 60, step = 1, rounding = Enum.NumericRuleFormatRounding.Down},
        },
    })
    severityCurve = C_CurveUtil.CreateColorCurve()
    severityCurve:SetType(Enum.LuaCurveType.Linear)
    severityCurve:AddPoint(0, CreateColor(1, 0, 0, 1))
    severityCurve:AddPoint(0.5, CreateColor(1, 1, 0, 1))
    severityCurve:AddPoint(1, CreateColor(0, 1, 0, 1))
end

function PallyPower:GetAuraTimerBindingTemplate()
    if bindingTemplate then return bindingTemplate end
    resources()
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetFormatter(formatter)
    binding:SetTextColorCurve(severityCurve, Enum.DurationTextBindingProperty.RemainingPercent)
    binding:SetExpiredText("")
    binding:SetZeroDurationText("")
    binding:SetUpdateInterval(1)
    bindingTemplate = binding
    return bindingTemplate
end

function PallyPower:CreateAuraTimerBinding(text)
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:Assign(self:GetAuraTimerBindingTemplate())
    binding:SetFontString(text)
    return binding
end

-- Read the prepared casting identity, never change it here. Roster indices can
-- move during combat while the secure button must retain its previous target.
function PallyPower:UpdatePlayerAuraTimer(text, button, unit, blessing)
    if not unit or button.ppWheelName ~= unit.name or button:GetAttribute("unit1") ~= unit.unitid then
        self:StopAuraTimer(text)
        text:SetText("")
        return true
    end
    return self:UpdateAuraTimer(text, unit.unitid, unit.hasbuff, unit.buffDuration,
        self:GetBuffAlternatives(self.Spells[blessing], self.GSpells[blessing]))
end

function PallyPower:StopAuraTimer(text)
    if self.NativeAuras then self.NativeAuras:StopTimer(text) end
    local timer = text.ppAuraTimer
    if timer then
        timer.active = false
        timer.source = nil
        timer.secret = false
        timer.binding:Disable()
    end
end

function PallyPower:UpdateAuraTimer(text, unit, remaining, total, ...)
    if not self.isForever or not available() then return false end
    if self.NativeAuras and self.NativeAuras:UpdateTimer(text, unit, ...) then
        local timer = text.ppAuraTimer
        if timer and timer.binding then
            timer.active = false
            timer.binding:Disable()
        end
        return true
    end
    if not text:IsVisible() then
        self:StopAuraTimer(text)
        return true
    end
    local duration, source
    if PPAPI.GetBuffDuration then duration, source = PPAPI.GetBuffDuration(unit, ...) end
    -- No aura handle is available when the client withholds the aura entirely.
    -- Preserve the existing remembered timer, without presenting it as live data.
    local remembered = not duration and remaining and remaining > 0 and remaining ~= 9999
        and total and total > 0
    if not duration and not remembered then
        self:StopAuraTimer(text)
        text:SetText("")
        return true
    end
    local timer = text.ppAuraTimer
    if not timer then
        local binding = self:CreateAuraTimerBinding(text)
        timer = {binding = binding}
        text.ppAuraTimer = timer
        local parent = text:GetParent()
        parent:HookScript("OnHide", function() binding:Disable() end)
        parent:HookScript("OnShow", function()
            if timer.active and text:IsVisible() then binding:Enable() end
        end)
    end
    if remembered then
        if not timer.remembered then timer.remembered = C_DurationUtil.CreateDuration() end
        timer.remembered:SetTimeFromEnd(GetTime() + remaining, total)
        duration = timer.remembered
    end
    timer.binding:SetDuration(duration)
    timer.source = source or "remembered fallback"
    timer.secret = duration:HasSecretValues()
    timer.active = true
    timer.binding:Enable()
    timer.binding:UpdateFontString()
    return true
end

-- Prepare the existing timer positions before combat, including hidden player
-- pullouts. The adapter owns all native objects and handles later aura updates.
function PallyPower:PrepareAuraDisplays()
    if not self.isForever or InCombatLockdown() or not self.NativeAuras then return end
    if not self.NativeAuras:Prepare() then return end
    self:UpdateAuraTimer(_G.PallyPowerRFTime1, "player", nil, nil, self.opt.rf and self:GetRFSpellName() or nil)
    if not self.opt.rf then self:StopAuraTimer(_G.PallyPowerRFTime1) end
    self:UpdateAuraTimer(_G.PallyPowerRFTime2, "player", nil, nil, self.Seals[self.opt.seal])
    for cb, children in ipairs(self.playerButtons) do
        local class = self.classButtons[cb]:GetAttribute("classID")
        for _, button in ipairs(children) do
            local player = button:GetAttribute("playerID")
            local text = _G[button:GetName() .. "Time"]
            if class and class > 0 and player and player > 0 then
                local unit = self:GetUnit(class, player)
                local blessing = unit and self:GetSpellID(class, unit.name)
                self:UpdatePlayerAuraTimer(text, button, unit, blessing)
            else
                self:StopAuraTimer(text)
            end
        end
    end
end
