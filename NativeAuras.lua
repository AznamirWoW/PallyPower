-- Display-only adapter. Blizzard owns aura matching, instances, visibility and
-- durations; callers supply ordinary unit tokens, spell names and UI positions.
-- No casting buttons or assignment tables are owned by this module.
local NativeAuras = {}
PallyPower.NativeAuras = NativeAuras

local ready, loadFailed, rankNames, spellsDirty
local hosts, timers = {}, {}
local failedTimers = {}
local playerStatus = {}
local filters = {}
local enable
local controller = CreateFrame("Frame")
controller:RegisterEvent("SPELLS_CHANGED")
controller:RegisterEvent("SPELL_DATA_LOAD_RESULT")
controller:RegisterEvent("GROUP_ROSTER_UPDATE")
controller:SetScript("OnEvent", function(_, event)
    if event == "GROUP_ROSTER_UPDATE" then
        if InCombatLockdown() then
            for _, host in pairs(hosts) do
                if host.unit ~= "player" then
                    host.suspended = true
                    for _, display in pairs(host.displays) do enable(display, false) end
                end
            end
        end
    else
        -- Keep the prepared spell snapshot throughout combat.
        spellsDirty = true
    end
end)

local function addSpell(names, id)
    local name = PPAPI.GetSpellInfo(id)
    if name then
        names[name] = names[name] or {}
        names[name][id] = true
    end
end

function NativeAuras:Prepare()
    if spellsDirty and not InCombatLockdown() then
        ready, filters, spellsDirty = nil, {}, false
    end
    if ready then return true end
    if loadFailed or InCombatLockdown() then return false end
    local loaded, reason = C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    if not loaded or not (C_XMLUtil and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) then
        loadFailed = true
        PallyPower:Print("Native aura displays unavailable: " .. tostring(reason or "missing template") .. ". Using remembered timers.")
        return false
    end
    rankNames = {}
    for _, ranks in pairs(PallyPower.NormalBuffs) do
        for _, rank in pairs(ranks) do addSpell(rankNames, rank[2]) end
    end
    for _, ranks in pairs(PallyPower.GreaterBuffs) do
        for _, rank in pairs(ranks) do addSpell(rankNames, rank[2]) end
    end
    ready = true
    return true
end

