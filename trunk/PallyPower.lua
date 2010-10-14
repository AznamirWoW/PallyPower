PallyPower = LibStub("AceAddon-3.0"):NewAddon("PallyPower", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")
--_G.PallyPower = PallyPower

local L    = LibStub("AceLocale-3.0"):GetLocale("PallyPower")
local LSM3 = LibStub("LibSharedMedia-3.0")

-- BINDINGs labels
BINDING_HEADER_PALLYPOWER = "PallyPower"
BINDING_NAME_PPBUFFCYCLE  = L["Change blessing"]
BINDING_NAME_PPAURACYCLEP = L["Cycle to previous aura"]
BINDING_NAME_PPAURACYCLEN = L["Cycle to next aura"]
BINDING_NAME_PPSEALCYCLEP = L["Cycle to previous seal"]
BINDING_NAME_PPSEALCYCLEN = L["Cycle to next seal"]

local settings

local tinsert = table.insert
local tremove = table.remove
local twipe = table.wipe
local tsort = table.sort
local sfind = string.find
local ssub = string.sub
local sformat = string.format

local isPally = false

-- buttons 
local PallyPowerHeader
local PallyPowerAuto
local PallyPowerRF
local PallyPowerAura

-- unit tables
local party_units = {}
local raid_units = {}
local roster = {}

do
	--print("Roster Table init")
	table.insert(party_units, "player")
	--table.insert(party_units, "pet")

	for i = 1, MAX_PARTY_MEMBERS do
		table.insert(party_units, ("party%d"):format(i))
		--table.insert(party_units, ("partypet%d"):format(i))
	end
	
	for i = 1, MAX_RAID_MEMBERS do
		table.insert(raid_units, ("raid%d"):format(i))
		--table.insert(raid_units, ("raidpet%d"):format(i))
	end
end

PallyPower.Credits1 = "Pally Power - by Aznamir (Lightbringer US)";

-------------------------------------------------------------------
-- Spell Settings
-------------------------------------------------------------------

PallyPower.Spells = {
	[0] = "",
	[1] = GetSpellInfo(19740), --Blessing of Might
	[2] = GetSpellInfo(20217), --Blessing of Kings
	[3] = "",
};

PallyPower.RFSpell = GetSpellInfo(25780) -- Righteous Fury
PallyPower.HLSpell = GetSpellInfo(635)	 -- Holy Light
PallyPower.MSpell = GetSpellInfo(1126) -- Mark of the Wild

PallyPower.Seals = {
    [0] = "",
	[1] = GetSpellInfo(20154), -- seal of righteousness
	[2] = GetSpellInfo(20165), -- seal of insight
	[3] = GetSpellInfo(31801), -- seal of truth
	[4] = GetSpellInfo(20164), -- seal of justice
	[5] = "",
}

PallyPower.Auras = {
	[0] = "",
	[1] = GetSpellInfo(465),   --Devotion Aura
	[2] = GetSpellInfo(7294),  --Retribution Aura
	[3] = GetSpellInfo(19746), --Concentration Aura
	[4] = GetSpellInfo(19891), --Resistance Aura
	[5] = GetSpellInfo(32223), --Crusader Aura
	[6] = "",
}

-------------------------------------------------------------------
-- Interface settings
-------------------------------------------------------------------
PallyPower.options = 
{
	type = "group",
	name = "PallyPower",
	--handler = PallyPower,
	icon = "Interface\Icons\Spell_Holy_SummonChampion",
	args = {
		desc = {
			type = "description",
			order = 0,
			name = L["MOVE_DESC"],
		},
		buffscale = {
			type = "range",
			order = 1,
			name = L["BSC"],
			desc = L["BSC_DESC"],
			min = 0.4,
			max = 1.5,
			step = 0.05,
			get = function(info) return settings.buffscale end,
			set = function(info, val)
					settings.buffscale = val
					PallyPower:UpdateLayout()
				end,
		},
		reset = {
			type = "execute",
			order = 2,
			name = L["RESET"],
			desc = L["RESET_DESC"],
			func = function() PallyPower:Reset() end,			
		},
		showparty = {
			type = "toggle",
			order = 17,
			name = L["SHOWPARTY"],
			desc = L["SHOWPARTY_DESC"],
			get = function(info) return settings.display.ShowInParty end,
			set = function(info, val)
				settings.display.ShowInParty = val
				--PallyPower:UpdateRoster()
				end,
		},
		showsingle = {
			type = "toggle",
			order = 18,
			name = L["SHOWSINGLE"],
			desc = L["SHOWSINGLE_DESC"],
			get = function(info) return settings.display.ShowWhenSingle end,
			set = function(info, val)
					settings.display.ShowWhenSingle = val
					--PallyPower:UpdateRoster()
				end,
		},				
		extras = {
			type = "toggle",
			order = 19,
			name = L["IGNOREEXTRA"],
			desc = L["IGNOREEXTRADESC"],
			get = function(info) return settings.extras end,
			set = function(info, val)
					settings.extras = val
					PallyPower:UpdateRoster()
				end,
		},
		display = {
			type = "group",
			order = 3,
			name = L["DISP"],
			desc = L["DISP_DESC"],
			args = {
			    layout = {
					type = "select",
					order = 4,
					name = L["LAYOUT"],
					desc = L["LAYOUT_DESC"],
					get = function(info) return settings.layout end,
					set = function(info,val)
						settings.layout = val
						PallyPower:UpdateLayout()
						end,
					values = {
						["Layout 1"] = L["Up"],
						["Layout 2"] = L["Down"],
						["Layout 3"] = L["Right"],
						["Layout 4"] = L["Left"],
					},
				},
				skin = {
					type = "select",
					order = 5,
					name = L["SKIN"],
					desc = L["SKIN_DESC"],
					dialogControl = "LSM30_Background",
					values = AceGUIWidgetLSMlists.background,
					get = function(info) return settings.skin end,
					set = function(info,val)
						settings.skin = val
						PallyPower:ApplySkin()
						end,
				},
				edges = {
					type = "select",
					order = 6,
					name = L["DISPEDGES"],
					desc = L["DISPEDGES_DESC"],
					dialogControl = "LSM30_Border",
					values = AceGUIWidgetLSMlists.border,
					get = function(info) return settings.border end,
					set = function(info,val)
						settings.border = val
						PallyPower:ApplySkin()
						end,
				},
				colors = {
					type = "header",
					order = 7,
					name = L["Colors"],
				},
				color_good = {
					type = "color",
					order = 8,
					name = L["Fully Buffed"],
					get = function() return settings.cBuffGood.r, settings.cBuffGood.g, settings.cBuffGood.b, settings.cBuffGood.t end,
					set = function (info, r, g, b, t)
							settings.cBuffGood.r = r
							settings.cBuffGood.g = g
							settings.cBuffGood.b = b
							settings.cBuffGood.t = t
						end,
					hasAlpha = true,
				},
				color_partial = {
					type = "color",
					order = 9,
					name = L["Partially Buffed"],
					get = function() return settings.cBuffNeedSome.r, settings.cBuffNeedSome.g, settings.cBuffNeedSome.b, settings.cBuffNeedSome.t end,
					set = function (info, r, g, b, t)
							settings.cBuffNeedSome.r = r
							settings.cBuffNeedSome.g = g
							settings.cBuffNeedSome.b = b
							settings.cBuffNeedSome.t = t
						end,
					hasAlpha = true,
				},
				color_missing = {
					type = "color",
					order = 10,
					name = L["None Buffed"],
					get = function() return settings.cBuffNeedAll.r, settings.cBuffNeedAll.g, settings.cBuffNeedAll.b, settings.cBuffNeedAll.t end,
					set = function (info, r, g, b, t)
							settings.cBuffNeedAll.r = r
							settings.cBuffNeedAll.g = g
							settings.cBuffNeedAll.b = b
							settings.cBuffNeedAll.t = t
						end,
					hasAlpha = true,
				},
				rfs = {
					type = "group",
					order = 11,
					name = L["RFM"],
					desc = L["RFM_DESC"],
					args = {
						rfbutton = {
							type = "toggle",
							order = 11,
							name = L["RFB"],
							desc = L["RFB_DESC"],
							get = function(info) return settings.rfbuff end,
							set = function(info, val)
								settings.rfbuff = val
								PallyPower:UpdateLayout()
								end,
						},
						rfury = {
							type = "toggle",
							order = 12,
							name = L["RFUSE"],
							desc = L["RFUSE_DESC"],
							get = function(info) return settings.rf end,
							set = function(info, val)
								settings.rf = val
								PallyPower:RFAssign(settings.rf)
								end,
						},
					},
				},
				auras = {
					type = "group",
					order = 13,
					name = L["AURAM"],
					desc = L["AURAM_DESC"],
					args = {
						aurabutton = {
							type = "toggle",
							order = 14,
							name = L["AURABTN"],
							desc = L["AURABTN_DESC"],
							get = function(info) return settings.auras end,
							set = function(info, val)
								settings.auras = val
								PallyPower:UpdateLayout()
								end,
						},
						aura = {
							type = "select",
							order = 15,
							name = L["AURA"],
							desc = L["AURA_DESC"],
							get = function(info) return settings.aura end,
							set = function(info, val)
								settings.aura = val
								PallyPower:UpdateLayout()
								end,
							values = {
								[0] = L["None"],
								[1] = PallyPower.Auras[1],
								[2] = PallyPower.Auras[2],
								[3] = PallyPower.Auras[3],
								[4] = PallyPower.Auras[4],
								[5] = PallyPower.Auras[5],
							},
						},
						seal = {
							type = "select",
							order = 16,
							name = L["SEAL"],
							desc = L["SEAL_DESC"],
							get = function(info) return settings.seal end,
							set = function(info, val)
								settings.seal = val
								PallyPower:SealAssign(settings.seal)
								end,
							values = {
								[0] = L["None"],
								[1] = PallyPower.Seals[1],
								[2] = PallyPower.Seals[2],
								[3] = PallyPower.Seals[3],
								[4] = PallyPower.Seals[4],
							},
						},
					},
				},
			},      -- display args
		}, -- main args
	},
}

PallyPower.Layouts = {
	["Layout 1"] = { 	
				ab = {x = 0, y = 1},
				au = {x = 0, y = 2},
				rf = {x = 0, y = 3},
	},
	["Layout 2"] = { 	
				ab = {x = 0, y = 0},
		 		au = {x = 0, y = -1},
    			rf = {x = 0, y = -2},
	},	
	["Layout 3"] = { 	
				ab = {x = 0, y = 0},
		 		au = {x = 1, y = 0},
    			rf = {x = 2, y = 0},
	},
	["Layout 4"] = { 	
				ab = {x = -1, y = 0},
		 		au = {x = -2, y = 0},
    			rf = {x = -3, y = 0},
	},	
 }
-------------------------------------------------------------------
-- Default Settings
-------------------------------------------------------------------
PallyPower.defaults = {
	profile = {
		buffscale = 0.9,
		rfbuff = true,
		auras = true,
		extras = false,
		display = {
			buttonWidth = 100,
			buttonHeight = 34,
			ShowInParty = true,
			ShowWhenSingle = true,
		},
		border = "Blizzard Tooltip",
		skin = "Solid",
		cBuffNeedAll     = {r = 1.0, g = 0.0, b = 0.0, t = 0.5},
		cBuffNeedSome    = {r = 1.0, g = 1.0, b = 0.5, t = 0.5},
		cBuffGood        = {r = 0.0, g = 0.7, b = 0.0, t = 0.5},
		sets = { 
			["primary"] = {
							seal = 1,
							aura = 1,
							rf   = false,
							buff = 2,
						},
			["secondary"] = {
							seal = 1,
							aura = 1,
							rf   = false,
							buff = 2,
						},
		},
		-- default assignments
		seal = 1,
		aura = 1,
		rf   = false,
		buff = 2,
		disabled = false,
		layout = "Layout 1",
	}
}

-------------------------------------------------------------------
-- Ace Framework Events
-------------------------------------------------------------------
function PallyPower:OnInitialize()
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99"..PallyPower.Credits1.."|r")
	local _, class = UnitClass("player")
	if (class == "PALADIN") then
		isPally = true
	else
		isPally = false
	end

	self.db = LibStub("AceDB-3.0"):New("PallyPowerDB", PallyPower.defaults, "Default")
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")	
	
	settings = self.db.profile
	PallyPower.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("PallyPower", PallyPower.options, "pp")
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("PallyPower", "PallyPower")
	
	--LSM3.RegisterCallback( self, "LibSharedMedia_Registered", "MediaUpdate")
	--LSM3.RegisterCallback( self, "LibSharedMedia_SetGlobal", "MediaUpdate")
	
	LSM3:Register("background", "None", 			"Interface\\Tooltips\\UI-Tooltip-Background")
	LSM3:Register("background", "Banto",			"Interface\\AddOns\\PallyPower\\Skins\\Banto")
	LSM3:Register("background", "BantoBarReverse", 	"Interface\\AddOns\\PallyPower\\Skins\\BantoBarReverse")
	LSM3:Register("background", "Glaze", 			"Interface\\AddOns\\PallyPower\\Skins\\Glaze")
	LSM3:Register("background", "Gloss", 			"Interface\\AddOns\\PallyPower\\Skins\\Gloss")
	LSM3:Register("background", "Healbot", 			"Interface\\AddOns\\PallyPower\\Skins\\Healbot")
	LSM3:Register("background", "oCB", 				"Interface\\AddOns\\PallyPower\\Skins\\oCB")
	LSM3:Register("background", "Smooth", 			"Interface\\AddOns\\PallyPower\\Skins\\Smooth")

	self.player = UnitName("player")
	
	_G["BINDING_NAME_CLICK PallyPowerAutoBtn:LeftButton"]  = L["Cast selected blessing"]
	_G["BINDING_NAME_CLICK PallyPowerAuraBtn:LeftButton"]  = L["Cast selected aura"]
	_G["BINDING_NAME_CLICK PallyPowerAuraBtn:RightButton"] = L["Cast selected seal"]
	
	if settings.seal > 4 then settings.seal = 1 end
	if settings.aura > 5 then settings.aura = 1 end
	
	self:CreateLayout()
	
	if settings.skin then
		PallyPower:ApplySkin(settings.skin)
 	end
	
end

function PallyPower:OnProfileChanged()
	settings = self.db.profile
	PallyPower:UpdateLayout()
end

function PallyPower:OnEnable()
	if isPally then
		settings.disabled = false
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		self:RegisterBucketEvent({"RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "UNIT_PET"}, 1, "UpdateRoster")
		self:UpdateRoster()
	else
		settings.disabled = true
	end
end

function PallyPower:OnDisable()
	-- events
	settings.disabled = true
	self:UpdateLayout()
end

function PallyPower:MediaUpdate()

end
-------------------------------------------------------------------
-- Service Functions
-------------------------------------------------------------------
function PallyPower:FormatTime(time)
	if not time or time < 0 or time == 9999 then
		return ""
	end
	local mins = floor(time / 60)
	local secs = time - (mins * 60)
	return sformat("%d:%02d", mins, secs)
end

-------------------------------------------------------------------
-- Command Prompt Response
-------------------------------------------------------------------
function PallyPower:Reset()
	local h = _G["PallyPowerFrame"]
	h:ClearAllPoints()
	h:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	self:UpdateLayout()
end

-------------------------------------------------------------------
-- Internal Functions
-------------------------------------------------------------------
function PallyPower:GetNumUnits()
	if GetNumRaidMembers() > 0 then
		return GetNumRaidMembers()
	end
	if GetNumPartyMembers() > 0 and settings.display.ShowInParty or settings.display.ShowWhenSingle then
		return GetNumPartyMembers() + 1
	end
	return 0
end
-------------------------------------------------------------------
-- External Event Handling
-------------------------------------------------------------------
function PallyPower:ACTIVE_TALENT_GROUP_CHANGED()
	local old, new
	if isPally then
		if GetActiveTalentGroup() == 1 then
			old = "secondary"
			new = "primary"
		else
			old = "primary"
			new = "secondary"
		end
		
		settings.sets[old].seal = settings.seal
		settings.sets[old].aura = settings.aura
		settings.sets[old].rf   = settings.rf
		settings.sets[old].buff = settings.buff
		
		settings.seal = settings.sets[new].seal
		settings.aura = settings.sets[new].aura
		settings.rf   = settings.sets[new].rf
		settings.buff = settings.sets[new].buff

		PallyPower:UpdateLayout()
	end
end

function PallyPower:PLAYER_REGEN_ENABLED()
	if isPally then self:UpdateLayout() end
end

-- Bucket for "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "UNIT_PET" events
function PallyPower:UpdateRoster()
	-- stop update timer
	self:CancelTimer(self.UpdateTimer)
	
	local units
	local num = self:GetNumUnits()
	local isInRaid
	
	local skip = settings.extras

	if num > 0 then
		num = 0
		if GetNumRaidMembers() == 0 then
			isInRaid = false
			units = party_units
		else
			isInRaid = true
			units = raid_units
		end
	
		twipe(roster)

		for _, unitid in ipairs(units) do
			--PallyPower:Print(unitid)
			if unitid and UnitExists(unitid) then
				local tmp = {}
				num = num + 1
				tmp.unitid = unitid
			
				if isInRaid then
					local n = select(3, unitid:find("(%d+)"))
					tmp.subgroup = select(3, GetRaidRosterInfo(n))
				else
					tmp.subgroup = 1
				end
			
				if tmp.subgroup < 6 or not skip then
					tinsert(roster, tmp)
				end
			end
		end
	end
	
	PallyPower:UpdateLayout()

	if num > 0 and isPally then
		-- start update timer
		self.UpdateTimer = self:ScheduleRepeatingTimer("ButtonsUpdate", 2)
	end
end

-------------------------------------------------------------------
-- Buff Checks
-------------------------------------------------------------------
function PallyPower:GetBuffExpiration()
	
	local spellName = PallyPower.Spells[settings.buff]
	local markName = PallyPower.MSpell
	local classExpire, classDuration, have, need = 9999, 9999, 0, 0
	if spellName then
		for playerID, unit in pairs(roster) do
			if unit.unitid then
				if IsSpellInRange(PallyPower.HLSpell, unit.unitid) == 1 then
					
					local _, _, _, _, _, buffDuration, buffExpire = UnitBuff(unit.unitid, spellName)
					
					if not buffExpire and settings.buff == 2 then -- Kings fallback to MotW
						_, _, _, _, _, buffDuration, buffExpire = UnitBuff(unit.unitid, markName)
					end
					
					if buffExpire then
						buffExpire = buffExpire - GetTime()
						classExpire = min(classExpire, buffExpire)
						classDuration = min(classDuration, buffDuration)
						have = have + 1
					else
						need = need + 1
					end
				end
			end
		end
	end
	return classExpire, classDuration, have, need
end

function PallyPower:GetRFExpiration()
    local spellName = PallyPower.RFSpell
    local rfExpire = 9999
	local _, _, _, _, _, buffDuration, buffExpire = UnitBuff("player", spellName)
	if buffExpire then
		rfExpire = buffExpire - GetTime()
	end
	return rfExpire
end

function PallyPower:GetSealExpiration()
    local spellName = PallyPower.Seals[settings.seal]
    local sealExpire, sealDuration = 9999, 30*60
	local _, _, _, _, _, buffDuration, buffExpire = UnitBuff("player", spellName)
	if buffExpire then
		sealExpire = buffExpire - GetTime()
	end
	return sealExpire, sealDuration
end

function PallyPower:GetAuraExpiration()
    local spellName = PallyPower.Auras[settings.aura]
    local auraExpire = 9999
	local buffName, _, _, _, _, _, _ = UnitBuff("player", spellName)
	if buffName == spellName then
		auraExpire = 60*60
	end
	return auraExpire
end

-------------------------------------------------------------------
-- Buff Assignment
-------------------------------------------------------------------
function PallyPower:BuffAssign(buff)
	settings.buff = buff
	local spellName, _, spellIcon = GetSpellInfo(PallyPower.Spells[buff])
	local bufficon = _G["PallyPowerAutoBtnBuffIcon"]
	bufficon:SetTexture(spellIcon)
	PallyPowerAuto:SetAttribute("spell1", spellName)
end

function PallyPower:RFAssign(rf)
	local spellName, _, spellIcon = GetSpellInfo(PallyPower.RFSpell)
	local rfIcon = _G["PallyPowerRFBtnIconRF"]
	
	settings.rf = rf
	
	if rf then
		rfIcon:SetTexture(spellIcon)
		PallyPowerRF:SetAttribute("spell1", spellName)
	else
		rfIcon:SetTexture(nil)
		PallyPowerRF:SetAttribute("spell1", nil)
	end
end

function PallyPower:AuraAssign(aura)
	local spellName, _, spellIcon = GetSpellInfo(PallyPower.Auras[aura])
	local auraIcon = _G["PallyPowerAuraBtnIconAura"] -- aura icon

	settings.aura = aura

	auraIcon:SetTexture(spellIcon)
	PallyPowerAura:SetAttribute("spell1", spellName)
end

function PallyPower:SealAssign(seal)
	local spellName, _, spellIcon = GetSpellInfo(PallyPower.Seals[seal])
	local sealIcon = _G["PallyPowerAuraBtnIconSeal"] -- seal icon

	settings.seal = seal

	sealIcon:SetTexture(spellIcon)
	PallyPowerAura:SetAttribute("spell2", spellName)
end

-------------------------------------------------------------------
-- Buff Modifiers
-------------------------------------------------------------------
function PallyPower:PerformBuffCycle()
	if not settings.buff then 
		settings.buff = 1
	end

	if settings.buff == 1 then
		settings.buff = 2
	else
		settings.buff = 1
	end

	PallyPower:BuffAssign(settings.buff)
end

function PallyPower:PerformRFCycle()
	settings.rf = not settings.rf
	PallyPower:RFAssign(settings.rf)
end

function PallyPower:PerformAuraCycle()
	if not settings.aura then
	   	settings.aura = 0
	end

	cur = settings.aura

	for test = cur + 1, 6 do
	    cur = test
	    if GetSpellInfo(PallyPower.Auras[cur]) then 
			do break end
		end
	end
	
	if cur == 6 then 
		cur = 0
	end
	
	PallyPower:AuraAssign(cur)
end

function PallyPower:PerformAuraCycleBackward()
	if not settings.aura then 
		settings.aura = 0
	end
	
	cur = settings.aura
	
	if cur == 0 then 
		cur = 6 
	end
	
	for test=cur-1, 0, -1 do
		cur = test
		if GetSpellInfo(PallyPower.Auras[cur]) then
			do break end
		end
	end
	PallyPower:AuraAssign(cur)

end

function PallyPower:PerformSealCycle()
    if not settings.seal then
	   	settings.seal = 0
	end
	
	cur = settings.seal
	
	for test = cur + 1, 5 do
	    cur = test
	    if GetSpellInfo(PallyPower.Seals[cur]) then 
			do break end
		end
	end
	
	if cur == 5 then 
		cur = 0
	end
	PallyPower:SealAssign(cur)
end

function PallyPower:PerformSealCycleBackward()

	if not settings.seal then 
		settings.seal = 0
	end
	
	cur = settings.seal
	
	if cur == 0 then 
		cur = 5 
	end
	
	for test=cur-1, 0, -1 do
		cur = test
		if GetSpellInfo(PallyPower.Seals[cur]) then
			do break end
		end
	end
	PallyPower:SealAssign(cur)
end

-------------------------------------------------------------------
-- Buff UI
-------------------------------------------------------------------
function PallyPower:CreateLayout()

	PallyPowerHeader = _G["PallyPowerFrame"]

    PallyPowerAuto = CreateFrame("Button", "PallyPowerAutoBtn", PallyPowerHeader, "SecureActionButtonTemplate, PallyPowerButtonTemplate")
	PallyPowerAuto:RegisterForClicks("LeftButtonDown")

	PallyPowerRF = CreateFrame("Button", "PallyPowerRFBtn", PallyPowerHeader, "SecureActionButtonTemplate, PallyPowerRFButtonTemplate")
	PallyPowerRF:RegisterForClicks("LeftButtonDown")

	PallyPowerAura = CreateFrame("Button", "PallyPowerAuraBtn", PallyPowerHeader, "SecureActionButtonTemplate, PallyPowerAuraButtonTemplate")
	PallyPowerAura:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	
	PallyPower:UpdateLayout()
end

function PallyPower:UpdateLayout()
	if InCombatLockdown() then return false end
	
	PallyPowerFrame:SetScale(settings.buffscale)
	
	-- custom layout
	local x = settings.display.buttonWidth
	local y = settings.display.buttonHeight
	local point = "TOPLEFT"
	local pointOpposite = "BOTTOMLEFT"
	local layout = PallyPower.Layouts[settings.layout]
	local ox = layout.ab.x * x
	local oy = layout.ab.y * y
	
 	PallyPowerAuto:ClearAllPoints()
	PallyPowerAuto:SetPoint(point, PallyPowerHeader, "CENTER", ox, oy)
	PallyPowerAuto:SetAttribute("type", "spell")
	PallyPowerAuto:SetAttribute("unit1", "player")
	
	PallyPower:BuffAssign(settings.buff)
	
	if self:GetNumUnits() > 0 and not settings.disabled and isPally then
		PallyPowerAuto:Show()
	else
		PallyPowerAuto:Hide()
	end

    ox = layout.rf.x * x
	oy = layout.rf.y * y

	PallyPowerRF:ClearAllPoints()
	PallyPowerRF:SetPoint(point, PallyPowerHeader, "CENTER", ox, oy)

	PallyPowerRF:SetAttribute("type1", "spell")
	PallyPowerRF:SetAttribute("unit1", "player")
	
	PallyPower:RFAssign(settings.rf)

	if self:GetNumUnits() > 0 and settings.rfbuff and not settings.disabled and isPally then
		PallyPowerRF:Show()
	else
		PallyPowerRF:Hide()
	end

    ox = layout.au.x * x
	oy = layout.au.y * y

	PallyPowerAura:ClearAllPoints()
	PallyPowerAura:SetPoint(point, PallyPowerHeader, "CENTER", ox, oy)
		
	PallyPowerAura:SetAttribute("type1", "spell")
	PallyPowerAura:SetAttribute("unit1", "player")
	
	PallyPower:AuraAssign(settings.aura)

	PallyPowerAura:SetAttribute("type2", "spell")
	PallyPowerAura:SetAttribute("unit2", "player")
	
	PallyPower:SealAssign(settings.seal)
		
	if self:GetNumUnits() > 0 and settings.auras and not settings.disabled and isPally then
		PallyPowerAura:Show()
	else
		PallyPowerAura:Hide()
	end
	
	self:ButtonsUpdate()
end


function PallyPower:GetSeverityColor(percent)
	if (percent >= 0.5) then
		return (1.0-percent)*2, 1.0, 0.0
	else
		return 1.0, percent*2, 0.0
	end
end

function PallyPower:ButtonsUpdate()
	-- roster buff check
	local minClassExpire, minClassDuration, sumnhave, sumnneed = PallyPower:GetBuffExpiration()
	--self:Print("Buff Expirations", minClassExpire, minClassDuration, sumnhave, sumnneed)
	local btime = _G["PallyPowerAutoBtnTime"]
	local btext = _G["PallyPowerAutoBtnText"]
	
	if (sumnhave == 0) then
  		PallyPower:ApplyBackdrop(PallyPowerAuto, settings.cBuffNeedAll)
	elseif (sumnneed > 0) then
  		self:ApplyBackdrop(PallyPowerAuto, settings.cBuffNeedSome)
	else
  		self:ApplyBackdrop(PallyPowerAuto, settings.cBuffGood)
	end
	
	btime:SetText(PallyPower:FormatTime(minClassExpire))
	btime:SetTextColor(PallyPower:GetSeverityColor(minClassExpire and minClassDuration and (minClassExpire/minClassDuration) or 0))
	
	if (sumnneed > 0) then
		btext:SetText(sumnneed)
	else
		btext:SetText("")
	end
	
	-- rf button check
	local expire = PallyPower:GetRFExpiration()
	
	if expire == 9999 and settings.rf then
		self:ApplyBackdrop(PallyPowerRF, settings.cBuffNeedAll)
	else
		self:ApplyBackdrop(PallyPowerRF, settings.cBuffGood)
	end

	-- seal check
	local stime = _G["PallyPowerAuraBtnTimeSeal"] -- seal timer
	local expire1, duration1 = PallyPower:GetSealExpiration()
	local expire2            = PallyPower:GetAuraExpiration()
	
	--self:Print(settings.aura, settings.seal)	
	--self:Print("Seal expirations", expire1, duration1, "Aura Expiration", expire2)
		
	stime:SetText(PallyPower:FormatTime(expire1))
	stime:SetTextColor(PallyPower:GetSeverityColor(expire1 and (expire1/duration1) or 0))
		
	if (expire1 == 9999 and settings.seal > 0) and (expire2 == 9999 and settings.aura > 0) then
		self:ApplyBackdrop(PallyPowerAura, settings.cBuffNeedAll)
  	elseif (expire1 == 9999 and settings.seal > 0) or (expire2 == 9999 and settings.aura > 0) then
  	    self:ApplyBackdrop(PallyPowerAura, settings.cBuffNeedSome)
	else                                               
		self:ApplyBackdrop(PallyPowerAura, settings.cBuffGood)
	end

end

function PallyPower:ApplySkin()
	--PallyPower.Edge = 'Interface\\Tooltips\\UI-Tooltip-Border'
	--bgfile = PallyPower.Skins[skinname]
	
	
	local border     = LSM3:Fetch("border", settings.border)
	local background = LSM3:Fetch("background", settings.skin)
	
	--if settings.display.edges then 
	--	edge = PallyPower.Edge
	--else
	--	edge = nil
	--end

    PallyPowerAuto:SetBackdrop({bgFile = background, edgeFile= border,
						  tile=false, tileSize = 8, edgeSize = 8,
						  insets = { left = 0, right = 0, top = 0, bottom = 0}});
    PallyPowerRF:SetBackdrop({bgFile = background, edgeFile= border,
						  tile=false, tileSize = 8, edgeSize = 8,
						  insets = { left = 0, right = 0, top = 0, bottom = 0}});
	PallyPowerAura:SetBackdrop({bgFile = background, edgeFile= border,
						  tile=false, tileSize = 8, edgeSize = 8,
						  insets = { left = 0, right = 0, top = 0, bottom = 0}});
end

-- button coloring: preset
function PallyPower:ApplyBackdrop(button, preset)
	button:SetBackdropColor(preset["r"], preset["g"], preset["b"], preset["t"])
end
