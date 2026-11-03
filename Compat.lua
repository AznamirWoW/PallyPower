-- PallyPower Forever API layer.
--
-- PallyPower's own files call these through the private PPAPI table (they alias the names at
-- the top of each file). Each function uses the modern C_ API when the client has it and falls
-- back to the legacy global only when it does not. Nothing is written to the global namespace
-- apart from PPAPI, PP_IS_FOREVER and PP_RESTRICTED, so other addons never see fake replacements
-- for functions Blizzard removed.

local _, build, _, toc = GetBuildInfo()
toc = toc or 0

-- Forever beta reports TOC 16001 (build 1.60.x). Also treat any client whose
-- WOW_PROJECT_ID matches none of the known Classic projects as Forever.
local knownProject = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_CLASSIC)
	or (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
	or (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_WRATH_CLASSIC)
	or (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
PP_IS_FOREVER = (toc >= 16000 and toc < 17000) or (not knownProject and _G.WOW_PROJECT_ID ~= nil)

local issecret = _G.issecretvalue or function() return false end

local API = {}
-- Which implementation each function resolved to, shown by /ppforever.
API.source = {}
PPAPI = API

-- The client throws a "bad argument" usage error for anything that is not a spell ID or a
-- non-empty spell name (an empty string, 0, a boolean, a table). The addon passes such values
-- in a few places (for example the "no seal" slot is ""), so every spell function validates first.
local function validSpell(s)
	local t = type(s)
	if t == "number" then return s > 0 end
	if t == "string" then return s ~= "" end
	return false
end

-- Spells ---------------------------------------------------------------
-- Legacy return order: name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon
if C_Spell and C_Spell.GetSpellInfo then
	API.source.GetSpellInfo = "C_Spell.GetSpellInfo"
	function API.GetSpellInfo(spell)
		if not validSpell(spell) then return end
		local ok, info = pcall(C_Spell.GetSpellInfo, spell)
		if not ok or type(info) ~= "table" then return end
		return info.name, nil, info.iconID, info.castTime, info.minRange, info.maxRange, info.spellID, info.originalIconID
	end
elseif _G.GetSpellInfo then
	API.source.GetSpellInfo = "legacy GetSpellInfo"
	local legacy = _G.GetSpellInfo
	function API.GetSpellInfo(spell)
		if not validSpell(spell) then return end
		local ok, a, b, c, d, e, f, g, h = pcall(legacy, spell)
		if ok then return a, b, c, d, e, f, g, h end
	end
else
	API.source.GetSpellInfo = "none"
	function API.GetSpellInfo() end
end

if C_Spell and C_Spell.GetSpellSubtext then
	API.source.GetSpellSubtext = "C_Spell.GetSpellSubtext"
	function API.GetSpellSubtext(spell)
		if not validSpell(spell) then return end
		local ok, text = pcall(C_Spell.GetSpellSubtext, spell)
		if ok then return text end
	end
elseif _G.GetSpellSubtext then
	API.source.GetSpellSubtext = "legacy GetSpellSubtext"
	local legacy = _G.GetSpellSubtext
	function API.GetSpellSubtext(spell)
		if not validSpell(spell) then return end
		local ok, text = pcall(legacy, spell)
		if ok then return text end
	end
else
	API.source.GetSpellSubtext = "none"
	function API.GetSpellSubtext() end
end

-- Legacy return order: start, duration, enabled(1/0), modRate
if C_Spell and C_Spell.GetSpellCooldown then
	API.source.GetSpellCooldown = "C_Spell.GetSpellCooldown"
	function API.GetSpellCooldown(spell)
		if not validSpell(spell) then return end
		local ok, cd = pcall(C_Spell.GetSpellCooldown, spell)
		if not ok or type(cd) ~= "table" then return end
		local enabled = 1
		local ok2, v = pcall(function() return cd.isEnabled and 1 or 0 end)
		if ok2 then enabled = v end
		return cd.startTime, cd.duration, enabled, cd.modRate
	end
elseif _G.GetSpellCooldown then
	API.source.GetSpellCooldown = "legacy GetSpellCooldown"
	local legacy = _G.GetSpellCooldown
	function API.GetSpellCooldown(spell)
		if not validSpell(spell) then return end
		local ok, a, b, c, d = pcall(legacy, spell)
		if ok then return a, b, c, d end
	end
else
	API.source.GetSpellCooldown = "none"
	function API.GetSpellCooldown() end
end

if C_SpellBook and C_SpellBook.IsSpellKnown then
	API.source.IsSpellKnown = "C_SpellBook.IsSpellKnown"
	function API.IsSpellKnown(id, isPet)
		if not validSpell(id) then return false end
		local bank = nil
		if isPet and Enum and Enum.SpellBookSpellBank then bank = Enum.SpellBookSpellBank.Pet end
		local ok, known = pcall(C_SpellBook.IsSpellKnown, id, bank)
		return ok and known and true or false
	end
elseif _G.IsSpellKnown then
	API.source.IsSpellKnown = "legacy IsSpellKnown"
	local legacy = _G.IsSpellKnown
	function API.IsSpellKnown(id, isPet)
		if not validSpell(id) then return false end
		local ok, known = pcall(legacy, id, isPet)
		return ok and known and true or false
	end
else
	API.source.IsSpellKnown = "none"
	function API.IsSpellKnown() return false end
end

-- Legacy returned 1 / 0 / nil; C_Spell returns true / false / nil (or a hidden value in combat).
if C_Spell and C_Spell.IsSpellInRange then
	API.source.IsSpellInRange = "C_Spell.IsSpellInRange"
	function API.IsSpellInRange(spell, unit)
		if not validSpell(spell) then return nil end
		local ok, r = pcall(C_Spell.IsSpellInRange, spell, unit)
		if not ok or issecret(r) then return nil end
		if r == true then return 1 elseif r == false then return 0 end
		return nil
	end
elseif _G.IsSpellInRange then
	API.source.IsSpellInRange = "legacy IsSpellInRange"
	local legacy = _G.IsSpellInRange
	function API.IsSpellInRange(spell, unit)
		if not validSpell(spell) then return nil end
		local ok, r = pcall(legacy, spell, unit)
		if not ok or issecret(r) then return nil end
		return r
	end
else
	API.source.IsSpellInRange = "none"
	function API.IsSpellInRange() return nil end
end

-- Items ------------------------------------------------------------------
if C_Item and C_Item.GetItemCount then
	API.source.GetItemCount = "C_Item.GetItemCount"
	function API.GetItemCount(...) return C_Item.GetItemCount(...) end
elseif _G.GetItemCount then
	API.source.GetItemCount = "legacy GetItemCount"
	API.GetItemCount = _G.GetItemCount
else
	API.source.GetItemCount = "none"
	function API.GetItemCount() return 0 end
end

-- Chat -------------------------------------------------------------------
if C_ChatInfo and C_ChatInfo.SendChatMessage then
	API.source.SendChatMessage = "C_ChatInfo.SendChatMessage"
	function API.SendChatMessage(...) return C_ChatInfo.SendChatMessage(...) end
elseif _G.SendChatMessage then
	API.source.SendChatMessage = "legacy SendChatMessage"
	API.SendChatMessage = _G.SendChatMessage
else
	API.source.SendChatMessage = "none"
	function API.SendChatMessage() end
end

-- Name returned for an aura that exists but cannot be read (hidden in combat).
PP_RESTRICTED = "<restricted>"

-- Auras ------------------------------------------------------------------
-- Return values match the legacy UnitAura:
-- name, icon, count, debuffType, duration, expirationTime, source, isStealable,
-- nameplateShowPersonal, spellId
-- On the modern client, aura data can be "secret" (restricted in combat), and reading it from
-- addon code can raise a hard error. Everything here is pcall-protected: a restricted aura is
-- returned as an unreadable placeholder so scans carry on to the auras after it.
local MAX_AURA_INDEX = 64 -- safety stop so a loop can never run forever

-- Returned for an aura that exists but cannot be read (e.g. an active seal or a personal
-- cooldown in combat). It must be non-nil so callers that loop "until nil" keep going and
-- still see the auras after it; it matches no real spell name.
local function placeholder()
	return PP_RESTRICTED, nil, 0, nil, 0, 0, nil, nil, nil, 0
end

if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
	local function clean(v, default)
		if issecret(v) then return default end
		return v
	end
	-- Expiry time and duration can be hidden in combat even when the aura name is readable.
	-- Remember the last readable values per unit+aura. The expiry is an absolute timestamp, so the
	-- remembered value keeps counting down correctly while the real one is hidden.
	local timeCache, cacheCount = {}, 0
	local function cacheKey(unit, name)
		local guid
		pcall(function() guid = UnitGUID(unit) end)
		if not guid or issecret(guid) then guid = unit end
		return tostring(guid) .. "|" .. name
	end
	local function toLegacyShape(data, unit)
		if issecret(data.name) then return placeholder() end
		local name = data.name
		local exp, dur = data.expirationTime, data.duration
		if issecret(exp) or issecret(dur) then
			local key = cacheKey(unit, name)
			local cached = timeCache[key]
			if cached and cached.exp > GetTime() then
				exp, dur = cached.exp, cached.dur
			else
				-- first seen while hidden: assume a fresh 60 minute buff (all Forever blessings)
				exp, dur = GetTime() + 3600, 3600
				if cacheCount > 500 then timeCache, cacheCount = {}, 0 end
				timeCache[key] = {exp = exp, dur = dur}
				cacheCount = cacheCount + 1
			end
		elseif exp and exp > 0 then
			local key = cacheKey(unit, name)
			if not timeCache[key] then cacheCount = cacheCount + 1 end
			if cacheCount > 500 then timeCache, cacheCount = {}, 0 end
			timeCache[key] = {exp = exp, dur = dur}
		end
		return name, clean(data.icon), clean(data.applications, 0), clean(data.dispelName),
			dur, exp, clean(data.sourceUnit),
			clean(data.isStealable), clean(data.nameplateShowPersonal), clean(data.spellId, 0)
	end
	local function fetch(unit, index, filter)
		if type(index) ~= "number" or index > MAX_AURA_INDEX then return end
		local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
		if not ok then
			-- "cannot be accessed when secret": the aura is there but hidden from us
			return placeholder()
		end
		if not data then return end
		local ok2, a, b, c2, d, e, f, g, h, i, j = pcall(toLegacyShape, data, unit)
		if not ok2 then return placeholder() end
		return a, b, c2, d, e, f, g, h, i, j
	end

	local srcName = "C_UnitAuras.GetAuraDataByIndex"
	API.source.UnitAura, API.source.UnitBuff, API.source.UnitDebuff = srcName, srcName, srcName
	function API.UnitAura(unit, index, filter)
		return fetch(unit, index, filter)
	end
	function API.UnitBuff(unit, index, filter)
		return fetch(unit, index, filter and (filter .. "|HELPFUL") or "HELPFUL")
	end
	function API.UnitDebuff(unit, index, filter)
		return fetch(unit, index, filter and (filter .. "|HARMFUL") or "HARMFUL")
	end
else
	-- Client without C_UnitAuras: use the legacy calls, still protected so one bad aura
	-- cannot break a scan.
	local function wrapLegacy(name)
		local legacy = _G[name]
		if not legacy then
			API.source[name] = "none"
			API[name] = function() end
			return
		end
		API.source[name] = "legacy " .. name
		API[name] = function(unit, index, filter)
			if type(index) ~= "number" or index > MAX_AURA_INDEX then return end
			local ok, a, b, c, d, e, f, g, h, i, j = pcall(legacy, unit, index, filter)
			if not ok then return placeholder() end
			return a, b, c, d, e, f, g, h, i, j
		end
	end
	wrapLegacy("UnitAura")
	wrapLegacy("UnitBuff")
	wrapLegacy("UnitDebuff")
end

-- Talents ----------------------------------------------------------------
-- The classic (tab, index) talent API has no direct C_ replacement: Forever reworked the
-- Paladin trees and uses a different system. PallyPower only reads it to find Improved
-- Wisdom/Might/Sanctuary ranks, so when the old calls are missing it reports 0 ranks.
API.source.GetNumTalentTabs = _G.GetNumTalentTabs and "legacy GetNumTalentTabs" or "stub (returns 0)"
API.source.GetNumTalents = _G.GetNumTalents and "legacy GetNumTalents" or "stub (returns 0)"
API.source.GetTalentInfo = _G.GetTalentInfo and "legacy GetTalentInfo" or "stub (returns nil)"
API.GetNumTalentTabs = _G.GetNumTalentTabs or function() return 0 end
API.GetNumTalents = _G.GetNumTalents or function() return 0 end
API.GetTalentInfo = _G.GetTalentInfo or function() return nil end
