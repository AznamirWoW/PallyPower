-- Native countdowns for a single known aura. Class-minimum timers continue
-- using readable/cached data; none of this code compares secret durations.
local formatter, severityCurve

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

function PallyPower:StopAuraTimer(text)
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
    resources()
    local timer = text.ppAuraTimer
    if not timer then
        local binding = C_DurationUtil.CreateDurationTextBinding()
        binding:SetFontString(text)
        binding:SetFormatter(formatter)
        binding:SetTextColorCurve(severityCurve, Enum.DurationTextBindingProperty.RemainingPercent)
        binding:SetExpiredText("")
        binding:SetZeroDurationText("")
        binding:SetUpdateInterval(1)
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