local function spellFilter(...)
    local names = {}
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if name and name ~= "" then names[#names + 1] = name end
    end
    local key = table.concat(names, "\031")
    if filters[key] then return filters[key][1], filters[key][2] end
    local ids = {}
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if name and name ~= "" then
            for id in pairs(rankNames[name] or {}) do ids[id] = true end
            -- Also resolve the currently learned rank, including seals/auras.
            local _, _, _, _, _, _, id = PPAPI.GetSpellInfo(name)
            if id then ids[id] = true end
        end
    end
    local sorted = {}
    for id in pairs(ids) do sorted[#sorted + 1] = id end
    table.sort(sorted)
    local filter, signature = {includeSpellIDs = ids}, table.concat(sorted, ",")
    filters[key] = {filter, signature}
    return filter, signature
end

local function hostFor(parent, unit, status)
    local host = hosts[parent]
    if not host then
        if InCombatLockdown() then return end
        -- Independent visual sibling: never make native frames protected
        -- descendants of the casting button. Geometry is prepared out of combat.
        local container = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
        container:EnableMouse(false)
        container:EnableMouseWheel(false)
        container:SetSize(1, 1)
        container:SetPoint("TOPLEFT", parent, "TOPLEFT")
        container:SetEnabled(false)
        host = {container = container, parent = parent, active = 0, displays = {}, status = status}
        hosts[parent] = host
        parent:HookScript("OnHide", function()
            host.visible = false
            for _, display in pairs(host.displays) do enable(display, false) end
            container:Hide()
        end)
        parent:HookScript("OnShow", function()
            host.visible = true
            container:Show()
            for _, display in pairs(host.displays) do
                enable(display, display.requested and not host.suspended)
            end
        end)
    end
    if not InCombatLockdown() then
        host.suspended = false
        local scale = parent:GetEffectiveScale() / UIParent:GetEffectiveScale()
        -- Status layers sit behind the original icons, labels and secure wheel.
        local strata = parent:GetFrameStrata()
        local level = math.max(0, parent:GetFrameLevel() + (host.status and -2 or 1))
        if host.scale ~= scale then host.container:SetScale(scale); host.scale = scale end
        if host.strata ~= strata then host.container:SetFrameStrata(strata); host.strata = strata end
        if host.level ~= level then host.container:SetFrameLevel(level); host.level = level end
        -- Effective parent visibility is mirrored by the ordinary parent hooks.
        if host.visible == nil then
            host.visible = parent:IsVisible()
            host.container:SetShown(host.visible)
        end
    end
    if host.unit ~= unit then
        if InCombatLockdown() then return end
        host.container:SetUnit(unit)
        host.unit = unit
    end
    return host
end

enable = function(display, enabled)
    enabled = not not enabled
    if display.enabled ~= enabled then
        display.host.container:SetAuraSlotEnabled(display.key, enabled)
        display.host.active = display.host.active + (enabled and 1 or -1)
        display.enabled = enabled
    end
    local active = display.host.active > 0
    if display.host.enabled ~= active then
        display.host.container:SetEnabled(active)
        display.host.enabled = active
    end
    if display.base then
        display.statusActive = enabled and display.signature ~= "" and not display.host.suspended
        display.base:SetShown(display.statusActive)
        if display.statusActive then
            display.host.parent:SetBackdropColor(0, 0, 0, 0)
        end
    end
end

local function updateFilter(display, filter, signature)
    if display.signature == signature then return end
    display.host.container:SetAuraSlotCandidateFilters(display.key, filter)
    display.signature = signature
end

local function copyTextStyle(text, source)
    text:SetFont(source:GetFont())
    text:SetJustifyH(source:GetJustifyH())
    text:SetJustifyV(source:GetJustifyV())
    text:SetShadowColor(source:GetShadowColor())
    text:SetShadowOffset(source:GetShadowOffset())
    text:SetAllPoints(source)
end

local function timerDisplay(source, unit)
    if failedTimers[source] then return end
    local display = timers[source]
    local status = playerStatus[source]
    local host = hostFor(source:GetParent(), unit, status ~= nil)
    if not host then return end
    if not display then
        if InCombatLockdown() then return end
        display = {host = host, key = source:GetName(), enabled = true}
        if status then
            local base = host.container:CreateTexture(nil, "BACKGROUND")
            base:SetAllPoints(source:GetParent().Center)
            display.base = base
        end
        -- Fixed slots allocate a single AuraButton, rather than a ten-button
        -- group pool, and keep the same frame as the tracked aura is replaced.
        host.container:AddAuraSlot(display.key, "HELPFUL", {
            candidateFilters = {includeSpellIDs = {}},
            sortMethod = AuraContainerSortMethod.ExpirationOnly,
            initializeFrame = function(frame)
                frame:EnableMouse(false)
                frame:EnableMouseWheel(false)
                frame:SetAllPoints(source:GetParent())
                frame:SetFrameLevel(status and host.level + 1 or source:GetParent():GetFrameLevel() + 1)
                if status then
                    local background = frame:CreateTexture(nil, "BACKGROUND")
                    background:SetAllPoints(source:GetParent().Center)
                    -- Keep configured opacity independent of native RGB writes
                    -- on the texture (reload after changing opacity).
                    frame:SetAlpha(PallyPower.opt.cBuffGood.t)
                    -- Use the native CustomAsset presentation API so later
                    -- color updates never call C methods on private regions.
                    display.background = background
                end
                local textParent = frame
                if status then
                    -- Keep the countdown at its previous level above the
                    -- original artwork, while the tile stays behind it.
                    textParent = CreateFrame("Frame", nil, frame)
                    textParent:EnableMouse(false)
                    textParent:EnableMouseWheel(false)
                    textParent:SetIgnoreParentAlpha(true)
                    textParent:SetAllPoints(frame)
                    textParent:SetFrameLevel(source:GetParent():GetFrameLevel() + 1)
                end
                local text = textParent:CreateFontString(nil, "OVERLAY")
                copyTextStyle(text, source)
                frame:SetDurationText(text, {binding = PallyPower:GetAuraTimerBindingTemplate()})
                display.frame, display.text = frame, text
            end,
        })
        -- securecallfunction reports initialization errors but can let slot
        -- creation return. Never publish that partial display or retry its key.
        if not display.frame then
            host.container:SetAuraSlotEnabled(display.key, false)
            if display.base then display.base:Hide() end
            failedTimers[source] = true
            return
        end
        host.active = host.active + 1
        timers[source] = display
        host.displays[source] = display
    end
    return display
end

-- Inputs here are assignment-derived colors, not remembered aura presence.
function NativeAuras:ConfigurePlayerStatus(source, missing)
    playerStatus[source] = missing
end

function NativeAuras:HasPlayerStatus(source)
    -- Locally owned configuration flag, never native aura presence/visibility.
    local display = timers[source]
    return display and display.statusActive or false
end

local function updatePlayerStatus(display, source)
    if not display.base then return end
    local missing, good = playerStatus[source], PallyPower.opt.cBuffGood
    local parent = display.host.parent
    local center = parent.Center
    -- The selected skin contributes its own shading/alpha. A white texture
    -- with identical RGB values can look much brighter than the original tile.
    local skin = parent.backdropInfo.bgFile
    local ulx, uly, _, lly, urx = center:GetTexCoord()
    local asset = display.asset
    local skinChanged = not asset or asset.asset ~= skin
        or asset.texCoords.left ~= ulx or asset.texCoords.right ~= urx
        or asset.texCoords.top ~= uly or asset.texCoords.bottom ~= lly
    if skinChanged then
        display.base:SetTexture(center:GetTexture())
        display.base:SetTexCoord(center:GetTexCoord())
        display.base:SetHorizTile(center:GetHorizTile())
        display.base:SetVertTile(center:GetVertTile())
        asset = {asset = skin, texCoords = {left = ulx, right = urx, top = uly, bottom = lly}}
        display.asset = asset
    end
    display.base:SetVertexColor(missing.r, missing.g, missing.b, missing.t)
    if skinChanged or display.goodR ~= good.r or display.goodG ~= good.g or display.goodB ~= good.b then
        if display.goodR then display.frame:RemoveDispelTypeTexture(display.background) end
        local assets, colors = {}, {}
        local color = CreateColor(good.r, good.g, good.b, 1)
        for _, kind in ipairs({"None", "Magic", "Curse", "Disease", "Poison", "Enrage", "Bleed"}) do
            assets[kind], colors[kind] = asset, color
        end
        display.frame:AddDispelTypeTexture(display.background, {
            showAlways = true,
            style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
            customDispelAssetMap = assets, customDispelColorMap = colors,
        })
        display.goodR, display.goodG, display.goodB = good.r, good.g, good.b
    end
    local shown = source:IsShown()
    if display.timerShown ~= shown then
        -- Keep native presence live even when the user hides countdown text.
        display.frame:SetDurationText(display.text, {
            binding = PallyPower:GetAuraTimerBindingTemplate(),
            textFormat = not shown and {formatString = "", components = {}} or nil,
        })
        display.timerShown = shown
    end
end

function NativeAuras:UpdateTimer(source, unit, ...)
    if not self:Prepare() then return false end
    local display = timerDisplay(source, unit)
    if not display then return false end
    local filter, signature = spellFilter(...)
    updateFilter(display, filter, signature)
    updatePlayerStatus(display, source)
    display.requested = (display.base ~= nil or source:IsShown()) and signature ~= ""
    enable(display, display.requested and source:GetParent():IsVisible() and not display.host.suspended)
    -- Preserve the original region as a layout anchor and option-visibility
    -- flag; its replacement is owned by the native AuraButton.
    source:SetAlpha(0)
    return true
end

function NativeAuras:StopTimer(source)
    local display = timers[source]
    if not display then return end
    display.requested = false
    enable(display, false)
    source:SetAlpha(1)
end

function NativeAuras:DescribeTimer(source)
    local display = timers[source]
    if display then return "native aura slot", display.enabled end
end

-- Configuration only; never inspect private slots or secret-derived visibility.
function NativeAuras:GetAllocationCounts()
    local containers, slots, enabled = 0, 0, 0
    for _, host in pairs(hosts) do containers = containers + 1 end
    for _, display in pairs(timers) do
        slots = slots + 1
        if display.enabled then enabled = enabled + 1 end
    end
    return containers, slots, enabled
end
