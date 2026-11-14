-- Uses the same private API layer as the addon (modern C_ calls first).
local PPAPI = _G.PPAPI or {}
local GetSpellInfo = PPAPI.GetSpellInfo or _G.GetSpellInfo
local GetSpellSubtext = PPAPI.GetSpellSubtext or _G.GetSpellSubtext
local IsSpellKnown = PPAPI.IsSpellKnown or _G.IsSpellKnown

-- /ppforever : prints what this client exposes so the port can be corrected
-- against real Forever data. Safe on every client; only prints to chat.

SLASH_PPFOREVER1 = "/ppforever"
SlashCmdList["PPFOREVER"] = function()
	local function out(...) print("|cff33ff99PP-Forever|r", ...) end
	local version, build, _, toc = GetBuildInfo()
	out("version", version, "build", build, "toc", toc, "WOW_PROJECT_ID", tostring(WOW_PROJECT_ID))
	out("isForever", tostring(PallyPower.isForever), "isVanilla", tostring(PallyPower.isVanilla), "isWrath", tostring(PallyPower.isWrath))
	out("class", select(2, UnitClass("player")), "level", UnitLevel("player"))
	out("group: IsInRaid=", tostring(IsInRaid()), "IsInGroup(instance)=", tostring(IsInGroup(LE_PARTY_CATEGORY_INSTANCE)),
		"IsInInstance=", tostring(select(2, IsInInstance())), "members=", tostring(GetNumGroupMembers()),
		"combat=", tostring(InCombatLockdown()))
	do
		local n, readable, hidden = 0, 0, 0
		local issecret = _G.issecretvalue or function() return false end
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if UnitExists(u) then
				n = n + 1
				local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, u, 1, "HELPFUL")
				if ok and d and not issecret(d.name) then readable = readable + 1 else hidden = hidden + 1 end
			end
		end
		out("raid units", n, "first aura readable:", readable, "hidden/failed:", hidden)
	end
	out("names: UnitName=", tostring(UnitName("player")), "GetUnitName(true)=", tostring(GetUnitName("player", true)),
		"GetUnitName(false)=", tostring(GetUnitName("player", false)))
	out("PallyPower.player=", tostring(PallyPower.player), "PallyPower.realm=", tostring(PallyPower.realm))
	for i = 1, GetNumGroupMembers() do
		local u = IsInRaid() and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
		out("roster", u, tostring(GetUnitName(u, true)), "class", tostring(select(2, UnitClass(u))))
	end
	out("durations normal/greater", PALLYPOWER_NORMALBLESSINGDURATION, PALLYPOWER_GREATERBLESSINGDURATION)
	local rfName, _, rfIcon = GetSpellInfo(25780)
	out("Righteous Fury: name=", tostring(rfName), "icon=", tostring(rfIcon), "known=", tostring(IsSpellKnown(25780)),
		"addon RFSpell=", tostring(PallyPower.RFSpell), "opt.rf=", tostring(PallyPower.opt and PallyPower.opt.rf),
		"opt.rfbuff=", tostring(PallyPower.opt and PallyPower.opt.rfbuff), "button shown=", tostring(PallyPower.rfButton and PallyPower.rfButton:IsShown()))

	local order = { "GetSpellInfo", "GetSpellSubtext", "GetSpellCooldown", "IsSpellKnown", "IsSpellInRange",
		"GetItemCount", "SendChatMessage", "UnitAura", "UnitBuff", "UnitDebuff", "GetTalentInfo", "GetNumTalentTabs" }
	out("API sources (new calls first):")
	for _, n in ipairs(order) do
		out("  " .. n .. " -> " .. tostring(PPAPI.source and PPAPI.source[n] or "not resolved"))
	end
	local apis = { "C_UnitAuras", "C_Spell", "C_SpellBook", "C_Item", "C_ClassTalents", "C_Traits",
		"GetNumTalentTabs", "GetTalentInfo", "GetSpecialization", "UnitBuff", "UnitAura", "GetSpellInfo",
		"IsSpellKnown", "issecretvalue", "C_Timer", "C_ChatInfo" }
	local have = {}
	for _, n in ipairs(apis) do have[#have + 1] = n .. "=" .. (_G[n] and "yes" or "no") end
	out("APIs:", table.concat(have, " "))

	-- Which blessings / greater blessings resolve by name on this client?
	local function nameOf(id)
		local n = GetSpellInfo(id)
		return n
	end
	for i = 1, #PallyPower.Spells do
		local n = PallyPower.Spells[i]
		local rank = n and GetSpellSubtext and GetSpellSubtext(n) or nil
		out("Spell", i, tostring(n), "rank:", tostring(rank))
	end
	for i = 1, #PallyPower.GSpells do
		out("GreaterSpell", i, tostring(PallyPower.GSpells[i]))
	end

	-- Which rank IDs from the Vanilla tables does this character actually know?
	for blessing, ranks in pairs(PallyPower.NormalBuffs) do
		local known = {}
		for _, v in ipairs(ranks) do
			if IsSpellKnown(v[2]) then known[#known + 1] = v[2] end
		end
		out("NormalBuffs", blessing, "known IDs:", #known > 0 and table.concat(known, ",") or "none")
	end
	for blessing, ranks in pairs(PallyPower.GreaterBuffs) do
		local known = {}
		for _, v in ipairs(ranks) do
			if IsSpellKnown(v[2]) then known[#known + 1] = v[2] end
		end
		out("GreaterBuffs", blessing, "known IDs:", #known > 0 and table.concat(known, ",") or "none")
	end
end

-- /ppaura [unit] : shows how the client exposes a unit's buffs RIGHT NOW (run it in combat).
-- For each helpful aura it reports whether the name / expiry are hidden ("secret") from addons.
SLASH_PPAURA1 = "/ppaura"
SlashCmdList["PPAURA"] = function(msg)
	local function out(...) print("|cff33ff99PP-Aura|r", ...) end
	if msg and msg:match("^%s*colors%s*$") then
		local good = PallyPower.opt.cBuffGood
		out("configured good color RGBA:", good.r, good.g, good.b, good.t)
		out("configured background skin:", PallyPower.opt.skin)
		return
	end
	local unit = (msg and msg:match("%S+")) or "target"
	local issecret = _G.issecretvalue or function() return false end
	local exists = UnitExists(unit)
	if issecret(exists) then out("unit existence is hidden; using player"); unit = "player"
	elseif not exists then unit = "player" end
	out("unit", unit, "inCombat", tostring(InCombatLockdown()))
	if PallyPower.NativeAuras then
		local containers, slots, enabled = PallyPower.NativeAuras:GetAllocationCounts()
		out("native allocations: containers", containers, "fixed slots", slots, "enabled slots", enabled,
			"(configuration counts, not aura presence)")
	end
	if unit == "player" then
		for _, entry in ipairs({{"RF", "PallyPowerRFTime1"}, {"seal", "PallyPowerRFTime2"}}) do
			local text = _G[entry[2]]
			local timer = text and text.ppAuraTimer
			local source, enabled
			if text and PallyPower.NativeAuras then source, enabled = PallyPower.NativeAuras:DescribeTimer(text) end
			if source then
				out(entry[1], "timer source:", source, "display enabled:", tostring(enabled), "duration: managed by Blizzard")
			else
				out(entry[1], "timer source:", timer and timer.source or "not bound",
					"active:", tostring(timer and timer.active or false), "secret duration:", tostring(timer and timer.secret or false))
			end
		end
	end
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then out("C_UnitAuras missing") return end
	local hidden, shown, blocked = 0, 0, false
	for i = 1, 40 do
		local ok, d = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
		if not ok then
			blocked = true
			out("scan blocked at index", i, "(not a buff count; raw aura access denied)")
			break
		elseif issecret(d) then
			blocked = true
			out("scan blocked at index", i, "(whole aura table is secret)")
			break
		elseif not d then
			break
		else
			local nameSecret, expSecret = issecret(d.name), issecret(d.expirationTime)
			if nameSecret then hidden = hidden + 1 else shown = shown + 1 end
			out(i, nameSecret and "name=SECRET" or ("name=" .. tostring(d.name)), expSecret and "expiry=SECRET" or "expiry=readable")
		end
	end
	out("readable names:", shown, "hidden names:", hidden, "scan blocked:", tostring(blocked))
end

-- /ppcasts : the last of your own spell casts the addon saw (shows whether the client hides spell ids).
SLASH_PPCASTS1 = "/ppcasts"
SlashCmdList["PPCASTS"] = function()
	local function out(...) print("|cff33ff99PP-Casts|r", ...) end
	local ring = PallyPower._ppCastLog or {}
	out("recorded:", #ring, "click cast:", PallyPower._ppClickCast and PallyPower._ppClickCast.name or "none")
	local sealExp = PallyPower:GetSealExpiration()
	local rfExp = PallyPower:GetRFExpiration()
	local aid = PallyPower_AuraAssignments and PallyPower_AuraAssignments[PallyPower.player]
	out("own auras hidden:", tostring(PallyPower.AurasHidden("player")), "opt.seal:", tostring(PallyPower.opt.seal),
		"seal name:", tostring(PallyPower.Seals[PallyPower.opt.seal]), "seal left:", tostring(sealExp), "RF left:", tostring(rfExp))
	out("assigned aura id:", tostring(aid), "name:", tostring(aid and PallyPower.Auras[aid]), "active:", tostring(PallyPower:IsAuraActive(aid)))
	for _, c in ipairs(ring) do
		out(string.format("%.1f", c.t), c.secret and "spell id HIDDEN" or (tostring(c.id) .. " " .. tostring(c.name)))
	end
end
