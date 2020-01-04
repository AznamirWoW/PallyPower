PallyPower = LibStub("AceAddon-3.0"):NewAddon("PallyPower", "AceConsole-3.0", "AceEvent-3.0", "AceBucket-3.0", "AceTimer-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("PallyPower")
local LibClassicDurations = LibStub("LibClassicDurations")
local LSM3 = LibStub("LibSharedMedia-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local tinsert = table.insert
local tremove = table.remove
local twipe = table.wipe
local tsort = table.sort
local sfind = string.find
local ssub = string.sub
local sformat = string.format

local WisdomPallys, MightPallys, KingsPallys, SalvPallys, LightPallys, SancPallys = {}, {}, {}, {}, {}, {}
local classlist, classes = {}, {}
LastCast = {}
PallyPower_Assignments = {}
PallyPower_NormalAssignments = {}
PallyPower_AuraAssignments = {}
PallyPower_SavedPresets = {}

AllPallys = {}
SyncList = {}
ChatControl = {}

local initalized = false
PP_DebugEnabled = false
PP_Symbols = 0
PP_IsPally = false

-- unit tables
local party_units = {}
local raid_units = {}
local leaders = {}
local roster = {}
local raidtanks = {}

do
	table.insert(party_units, "player")
	table.insert(party_units, "pet")

	for i = 1, MAX_PARTY_MEMBERS do
		table.insert(party_units, ("party%d"):format(i))
		table.insert(party_units, ("partypet%d"):format(i))
	end

	for i = 1, MAX_RAID_MEMBERS do
		table.insert(raid_units, ("raid%d"):format(i))
		table.insert(raid_units, ("raidpet%d"):format(i))
	end
end

function PallyPower:Debug(string)
	if not string then string = "(nil)" end
	if (PP_DebugEnabled) then
		DEFAULT_CHAT_FRAME:AddMessage("[PP] "..string,1,0,0);
	end
end

function PallyPower:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PallyPowerDB", PALLYPOWER_DEFAULT_VALUES, "Default")
	self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
	self.opt = self.db.profile
	PallyPower.options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("PallyPower", PallyPower.options, {"pp", "pallypower"})
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("PallyPower", "PallyPower")
	LSM3:Register("background", "None", "Interface\\Tooltips\\UI-Tooltip-Background")
	LSM3:Register("background", "Banto", "Interface\\AddOns\\PallyPower\\Skins\\Banto")
	LSM3:Register("background", "BantoBarReverse", "Interface\\AddOns\\PallyPower\\Skins\\BantoBarReverse")
	LSM3:Register("background", "Glaze", "Interface\\AddOns\\PallyPower\\Skins\\Glaze")
	LSM3:Register("background", "Gloss", "Interface\\AddOns\\PallyPower\\Skins\\Gloss")
	LSM3:Register("background", "Healbot", "Interface\\AddOns\\PallyPower\\Skins\\Healbot")
	LSM3:Register("background", "oCB", "Interface\\AddOns\\PallyPower\\Skins\\oCB")
	LSM3:Register("background", "Smooth", "Interface\\AddOns\\PallyPower\\Skins\\Smooth")
	self.player = UnitName("player")
	self:ScanInventory()
	self:CreateLayout()
	if self.opt.skin then
		PallyPower:ApplySkin(self.opt.skin)
 	end
	LibClassicDurations:Register("PallyPower")
	self.AutoBuffedList = {}
	self.PreviousAutoBuffedUnit = nil
	if not PallyPowerConfigFrame then
		local pallypowerconfigframe = AceGUI:Create("Frame")
		LibStub("AceConfigDialog-3.0"):SetDefaultSize("PallyPower", 625, 580)
    LibStub("AceConfigDialog-3.0"):Open("PallyPower", pallypowerconfigframe)
		pallypowerconfigframe:Hide()
		_G["PallyPowerConfigFrame"] = pallypowerconfigframe.frame
		table.insert(UISpecialFrames, "PallyPowerConfigFrame")
	end
end

function PallyPower:OnProfileChanged()
  self.opt = self.db.profile
	PallyPower:UpdateLayout()
end

function PallyPower:OnEnable()
	self.opt.enable = true
	self:ScanSpells()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("UPDATE_BINDINGS", "BindKeys")
	self:RegisterEvent("UNIT_AURA")
	self:RegisterBucketEvent("SPELLS_CHANGED", 1, "SPELLS_CHANGED")
	self:RegisterBucketEvent({"GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "UNIT_PET"}, 1, "UpdateRoster")
	if PP_IsPally then
		self:ScheduleRepeatingTimer(self.InventoryScan, 60, self)
		self:ScheduleRepeatingTimer(self.ButtonsUpdate, 1, self)
	end
	self:UpdateRoster()
	self:BindKeys()
end

function PallyPower:BindKeys()
	local key1 = GetBindingKey("AUTOKEY1")
	local key2 = GetBindingKey("AUTOKEY2")
	if key1 then
		SetOverrideBindingClick(self.autoButton, false, key1, "PallyPowerAuto", "Hotkey1")
  	end
	if key2 then
		SetOverrideBindingClick(self.autoButton, false, key2, "PallyPowerAuto", "Hotkey2")
  	end
end

function PallyPower:OnDisable()
	self.opt.enable = false
	for i = 1, PALLYPOWER_MAXCLASSES do
		classlist[i] = 0
		classes[i] = {}
	end
	self:UpdateLayout()
	self.auraButton:Hide()
	self.rfButton:Hide()
	self.autoButton:Hide()
	PallyPowerAnchor:Hide()
	self:UnbindKeys()
end

function PallyPower:UnbindKeys()
	ClearOverrideBindings(self.autoButton)
end

function PallyPower:Purge()
	PallyPower_Assignments = nil
	PallyPower_NormalAssignments = nil
	PallyPower_AuraAssignments = nil
	PallyPower_Assignments = {}
	PallyPower_NormalAssignments = {}
	PallyPower_AuraAssignments = {}
end

function PallyPowerBlessings_Clear()
	if InCombatLockdown() then return end
	PallyPower:ClearAssignments(UnitName("player"))
	PallyPower:SendMessage("CLEAR")
	PallyPower:UpdateRoster()
end

function PallyPower:Reset()
	if InCombatLockdown() then return end
	local h = _G["PallyPowerFrame"]
	h:ClearAllPoints()
	h:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	PallyPower.opt.buffscale = 0.9
	PallyPower.opt.border = "Blizzard Tooltip"
	PallyPower.opt.layout = "Layout 2"
	PallyPower.opt.skin = "Smooth"
	local c = _G["PallyPowerBlessingsFrame"]
	c:ClearAllPoints()
  c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	PallyPower.opt.configscale = 0.9
	self:ApplySkin()
	self:UpdateLayout()
end

function PallyPowerBlessings_Refresh()
	AllPallys = {}
	SyncList = {}
	PallyPower:ScanSpells()
	PallyPower:ScanInventory()
	PallyPower:SendSelf()
	PallyPower:SendMessage("REQ")
	PallyPower:UpdateLayout()
	PallyPower:UpdateRoster()
end

function PallyPowerBlessings_Toggle(msg)
	if PallyPower.configFrame and PallyPower.configFrame:IsShown() then
		PallyPower.configFrame:Hide()
	end
	if PallyPowerBlessingsFrame:IsVisible() then
		PallyPowerBlessingsFrame:Hide()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
	else
		local c = _G["PallyPowerBlessingsFrame"]
		c:ClearAllPoints()
    	c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
		PallyPowerBlessingsFrame:Show()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
		table.insert(UISpecialFrames, "PallyPowerBlessingsFrame")
	end
end

function PallyPowerBlessings_ShowCredits(self)
	if PallyPower.opt.ShowTooltips then
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(PallyPower_Credits1, 1, 1, 1)
		GameTooltip:AddLine(PallyPower_Credits2, 1, 1, 1)
		GameTooltip:Show()
	end
end

function PallyPower:OpenConfigWindow()
	if PallyPowerBlessingsFrame:IsVisible() then
		PallyPowerBlessingsFrame:Hide()
	end
  if not PallyPowerConfigFrame:IsShown() then
		PallyPowerConfigFrame:Show()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
  else
		PallyPowerConfigFrame:Hide()
		PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
  end
end

function GetNormalBlessings(pname, class, tname)
	if PallyPower_NormalAssignments[pname] and PallyPower_NormalAssignments[pname][class] then
		local blessing = PallyPower_NormalAssignments[pname][class][tname]
		if blessing then
			return tostring(blessing)
		else
			return "0"
		end
	end
end

function SetNormalBlessings(pname, class, tname, value)
	if not PallyPower_NormalAssignments[pname] then
		PallyPower_NormalAssignments[pname] = {}
	end
	if not PallyPower_NormalAssignments[pname][class] then
		PallyPower_NormalAssignments[pname][class] = {}
	end
	PallyPower:SendMessage("NASSIGN "..pname.." "..class.." "..tname.." "..value)
	if value == 0 then value = nil end
	PallyPower_NormalAssignments[pname][class][tname] = value
end

function PallyPowerGrid_NormalBlessingMenu(btn, mouseBtn, pname, class)
	if InCombatLockdown() then return false end
	if (mouseBtn == "LeftButton") then
		local pre, suf
		for pally in pairs(AllPallys) do
			local control
			control = PallyPower:CanControl(pally)
			if not control then
				pre = "|cff999999"
				suf = "|r"
			else
				pre = ""
				suf = ""
			end
			local blessings = {["0"] = sformat("%s%s%s", pre, "(none)", suf)}
			for index, blessing in ipairs(PallyPower.Spells) do
				if PallyPower:CanBuff(pally, index) then
						blessings[tostring(index)] = sformat("%s%s%s", pre, blessing, suf)
				end
			end
		end
	elseif (mouseBtn == "RightButton") then
		for pally in pairs(AllPallys) do
			if PallyPower_NormalAssignments[pally] and PallyPower_NormalAssignments[pally][class] and PallyPower_NormalAssignments[pally][class][pname] then
				PallyPower_NormalAssignments[pally][class][pname] = nil
				PallyPower:SendMessage("NASSIGN "..pally.." "..class.." "..pname.." 0")
			end
		end
	end
end

function PallyPowerPlayerButton_OnClick(btn, mouseBtn)
	if InCombatLockdown() then return false end
	local _, _, class, pnum = sfind(btn:GetName(), "PallyPowerBlessingsFrameClassGroup(.+)PlayerButton(.+)")
	local pname = getglobal("PallyPowerBlessingsFrameClassGroup"..class.."PlayerButton"..pnum.."Text"):GetText()
	class = tonumber(class)
	PallyPowerGrid_NormalBlessingMenu(btn, mouseBtn, pname, class)
end

function PallyPowerPlayerButton_OnMouseWheel(btn, arg1)
	if InCombatLockdown() then return false end
	local _, _, class, pnum = sfind(btn:GetName(), "PallyPowerBlessingsFrameClassGroup(.+)PlayerButton(.+)")
	local pname = getglobal("PallyPowerBlessingsFrameClassGroup"..class.."PlayerButton"..pnum.."Text"):GetText()
	class = tonumber(class)
	PallyPower:PerformPlayerCycle(self, arg1, pname, class)
end

function PallyPowerGridButton_OnClick(btn, mouseBtn)
	if InCombatLockdown() then return false end
	local _, _, pnum, class = sfind(btn:GetName(), "PallyPowerBlessingsFramePlayer(.+)Class(.+)")
	pnum = pnum + 0
	class = class + 0
	local pname = getglobal("PallyPowerBlessingsFramePlayer"..pnum.."Name"):GetText()
	if not PallyPower:CanControl(pname) then return false end
	if (mouseBtn == "RightButton") then
		PallyPower_Assignments[pname][class] = 0
		PallyPower:SendMessage("ASSIGN "..pname.." "..class.. " 0")
	else
		PallyPower:PerformCycle(pname, class)
	end
end

function PallyPowerGridButton_OnMouseWheel(btn, arg1)
	if InCombatLockdown() then return false end
	local _, _, pnum, class = sfind(btn:GetName(), "PallyPowerBlessingsFramePlayer(.+)Class(.+)")
	pnum = pnum + 0
	class = class + 0
	local pname = getglobal("PallyPowerBlessingsFramePlayer"..pnum.."Name"):GetText()
	if not PallyPower:CanControl(pname) then return false end
	if (arg1==-1) then  --mouse wheel down
		PallyPower:PerformCycle(pname, class)
	else
		PallyPower:PerformCycleBackwards(pname, class)
	end
end

function PallyPowerBlessingsFrame_MouseUp(self, button)
	if ( PallyPowerBlessingsFrame.isMoving ) then
		PallyPowerBlessingsFrame:StopMovingOrSizing()
		PallyPowerBlessingsFrame.isMoving = false
	end
end

function PallyPowerBlessingsFrame_MouseDown(self, button)
	if ( ( ( not PallyPowerBlessingsFrame.isLocked ) or ( PallyPowerBlessingsFrame.isLocked == 0 ) ) and ( button == "LeftButton" ) ) then
		PallyPowerBlessingsFrame:StartMoving()
		PallyPowerBlessingsFrame.isMoving = true
	end
end

function PallyPowerBlessingsGrid_Update(self, elapsed)
	if not initalized then PallyPower:ScanSpells() end
	if PallyPowerBlessingsFrame:IsVisible() then
		local i = 1
		local numPallys = 0
		local numMaxClass = 0
		local name, skills
		for i = 1, PALLYPOWER_MAXCLASSES do
			local fname = "PallyPowerBlessingsFrameClassGroup"..i
			if movingPlayerFrame and MouseIsOver(getglobal(fname.."ClassButton")) then
				getglobal(fname.."ClassButtonHighlight"):Show()
			else
				getglobal(fname.."ClassButtonHighlight"):Hide()
			end
			getglobal(fname.."ClassButtonIcon"):SetTexture(PallyPower.ClassIcons[i])
			for j = 1, PALLYPOWER_MAXPERCLASS do
				local pbnt = fname.."PlayerButton"..j
				if classes[i] and classes[i][j] then
					local unit = classes[i][j]
					local shortname = Ambiguate(unit.name, "short")
					getglobal(pbnt.."Text"):SetText(shortname)
					local normal, greater = PallyPower:GetSpellID(i, unit.name)
					local icon
					if normal ~= greater and movingPlayerFrame ~= getglobal(pbnt) then
						if normal ~= greater then
							getglobal(pbnt.."Icon"):SetTexture(PallyPower.NormalBlessingIcons[normal])
						else
							getglobal(pbnt.."Icon"):SetTexture("")
						end
					else
						getglobal(pbnt.."Icon"):SetTexture("")
					end
					getglobal(pbnt):Show()
				else
					getglobal(pbnt):Hide()
				end
			end
			if classlist[i] then
				numMaxClass = math.max(numMaxClass, classlist[i])
			end
		end
		PallyPowerBlessingsFrame:SetScale(PallyPower.opt.configscale)
		for i, name in pairs(SyncList) do
			local fname = "PallyPowerBlessingsFramePlayer" .. i
			local SkillInfo = AllPallys[name]
			local BuffInfo = PallyPower_Assignments[name]
			local NormalBuffInfo = PallyPower_NormalAssignments[name]
			local shortname = Ambiguate(name, "short")
			getglobal(fname .. "Name"):SetText(shortname)
			if PallyPower:CanControl(name) then
				getglobal(fname.."Name"):SetTextColor(1,1,1)
			else
				if PallyPower:CheckLeader(name) then
					getglobal(fname.."Name"):SetTextColor(0,1,0)
				else
					getglobal(fname.."Name"):SetTextColor(1,0,0)
				end
			end
			getglobal(fname .. "Symbols"):SetText(SkillInfo.symbols)
			getglobal(fname .. "Symbols"):SetTextColor(1,1,0.5)
			for id = 1, 6 do
				if SkillInfo[id] then
					getglobal(fname.."Icon"..id):Show()
					getglobal(fname.."Skill"..id):Show()
					local txt = SkillInfo[id].rank
					if SkillInfo[id].talent and (SkillInfo[id].talent + 0 > 0) then
						txt = txt.. "+" .. SkillInfo[id].talent
					end
					getglobal(fname.."Skill"..id):SetText(txt)
				else
					getglobal(fname.."Icon"..id):Hide()
					getglobal(fname.."Skill"..id):Hide()
				end
			end
			if not AllPallys[name].AuraInfo then
				AllPallys[name].AuraInfo = {}
			end
			local AuraInfo = AllPallys[name].AuraInfo
			for id = 1, 3 do
				if AuraInfo[id] then
					getglobal(fname.."AIcon"..id):Show()
					getglobal(fname.."ASkill"..id):Show()
					local txt = AuraInfo[id].rank
					if AuraInfo[id].talent and (AuraInfo[id].talent + 0 > 0) then
						txt = txt.. "+" .. AuraInfo[id].talent
					end
					getglobal(fname.."ASkill"..id):SetText(txt)
				else
					getglobal(fname.."AIcon"..id):Hide()
					getglobal(fname.."ASkill"..id):Hide()
				end
			end
			local aura = PallyPower_AuraAssignments[name]
			if ( aura and aura > 0 ) then
				getglobal(fname.."Aura1Icon"):SetTexture(PallyPower.AuraIcons[aura])
			else
				getglobal(fname.."Aura1Icon"):SetTexture(nil)
			end
			for id = 1, PALLYPOWER_MAXCLASSES do
				if BuffInfo and BuffInfo[id] then
					getglobal(fname.."Class"..id.."Icon"):SetTexture(PallyPower.BlessingIcons[BuffInfo[id]])
				else
					getglobal(fname.."Class"..id.."Icon"):SetTexture(nil)
				end
				local found
			end
			i = i + 1
			numPallys = numPallys + 1
		end
		PallyPowerBlessingsFrame:SetHeight(14 + 24 + 56 + (numPallys * 80) + 22 + 13 * numMaxClass)
		getglobal("PallyPowerBlessingsFramePlayer1"):SetPoint("TOPLEFT", 8, -80 - 13 * numMaxClass)
		for i = 1, PALLYPOWER_MAXCLASSES do
			getglobal("PallyPowerBlessingsFrameClassGroup" .. i .. "Line"):SetHeight(56 + 13 * numMaxClass)
		end
		getglobal("PallyPowerBlessingsFrameAuraGroup1Line"):SetHeight(56 + 13 * numMaxClass)
		for i = 1, PALLYPOWER_MAXPERCLASS do
			local fname = "PallyPowerBlessingsFramePlayer" .. i
			if i <= numPallys then
				getglobal(fname):Show()
			else
				getglobal(fname):Hide()
			end
		end
		PallyPowerBlessingsFrameFreeAssign:SetChecked(PallyPower.opt.freeassign)
	end
end

function PallyPower_StartScaling(self, button)
	if button=="RightButton" then
		PallyPower.opt.configscale = 0.9
		local c = _G["PallyPowerBlessingsFrame"]
		c:ClearAllPoints()
   		c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
		PallyPowerBlessingsFrame:Show()
	end
	if button=="LeftButton" then
		self:LockHighlight()
		PallyPower.FrameToScale = self:GetParent()
    PallyPower.ScalingWidth = self:GetParent():GetWidth() * PallyPower.FrameToScale:GetParent():GetEffectiveScale()
    PallyPower.ScalingHeight = self:GetParent():GetHeight() * PallyPower.FrameToScale:GetParent():GetEffectiveScale()
    PallyPowerScalingFrame:Show()
	end
end

function PallyPower_StopScaling(self, button)
	if button=="LeftButton" then
		PallyPowerScalingFrame:Hide()
    PallyPower.FrameToScale = nil
    self:UnlockHighlight()
	end
end

function PallyPower_ScaleFrame(scale)
	local frame = PallyPower.FrameToScale
	local oldscale = frame:GetScale() or 1
	local framex = (frame:GetLeft() or PallyPowerPerOptions.XPos)* oldscale
	local framey = (frame:GetTop() or PallyPowerPerOptions.YPos)* oldscale
	frame:SetScale(scale)
	if frame:GetName() == "PallyPowerBlessingsFrame" then
		frame:SetClampedToScreen(true)
		frame:SetPoint("TOPLEFT","UIParent","BOTTOMLEFT",framex/scale,framey/scale)
		PallyPower.opt.configscale = scale
	end
end

function PallyPower_ScalingFrame_Update(self, elapsed)
	if not PallyPower.ScalingTime then
		PallyPower.ScalingTime = 0
	end
	PallyPower.ScalingTime = PallyPower.ScalingTime + elapsed
	if PallyPower.ScalingTime > 0.25 then
		PallyPower.ScalingTime = 0
		local frame = PallyPower.FrameToScale
		local oldscale = frame:GetEffectiveScale()
		local framex, framey, cursorx, cursory = frame:GetLeft() * oldscale, frame:GetTop() * oldscale, GetCursorPosition()
		if PallyPower.ScalingWidth>PallyPower.ScalingHeight then
			if (cursorx-framex)>32 then
				local newscale =  (cursorx-framex)/PallyPower.ScalingWidth
				if newscale < 0.5 then
					PallyPower_ScaleFrame(0.5)
				else
					PallyPower_ScaleFrame(newscale)
				end
			end
		else
			if (framey-cursory)>32 then
				local newscale =  (framey-cursory)/PallyPower.ScalingHeight
				if newscale < 0.5 then
					PallyPower_ScaleFrame(0.5)
				else
					PallyPower_ScaleFrame(newscale)
				end
			end
		end
	end
end

function PallyPower:Report(type)
	if GetNumGroupMembers() > 0 then
		if not type then
			if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
				type = "INSTANCE_CHAT"
			else
				if IsInRaid() then
					type = "RAID"
				elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
					type = "PARTY"
				end
			end
			if PallyPower:CheckLeader(self.player) and type ~= "INSTANCE_CHAT" then
				SendChatMessage(PALLYPOWER_ASSIGNMENTS1, type)
				local list = {}
				for name in pairs(AllPallys) do
					local blessings
					for i = 1, 6 do
						list[i] = 0
					end
					for id = 1, PALLYPOWER_MAXCLASSES do
						local bid = PallyPower_Assignments[name][id]
						if bid and bid > 0 then
							list[bid] = list[bid] + 1
						end
					end
					for id = 1, 6 do
						if (list[id] > 0) then
							if (blessings) then
								blessings = blessings .. ", "
							else
								blessings = ""
							end
							local spell = PallyPower.Spells[id]
							blessings = blessings .. spell
						end
					end
					if not (blessings) then
						blessings = "Nothing"
					end
					SendChatMessage(name ..": ".. blessings, type)
				end
				SendChatMessage(PALLYPOWER_ASSIGNMENTS2, type)
				if IsInRaid() and #SyncList > 4 and type == "RAID" then
					SendChatMessage(" ", type)
					SendChatMessage(PALLYPOWER_ASSIGNMENTS3, "RAID_WARNING")
					SendChatMessage(PALLYPOWER_ASSIGNMENTS4, "RAID_WARNING")
				end
			else
				if type == "INSTANCE_CHAT" then
					self:Print("Blessings Report is disabled in Battlegrounds.")
				elseif type == "RAID" then
					self:Print("You are not the raid leader or do not have raid assist.")
				else
					self:Print(ERR_NOT_LEADER)
				end
			end
		end
	else
		if type == "RAID" then
			self:Print(ERR_NOT_IN_RAID)
		else
			self:Print(ERR_NOT_IN_GROUP)
		end
	end
end

function PallyPower:PerformCycle(name, class, skipzero)
	local shift = (IsShiftKeyDown() and PallyPowerBlessingsFrame:IsMouseOver())
	local cur
	if shift then class = 5 end
	if not PallyPower_Assignments[name] then
		PallyPower_Assignments[name] = { }
	end
	if not PallyPower_Assignments[name][class] then
		cur = 0
	else
		cur = PallyPower_Assignments[name][class]
	end
	PallyPower_Assignments[name][class] = 0
	local testB
	for testB = cur + 1, 7 do
		if PallyPower:CanBuff(name, testB) and (PallyPower:NeedsBuff(class, testB) or shift) then
			cur = testB
			do break end
		end
	end
	if cur == 7 then
		if skipzero then
			if PallyPower:CanBuff(name, 1) then
				if self.opt.SmartBuffs and (class == 1 or class == 2) then
					cur = 2
				else
					cur = 1
				end
			elseif PallyPower:CanBuff(name, 2) then
				if self.opt.SmartBuffs and (class == 3 or class == 6 or class == 7 or class == 8) then
					cur = 1
				else
					cur = 2
				end
			end
		else
			cur = 0
		end
	end
	if shift then
		local testC
		for testC = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[name][testC] = cur
		end
		PallyPower:SendMessage("MASSIGN "..name.." "..cur)
	else
		PallyPower_Assignments[name][class] = cur
		PallyPower:SendMessage("ASSIGN "..name.." "..class.." "..cur)
	end
	PallyPower:UpdateRoster()
end

function PallyPower:PerformCycleBackwards(name, class, skipzero)
	local shift = (IsShiftKeyDown() and PallyPowerBlessingsFrame:IsMouseOver())
	local cur
	if shift then class = 5 end
	if not PallyPower_Assignments[name] then
		PallyPower_Assignments[name] = { }
	end
	if not PallyPower_Assignments[name][class] then
		cur = 7
	else
		cur = PallyPower_Assignments[name][class]
		local testB
		if PallyPower:CanBuff(name, 1) then
			if self.opt.SmartBuffs and (class == 1 or class == 2) then
				testB = 2
			else
				testB = 1
			end
		elseif PallyPower:CanBuff(name, 2) then
			if self.opt.SmartBuffs and (class == 3 or class == 6 or class == 7 or class == 8) then
				testB = 1
			else
				testB = 2
			end
		else
			testB = 0
		end
		if cur == 0 or skipzero and cur == testB then cur = 7 end
	end
	PallyPower_Assignments[name][class] = 0
	local testC
	for testC = cur - 1, 0, -1 do
		cur = testC
		if PallyPower:CanBuff(name, testC) and (PallyPower:NeedsBuff(class, testC) or shift) then
			do break end
		end
	end
	if shift then
		for testC = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[name][testC] = cur
		end
		PallyPower:SendMessage("MASSIGN "..name.." "..cur)
	else
		PallyPower_Assignments[name][class] = cur
		PallyPower:SendMessage("ASSIGN "..name.." "..class.." "..cur)
	end
	PallyPower:UpdateRoster()
end

function PallyPower:PerformPlayerCycle(self, delta, pname, class)
	local blessing = 0
	local playername = PallyPower.player
	if PallyPower_NormalAssignments[playername] and PallyPower_NormalAssignments[playername][class] and PallyPower_NormalAssignments[playername][class][pname] then
		blessing = PallyPower_NormalAssignments[playername][class][pname]
	end
	local test = (blessing - delta) % 7
	while not (PallyPower:CanBuff(playername, test) and PallyPower:NeedsBuff(class, test, pname)) and test > 0 do
		test = (test - delta) % 7
		if test == blessing then
			test = 0
			break
		end
	end
	SetNormalBlessings(playername, class, pname, test)
	PallyPower:UpdateRoster()
end

function PallyPower:AssignPlayerAsClass(pname, pclass, tclass)
	local greater, target, targetsorted, freepallies =  {}, {}, {}, {}
	for pally, classes in pairs(PallyPower_Assignments) do
		if AllPallys[pally] and classes[tclass] and classes[tclass] > 0 then
			target[classes[tclass]] = pally
			tinsert(targetsorted, classes[tclass])
		end
	end
	tsort(targetsorted, function(a,b) return a == 2 or a == 1 and b ~= 2 end)
	for pally, info in pairs(AllPallys) do
		if PallyPower_Assignments[pally] and PallyPower_Assignments[pally][pclass] then
			local blessing = PallyPower_Assignments[pally][pclass]
			greater[blessing] = pally
			if not target[blessing] then
				freepallies[pally] = info
			end
		else
			freepallies[pally] = info
		end
	end
	for index, blessing in pairs(targetsorted) do
		if greater[blessing] then
			local pally = greater[blessing]
			if PallyPower_NormalAssignments[pally] and
			   PallyPower_NormalAssignments[pally][pclass] and
			   PallyPower_NormalAssignments[pally][pclass][pname] then
				SetNormalBlessings(pally, pclass, pname, 0)
			end
		else
			local maxname, maxrank, maxtalent = nil, 0, 0
			local targetpally = target[blessing]
			for pally, blessinginfo in pairs(freepallies) do
				local blessinginfo = blessinginfo[blessing]
				local rank, talent = 0, 0
				if blessinginfo then
					rank, talent = blessinginfo.rank, blessinginfo.talent
				end
				if rank > maxrank or (rank == maxrank and talent > maxtalent) or pally == targetpally then
					maxname = pally
					maxrank = rank
					maxtalent = talent
				end
			end
			if maxname then
				freepallies[maxname] = nil
				SetNormalBlessings(maxname, pclass, pname, blessing)
			end
		end
	end
end

function PallyPower:CanBuff(name, test)
	if test==7 then
		return true
	end
	if (not AllPallys[name][test]) or (AllPallys[name][test].rank == 0) then
		return false
	end
	return true
end

function PallyPower:NeedsBuff(class, test, playerName)
	if test==7 or test==0 then
		return true
	end
	if self.opt.SmartBuffs then
		-- no wisdom for warriors and rogues
		if (class == 1 or class == 2) and test == 1 then
			return false
		end
		-- no might for casters and hunters
		if (class == 3 or class == 6 or class == 7 or class == 8) and test == 2 then
			return false
		end
	end
	if playerName then
		for pname, classes in pairs(PallyPower_NormalAssignments) do
			if AllPallys[pname] and not pname == self.player then
				for class_id, tnames in pairs(classes) do
					for tname, blessing_id in pairs(tnames) do
						if blessing_id == test then
							return false
						end
					end
				end
			end
		end
	end
	for name, skills in pairs(PallyPower_Assignments) do
		if (AllPallys[name]) and ((skills[class]) and (skills[class]==test)) then
			return false
		end
	end
	return true
end

function PallyPower:ScanSpells()
	self:Debug("ScanSpells()")
	local _, class=UnitClass("player")
	if (class == "PALADIN") then
		local RankInfo = {}
		for i = 1, 6 do -- find max spell ranks
			spellName = GetSpellInfo(PallyPower.Spells[i])
			spellRank = GetSpellSubtext(GetSpellInfo(PallyPower.Spells[i]))
			if spellName then
				RankInfo[i] = {}
				if not spellRank or spellRank == "" then -- spells without ranks
					spellRank = "1"		 -- BoK and BoS
				end
				local talent = 0
				if i == 1 then
					talent = talent + select(5, GetTalentInfo(1, 10)) -- Improved Blessing of Wisdom
				elseif i == 2 then
			    talent = talent + select(5, GetTalentInfo(3, 1)) -- Improved Blessing of Might
			  elseif i == 3 then
					talent = talent + select(5, GetTalentInfo(2, 6)) -- Blessing of Kings
				elseif i == 6 then
					talent = talent + select(5, GetTalentInfo(2, 12)) -- Blessing of Sanctuary
				end
				RankInfo[i].talent = talent
				RankInfo[i].rank = tonumber(select(3, sfind(spellRank, "(%d+)")))
			end
		end
		self:SyncAdd(self.player)
		AllPallys[self.player] = RankInfo
		AllPallys[self.player].AuraInfo = {}
		for i = 1, PALLYPOWER_MAXAURAS do -- find max ranks/talents for auaras
			local spellName = GetSpellInfo(PallyPower.Auras[i])
			local spellRank = GetSpellSubtext(GetSpellInfo(PallyPower.Auras[i]))
			if spellName then
				AllPallys[self.player].AuraInfo[i] = {}
				if not spellRank or spellRank == "" then -- spells without ranks
					spellRank = "1"		 -- Concentration
				end
				local talent = 0
				if i == 1 then
					talent = talent + select(5, GetTalentInfo(2, 1)) -- Improved Devotion Aura
				elseif i == 2 then
			    	talent = talent + select(5, GetTalentInfo(3, 11))  -- Improved Retribution Aura
		    elseif i == 3 then
			    	talent = talent + select(5, GetTalentInfo(2, 11))  -- Improved Concentration Aura
				elseif i == 7 then
					talent = talent + select(5, GetTalentInfo(3, 13)) -- Sanctity Aura
				end
				AllPallys[self.player].AuraInfo[i].talent = talent
				AllPallys[self.player].AuraInfo[i].rank = tonumber(select(3, sfind(spellRank, "(%d+)")))
			end
		end
		PP_IsPally = true
		if not AllPallys[self.player].subgroup then
			AllPallys[self.player].subgroup = 1
		end
	else
		PP_IsPally = false
	end
	initalized=true
end

function PallyPower:ScanInventory()
	self:Debug("ScanInventory()")
	if not PP_IsPally then return end
	PP_Symbols = GetItemCount(21177)
	AllPallys[self.player].symbols = PP_Symbols
end

function PallyPower:InventoryScan()
	if GetNumGroupMembers() > 0 and PP_IsPally then
		self:ScanInventory()
		self:SendMessage("SYMCOUNT " .. PP_Symbols)
	end
end

function PallyPower:SendSelf()
	--self:Debug("SendSelf()")
	if not initalized then PallyPower:ScanSpells() end
	if not AllPallys[self.player] then return end
	local s
	local SkillInfo = AllPallys[self.player]
	s = ""
	for i = 1, 6 do
		if not SkillInfo[i] then
			s = s.."nn"
		else
			s = s .. SkillInfo[i].rank .. SkillInfo[i].talent
		end
	end
	s = s .. "@"
	if not PallyPower_Assignments[self.player] then
		PallyPower_Assignments[self.player] = {}
		for i = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[self.player][i] = 0
		end
	end
	local BuffInfo = PallyPower_Assignments[self.player]
	for i = 1, PALLYPOWER_MAXCLASSES do
		if not BuffInfo[i] or BuffInfo[i] == 0 then
			s = s .. "n"
		else
			s = s .. BuffInfo[i]
		end
	end
	self:SendMessage("SELF " .. s)
	s = ""
	local AuraInfo = AllPallys[self.player].AuraInfo
	for i = 1, PALLYPOWER_MAXAURAS do
		if not AuraInfo[i] then
			s = s.."nn"
		else
			s = s .. sformat("%x%x", AuraInfo[i].rank, AuraInfo[i].talent)
		end
	end
	if not PallyPower_AuraAssignments[self.player] then
		PallyPower_AuraAssignments[self.player] = 0
	end
	s = s .. "@" .. PallyPower_AuraAssignments[self.player]
	self:SendMessage("ASELF " .. s)
	local AssignList = {}
	local inraid = IsInRaid()
	if PallyPower_NormalAssignments[self.player] then
		for class_id, tnames in pairs(PallyPower_NormalAssignments[self.player]) do
			for tname, blessing_id in pairs(tnames) do
				tinsert(AssignList, sformat("%s %s %s %s", self.player, class_id, tname, blessing_id))
			end
		end
	end
	local count = table.getn(AssignList)
	if count > 0 then
		local offset = 1
		repeat
			self:SendMessage("NASSIGN " .. table.concat(AssignList, "@", offset, min(offset + 4, count)))
			offset = offset + 5
		until offset > count
	end
	self:SendMessage("SYMCOUNT " .. PP_Symbols)
	if self.opt.freeassign then
		self:SendMessage("FREEASSIGN YES")
	else
		self:SendMessage("FREEASSIGN NO")
	end
end

function PallyPower:SendMessage(msg)
	--self:Debug("SendMessage("..msg..")")
	local type
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
		type = "INSTANCE_CHAT"
	else
		if IsInRaid() then
			type = "RAID"
		elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
			type = "PARTY"
		else
			type = "WHISPER"
		end
	end
	C_ChatInfo.SendAddonMessage(PallyPower.commPrefix, msg, type, self.player)
	--self:Debug("[Sent Message] prefix: "..PallyPower.commPrefix.." | msg: "..msg.." | type: "..type.." | player name: "..self.player)
end

function PallyPower:SPELLS_CHANGED()
	self:Debug("EVENT: SPELLS_CHANGED")
	self:ScanSpells()
	self:UpdateLayout()
	self:SendSelf()
end

function PallyPower:PLAYER_ENTERING_WORLD()
	self:Debug("EVENT: PLAYER_ENTERING_WORLD")
	--if UnitName("player") == "Dyaxler" then PP_DebugEnabled = true end
end

function PallyPower:CHAT_MSG_ADDON(event, prefix, message, distribution, source)
	local sender = Ambiguate(source, "none")
	if prefix == PallyPower.commPrefix then
		--self:Debug("[EVENT: CHAT_MSG_ADDON] prefix: "..prefix.." | message: "..message.." | distribution: "..distribution.." | sender: "..sender)
	end
	if prefix == PallyPower.commPrefix and (distribution == "PARTY" or distribution == "RAID" or distribution == "INSTANCE_CHAT") then
		self:ParseMessage(sender, message)
	end
end

function PallyPower:CHAT_MSG_SYSTEM(event, text)
	if text then
		if sfind(text, ERR_RAID_YOU_JOINED) or sfind(text, ERR_PARTY_CONVERTED_TO_RAID) then
			self:SendSelf()
			self:SendMessage("REQ")
			self:Debug("EVENT: CHAT_MSG_SYSTEM")
		elseif sfind(text, ERR_RAID_YOU_LEFT) or sfind(text, ERR_LEFT_GROUP_YOU) or sfind(text, ERR_UNINVITE_YOU) or sfind(text, ERR_GROUP_DISBANDED) or sfind(text, ERR_RAID_CONVERTED_TO_PARTY) then
			AllPallys = {}
			SyncList = {}
			PallyPower:ScanSpells()
			PallyPower:ScanInventory()
			if PallyPower_NormalAssignments[UnitName("player")] and PallyPower_NormalAssignments[UnitName("player")][PallyPower:GetClassID(string.upper(UnitClass("player")))] and PallyPower_NormalAssignments[UnitName("player")][PallyPower:GetClassID(string.upper(UnitClass("player")))][UnitName("player")] == (PallyPower.opt.mainTankSpellsW or PallyPower.opt.mainAssistSpellsW or PallyPower.opt.mainTankSpellsDP or PallyPower.opt.mainAssistSpellsDP) then
					SetNormalBlessings(UnitName("player"), PallyPower:GetClassID(string.upper(UnitClass("player"))), UnitName("player"), 0)
					PallyPower_NormalAssignments = {}
			end
			self:Debug("EVENT: CHAT_MSG_SYSTEM")
		end
	end
end

function PallyPower:UNIT_AURA(event, unitTarget)
	local ShowPets = self.opt.ShowPets
	local isPet = unitTarget:find("pet")
	local pclass = select(2, UnitClass(unitTarget))
	if ShowPets then
		if isPet and pclass == "MAGE" then --Warlock Imp pet
			PallyPower:UpdateRoster()
			self:Debug("EVENT: UNIT_AURA - [Warlock Imp Changed Phase]")
		end
	end
end

function PallyPower:CanControl(name)
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
		return (name==self.player) or (AllPallys[name] and (AllPallys[name].freeassign == true))
	else
		if UnitIsGroupLeader(self.player) or UnitIsGroupAssistant(self.player) then
			return true
		else
			return (name==self.player) or (AllPallys[name] and (AllPallys[name].freeassign == true))
		end
	end
end

function PallyPower:CheckLeader(nick)
	if leaders[nick] == true then
		return true
	else
		return false
	end
end

function PallyPower:CheckRaidTanks(nick)
	return raidtanks[nick]
end

function PallyPower:ClearAssignments(sender)
	local leader = self:CheckLeader(sender)
	for name, skills in pairs(PallyPower_Assignments) do
		if leader or name == sender then
			for i = 1, PALLYPOWER_MAXCLASSES do
				PallyPower_Assignments[name][i] = 0
			end
		end
	end
	for pname, classes in pairs(PallyPower_NormalAssignments) do
		if leader or pname == sender then
			for class_id, tnames in pairs(classes) do
				for tname, blessing_id in pairs(tnames) do
					tnames[tname] = nil
				end
			end
		end
	end
	for name, auras in pairs(PallyPower_AuraAssignments) do
		if leader or name == sender then
			PallyPower_AuraAssignments[name] = 0
		end
	end
end

function PallyPower:SyncClear()
	SyncList = {}
end

function PallyPower:SyncAdd(name)
	local chk = 0
	for i, v in ipairs(SyncList) do
		if v == name then
			chk = 1
		end
	end
	if chk == 0 then
		tinsert(SyncList, name)
		tsort(SyncList, function (a, b) return a < b end)
	end
end

function PallyPower:ParseMessage(sender, msg)
	--self:Debug("[Parse Message] sender: "..sender.." | msg: "..msg)
	if sender == self.player or sender == nil then return end
	if not initalized then PallyPower:ScanSpells() end
	local leader = self:CheckLeader(sender)
	if msg == "REQ" then
		self:SendSelf()
	end
	if sfind(msg, "^SELF") then
		PallyPower_NormalAssignments[sender] = {}
		PallyPower_Assignments[sender] = {}
		AllPallys[sender] = {}
		self:SyncAdd(sender)
		_, _, numbers, assign = sfind(msg, "SELF ([0-9n]*)@([0-9n]*)")
		for i = 1, 6 do
			rank = ssub(numbers, (i - 1) * 2 + 1, (i - 1) * 2 + 1)
			talent = ssub(numbers, (i - 1) * 2 + 2, (i - 1) * 2 + 2)
			if rank ~= "n" then
				AllPallys[sender][i] = { }
				AllPallys[sender][i].rank = tonumber(rank)
				AllPallys[sender][i].talent = tonumber(talent)
			end
		end
		-- sort here
		if assign then
			for i = 1, PALLYPOWER_MAXCLASSES do
				tmp =ssub(assign, i, i)
				if tmp == "n" or tmp == "" then tmp = 0 end
				PallyPower_Assignments[sender][i] = tmp + 0
			end
		end
	end
	if sfind(msg, "^ASSIGN") then
		_, _, name, class, skill = sfind(msg, "^ASSIGN (.*) (.*) (.*)")
		if name ~= sender and not (leader or PallyPower.opt.freeassign) then return false end
		if not PallyPower_Assignments[name] then PallyPower_Assignments[name] = {} end
		class = class + 0
		skill = skill + 0
		PallyPower_Assignments[name][class] = skill
	end
	if sfind(msg, "^NASSIGN") then
		for pname, class, tname, skill in string.gmatch(ssub(msg, 9), "([^@]*) ([^@]*) ([^@]*) ([^@]*)") do
			if pname ~= sender and not (leader or PallyPower.opt.freeassign) then return end
			if not PallyPower_NormalAssignments[pname] then PallyPower_NormalAssignments[pname] = {} end
			class = class + 0
			if not PallyPower_NormalAssignments[pname][class] then PallyPower_NormalAssignments[pname][class] = {} end
			skill = skill + 0
			if skill == 0 then skill = nil end
			PallyPower_NormalAssignments[pname][class][tname] = skill
		end
	end
	if sfind(msg, "^MASSIGN") then
		_, _, name, skill = sfind(msg, "^MASSIGN (.*) (.*)")
		if name ~= sender and not (leader or PallyPower.opt.freeassign) then return false end
		if not PallyPower_Assignments[name] then PallyPower_Assignments[name] = {} end
		skill = skill + 0
		for i = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[name][i] = skill
		end
	end
	if sfind(msg, "^SYMCOUNT") then
		_, _, count = sfind(msg, "^SYMCOUNT ([0-9]*)")
		if AllPallys[sender] then
			AllPallys[sender].symbols = count
		else
			self:SendMessage("REQ")
		end
	end
	if sfind(msg, "^CLEAR") then
		if leader then
			self:ClearAssignments(sender)
		elseif self.opt.freeassign then
			self:ClearAssignments(UnitName("player"))
		end
	end
	if msg == "FREEASSIGN YES" and AllPallys[sender] then
		AllPallys[sender].freeassign = true
	end
	if msg == "FREEASSIGN NO" and AllPallys[sender] then
		AllPallys[sender].freeassign = false
	end
	if sfind(msg, "^ASELF") then
		PallyPower_AuraAssignments[sender] = 0
		AllPallys[sender].AuraInfo = { }
		_, _, numbers, assign = sfind(msg, "ASELF ([0-9a-fn]*)@([0-9n]*)")
		for i = 1, PALLYPOWER_MAXAURAS do
			rank = ssub(numbers, (i - 1) * 2 + 1, (i - 1) * 2 + 1)
			talent = ssub(numbers, (i - 1) * 2 + 2, (i - 1) * 2 + 2)
			if rank ~= "n" then
				AllPallys[sender].AuraInfo[i] = { }
				AllPallys[sender].AuraInfo[i].rank = tonumber(rank,16)
				AllPallys[sender].AuraInfo[i].talent = tonumber(talent,16)
			end
		end
		if assign then
			if assign == "n" or assign == "" then
				assign = 0
			end
			PallyPower_AuraAssignments[sender] = assign + 0
		end
	end
	if sfind(msg, "^AASSIGN") then
		_, _, name, aura = sfind(msg, "^AASSIGN (.*) (.*)")
		if name ~= sender and not (leader or PallyPower.opt.freeassign) then return false end
		if not PallyPower_AuraAssignments[name] then PallyPower_AuraAssignments[name] = {} end
		aura = aura + 0
		PallyPower_AuraAssignments[name] = aura
	end
end

function PallyPower:FormatTime(time)
	if not time or time < 0 or time == 9999 then
		return ""
	end
	local mins = floor(time / 60)
	local secs = time - (mins * 60)
	return sformat("%d:%02d", mins, secs)
end

function PallyPower:GetClassID(class)
	for id, name in pairs(self.ClassID) do
		if (name==class) then
			return id
		end
	end
	return -1
end

function PallyPower:UpdateRoster()
	self:Debug("UpdateRoster()")
	self:CancelTimer(self.InventoryScan)
	local units
	for i = 1, PALLYPOWER_MAXCLASSES do
		classlist[i] = 0
		classes[i] = {}
	end
	if IsInRaid() then
		units = raid_units
	else
		units = party_units
	end
	twipe(roster)
	twipe(leaders)
	for _, unitid in ipairs(units) do
		if unitid and UnitExists(unitid) then
			local tmp = {}
			tmp.unitid = unitid
			tmp.name = UnitName(unitid)
			local ShowPets = self.opt.ShowPets
			local isPet = tmp.unitid:find("pet")
			local pclass = select(2, UnitClass(unitid))
			if ShowPets or not isPet then
				if isPet and pclass == "MAGE" then --Warlock Imp pet
					local i = 1
					local name, icon = UnitBuff(unitid, i)
					local isPhased = false
					while name do
						if icon == 136164 then
							self:Debug("isPet [isPhased]: "..tmp.name)
							isPhased = true
							break
						end
						i = i + 1
						name, icon = UnitBuff(unitid, i)
					end
					if not isPhased then
						self:Debug("isPet [notPhased]: "..tmp.name)
						tmp.class = "PET"
					end
				elseif isPet then --All other pet's
					self:Debug("isPet: "..tmp.name)
					tmp.class = "PET"
				else --Players
					--self:Debug("isPlayer: "..tmp.name)
					tmp.class = select(2, UnitClass(unitid))
				end
			end
			if IsInRaid() then
				local n = select(3, unitid:find("(%d+)"))
				tmp.name, tmp.rank, tmp.subgroup = GetRaidRosterInfo(n)
				local raidtank = select(10, GetRaidRosterInfo(n))
				local class = PallyPower:GetClassID(pclass)
				-- Warriors
				if (class == 1) then
					if (raidtanks[tmp.name] == true) then
						if PallyPower_NormalAssignments[UnitName("player")] and PallyPower_NormalAssignments[UnitName("player")][class] and PallyPower_NormalAssignments[UnitName("player")][class][tmp.name] == PallyPower.opt.mainTankSpellsW then
							SetNormalBlessings(UnitName("player"), class, tmp.name, 0)
							raidtanks[tmp.name] = false
						end
					end
					if (raidtanks[tmp.name] == true) then
						if PallyPower_NormalAssignments[UnitName("player")] and PallyPower_NormalAssignments[UnitName("player")][class] and PallyPower_NormalAssignments[UnitName("player")][class][tmp.name] == PallyPower.opt.mainAssistSpellsW then
							SetNormalBlessings(UnitName("player"), class, tmp.name, 0)
							raidtanks[tmp.name] = false
						end
					end
					if (raidtank == "MAINTANK" and PallyPower.opt.mainTank) then
						if PallyPower_Assignments[UnitName("player")] and (PallyPower_Assignments[UnitName("player")][class] == PallyPower.opt.mainTankGSpellsW) then
							SetNormalBlessings(UnitName("player"), class, tmp.name, PallyPower.opt.mainTankSpellsW)
							raidtanks[tmp.name] = true
						end
					end
					if (raidtank == "MAINASSIST" and PallyPower.opt.mainAssist) then
						if PallyPower_Assignments[UnitName("player")] and (PallyPower_Assignments[UnitName("player")][class] == PallyPower.opt.mainAssistGSpellsW) then
							SetNormalBlessings(UnitName("player"), class, tmp.name, PallyPower.opt.mainAssistSpellsW)
							raidtanks[tmp.name] = true
						end
					end
				end
				-- Druids and Paladins
				if (class == 4 or class == 5) then
					if (raidtanks[tmp.name] == true) then
						if PallyPower_NormalAssignments[UnitName("player")] and PallyPower_NormalAssignments[UnitName("player")][class] and PallyPower_NormalAssignments[UnitName("player")][class][tmp.name] == PallyPower.opt.mainTankSpellsDP then
							SetNormalBlessings(UnitName("player"), class, tmp.name, 0)
							raidtanks[tmp.name] = false
						end
					end
					if (raidtanks[tmp.name] == true) then
						if PallyPower_NormalAssignments[UnitName("player")] and PallyPower_NormalAssignments[UnitName("player")][class] and PallyPower_NormalAssignments[UnitName("player")][class][tmp.name] == PallyPower.opt.mainAssistSpellsDP then
							SetNormalBlessings(UnitName("player"), class, tmp.name, 0)
							raidtanks[tmp.name] = false
						end
					end
					if (raidtank == "MAINTANK" and PallyPower.opt.mainTank) then
						if PallyPower_Assignments[UnitName("player")] and (PallyPower_Assignments[UnitName("player")][class] == PallyPower.opt.mainTankGSpellsDP) then
							SetNormalBlessings(UnitName("player"), class, tmp.name, PallyPower.opt.mainTankSpellsDP)
							raidtanks[tmp.name] = true
						end
					end
					if (raidtank == "MAINASSIST" and PallyPower.opt.mainAssist) then
						if PallyPower_Assignments[UnitName("player")] and (PallyPower_Assignments[UnitName("player")][class] == PallyPower.opt.mainAssistGSpellsDP) then
							SetNormalBlessings(UnitName("player"), class, tmp.name, PallyPower.opt.mainAssistSpellsDP)
							raidtanks[tmp.name] = true
						end
					end
				end
			else
				tmp.rank = UnitIsGroupLeader(unitid) and 2 or 0
				tmp.subgroup = 1
			end
			if pclass == "PALADIN" then
				if AllPallys[tmp.name] then
					AllPallys[tmp.name].subgroup = tmp.subgroup
				end
			end
			if tmp.rank > 0 then
				if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
					leaders[tmp.name] = false
				else
					leaders[tmp.name] = true
				end
			end
			if tmp.subgroup then
				tinsert(roster, tmp)
				for i = 1, PALLYPOWER_MAXCLASSES do
					if tmp.class == self.ClassID[i] then
						tmp.visible = false
						tmp.hasbuff = false
						tmp.specialbuff = false
						tmp.dead = false
						classlist[i] = classlist[i] + 1
						tinsert(classes[i], tmp)
					end
				end
			end
		end
	end
	self:UpdateLayout()
end

function PallyPower:ScanClass(classID)
	local class = classes[classID]
	for playerID, unit in pairs(class) do
		if unit.unitid then
			local spellID, gspellID = self:GetSpellID(classID, unit.name)
			local spell = PallyPower.Spells[spellID]
			local spell2 = PallyPower.GSpells[spellID]
			local gspell = PallyPower.GSpells[gspellID]
			unit.visible = IsSpellInRange(spell, unit.unitid) == 1
			unit.dead = UnitIsDeadOrGhost(unit.unitid)
			unit.hasbuff = self:IsBuffActive(spell, spell2, unit.unitid)
			unit.specialbuff = spellID ~= gspellID
		end
	end
end

function PallyPower:CreateLayout()
	self:Debug("CreateLayout()")
	local p = _G["PallyPowerFrame"]
	self.Header = p
  self.autoButton = CreateFrame("Button", "PallyPowerAuto", self.Header, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureHandlerStateTemplate, SecureActionButtonTemplate, PallyPowerAutoButtonTemplate")
	self.autoButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	self.rfButton = CreateFrame("Button", "PallyPowerRF", self.Header, "PallyPowerRFButtonTemplate")
	self.rfButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	self.auraButton = CreateFrame("Button", "PallyPowerAura", self.Header, "PallyPowerAuraButtonTemplate")
	self.auraButton:RegisterForClicks("LeftButtonDown")
	self.classButtons = {}
	self.playerButtons = {}
	self.autoButton:Execute([[childs = table.new()]]);
	for cbNum = 1, PALLYPOWER_MAXCLASSES do
		local cButton = CreateFrame("Button", "PallyPowerC" .. cbNum, self.Header, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureHandlerStateTemplate, SecureActionButtonTemplate, PallyPowerButtonTemplate")
 		SecureHandlerSetFrameRef(self.autoButton, "child", cButton)
	  SecureHandlerExecute(self.autoButton, [[
			local child = self:GetFrameRef("child")
			childs[#childs+1] = child;
		]])
    cButton:Execute([[others = table.new()]])
		cButton:Execute([[childs = table.new()]])
    cButton:SetAttribute("_onenter", [[
			for _, other in ipairs(others) do
				 other:SetAttribute("state-inactive", self)
			end
			local leadChild;
			for _, child in ipairs(childs) do
					if child:GetAttribute("Display") == 1 then
							child:Show()
							if (leadChild) then
									leadChild:AddToAutoHide(child)
							else
									leadChild = child
									leadChild:RegisterAutoHide(2)
							end
					end
			end
			if (leadChild) then
					leadChild:AddToAutoHide(self)
			end
		]])
    cButton:SetAttribute("_onstate-inactive", [[
			childs[1]:Hide()
		]])
		cButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		cButton:EnableMouseWheel(1)
    self.classButtons[cbNum] = cButton
		self.playerButtons[cbNum] = {}
		local pButtons = self.playerButtons[cbNum]
    local leadChild
		for pbNum = 1, PALLYPOWER_MAXPERCLASS do -- create player buttons for each class
			local pButton = CreateFrame("Button","PallyPowerC".. cbNum .. "P" .. pbNum, UIParent, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate, SecureActionButtonTemplate, PallyPowerPopupTemplate")
			pButton:SetParent(cButton)
			SecureHandlerSetFrameRef(cButton, "child", pButton)
	    SecureHandlerExecute(cButton, [[
				local child = self:GetFrameRef("child")
				childs[#childs+1] = child;
			]])
			if pbNum == 1 then
				pButton:Execute([[siblings = table.new()]]);
				pButton:SetAttribute("_onhide", [[
					for _, sibling in ipairs(siblings) do
						sibling:Hide()
					end
				]])
				leadChild = pButton
			else
				SecureHandlerSetFrameRef(leadChild, "sibling", pButton)
	      SecureHandlerExecute(leadChild, [[
					local sibling = self:GetFrameRef("sibling")
					siblings[#siblings+1] = sibling;
				]])
			end
			pButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
			pButton:EnableMouseWheel(1)
			pButton:Hide();
			pButtons[pbNum] = pButton
		end -- by pbNum
	end -- by classIndex
	for cbNum = 1, PALLYPOWER_MAXCLASSES do
		local cButton = self.classButtons[cbNum];
		for cbOther = 1, PALLYPOWER_MAXCLASSES do
			if (cbOther ~= cbNum) then
				local oButton = self.classButtons[cbOther];
 				SecureHandlerSetFrameRef(cButton, "other", oButton)
	      		SecureHandlerExecute(cButton, [[
				local other = self:GetFrameRef("other")
				others[#others+1] = other;
			  ]])
			end
		end
	end
	self:UpdateLayout()
end

function PallyPower:CountClasses()
	local val = 0
	if not classes then return 0 end
	for i = 1, PALLYPOWER_MAXCLASSES do
		if classlist[i] and classlist[i] > 0 then
			val = val + 1
		end
	end
	return val
end

function PallyPower:UpdateLayout()
	self:Debug("UpdateLayout()")
	if InCombatLockdown() then return false end
	PallyPowerFrame:SetScale(self.opt.buffscale)
	local x = self.opt.display.buttonWidth
	local y = self.opt.display.buttonHeight
	local point = "TOPLEFT"
	local pointOpposite = "BOTTOMLEFT"
	local layout = PallyPower.Layouts[self.opt.layout]
	for cbNum = 1, PALLYPOWER_MAXCLASSES do
		cx = layout.c[cbNum].x
		cy = layout.c[cbNum].y
		local cButton = self.classButtons[cbNum]
		self:SetButton("PallyPowerC" .. cbNum)
		cButton.x = cx * x
		cButton.y = cy * y
		cButton:ClearAllPoints()
		cButton:SetPoint(point, self.Header, "CENTER", cButton.x, cButton.y)
		local pButtons = self.playerButtons[cbNum]
		for pbNum = 1, PALLYPOWER_MAXPERCLASS do
			px = layout.c[cbNum].p[pbNum].x
			py = layout.c[cbNum].p[pbNum].y
			local pButton = pButtons[pbNum]
			self:SetPButton("PallyPowerC".. cbNum .. "P" .. pbNum)
			pButton:ClearAllPoints()
			pButton:SetPoint(point, self.Header, "CENTER",
				cButton.x + px * x,
				cButton.y + py * y
			)
		end
	end
	local ox = layout.ab.x * x
	local oy = layout.ab.y * y
	local autob = self.autoButton
	autob:ClearAllPoints()
	autob:SetPoint(point, self.Header, "CENTER", ox, oy)
	autob:SetAttribute("type", "spell")
	if PP_IsPally and self.opt.enabled and self.opt.autobuff.autobutton and ((GetNumGroupMembers() == 0 and self.opt.ShowWhenSolo) or (GetNumGroupMembers() > 0 and self.opt.ShowInParty)) then
		autob:Show()
	else
		autob:Hide()
	end
	local rfb = self.rfButton
	if self.opt.autobuff.autobutton then
		ox = layout.rf.x * x
		oy = layout.rf.y * y
		rfb:ClearAllPoints()
		rfb:SetPoint(point, self.Header, "CENTER", ox, oy)
	else
		ox = layout.rfd.x * x
		oy = layout.rfd.y * y
		rfb:ClearAllPoints()
		rfb:SetPoint(point, self.Header, "CENTER", ox, oy)
	end
	rfb:SetAttribute("type1", "spell")
	rfb:SetAttribute("unit1", "player")
	PallyPower:RFAssign(self.opt.rf)
	rfb:SetAttribute("type2", "spell")
	rfb:SetAttribute("unit2", "player")
	PallyPower:SealAssign(self.opt.seal)
	if PP_IsPally and self.opt.enabled and self.opt.rfbuff and ((GetNumGroupMembers() == 0 and self.opt.ShowWhenSolo) or (GetNumGroupMembers() > 0 and self.opt.ShowInParty)) then
		rfb:Show()
	else
		rfb:Hide()
	end
	local auraBtn = self.auraButton
	if (not self.opt.autobuff.autobutton and self.opt.rfbuff) or (self.opt.autobuff.autobutton and not self.opt.rfbuff) then
		ox = layout.aud1.x * x
		oy = layout.aud1.y * y
		auraBtn:ClearAllPoints()
		auraBtn:SetPoint(point, self.Header, "CENTER", ox, oy)
	elseif not self.opt.autobuff.autobutton and not self.opt.rfbuff then
		ox = layout.aud2.x * x
		oy = layout.aud2.y * y
		auraBtn:ClearAllPoints()
		auraBtn:SetPoint(point, self.Header, "CENTER", ox, oy)
	else
		ox = layout.au.x * x
		oy = layout.au.y * y
		auraBtn:ClearAllPoints()
		auraBtn:SetPoint(point, self.Header, "CENTER", ox, oy)
	end
	auraBtn:SetAttribute("type1", "spell")
	auraBtn:SetAttribute("unit1", "player")
	PallyPower:UpdateAuraButton(PallyPower_AuraAssignments[self.player])
	if PP_IsPally and self.opt.enabled and self.opt.auras and (AllPallys[self.player].AuraInfo[1] ~= nil) and ((GetNumGroupMembers() == 0 and self.opt.ShowWhenSolo) or (GetNumGroupMembers() > 0 and self.opt.ShowInParty)) then
		auraBtn:Show()
	else
		auraBtn:Hide()
	end
	local cbNum = 0
	for classIndex = 1, PALLYPOWER_MAXCLASSES do
	local _, gspellID = PallyPower:GetSpellID(classIndex)
		if (classlist[classIndex] and classlist[classIndex] ~= 0 and (gspellID ~= 0 or PallyPower:NormalBlessingCount(classIndex) > 0)) then
			cbNum = cbNum + 1
			local cButton = self.classButtons[cbNum]
  		if self.opt.display.showClassButtons and ((GetNumGroupMembers() == 0 and self.opt.ShowWhenSolo) or (GetNumGroupMembers() > 0 and self.opt.ShowInParty)) then
  			cButton:Show()
			else
				cButton:Hide()
  		end
			cButton:SetAttribute("Display", 1)
			cButton:SetAttribute("classID", classIndex)
			cButton:SetAttribute("type1", "spell")
			cButton:SetAttribute("type2", "spell")
			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, math.min(classlist[classIndex], PALLYPOWER_MAXPERCLASS) do
				local pButton = pButtons[pbNum]
				if self.opt.display.showPlayerButtons then
					pButton:SetAttribute("Display", 1)
				else
					pButton:SetAttribute("Display", 0)
				end
				pButton:SetAttribute("classID", classIndex)
				pButton:SetAttribute("playerID", pbNum)
				local unit  = self:GetUnit(classIndex, pbNum)
				local spellID, gspellID = self:GetSpellID(classIndex, unit.name)
				local spell = PallyPower.Spells[spellID]
				local gspell = PallyPower.GSpells[spellID]
				pButton:SetAttribute("type1", "spell")
				pButton:SetAttribute("unit1", unit.unitid)
				pButton:SetAttribute("spell1", gspell)
				pButton:SetAttribute("type2", "spell")
				pButton:SetAttribute("unit2", unit.unitid)
				pButton:SetAttribute("spell2", spell)
			end
			for pbNum = classlist[classIndex]+1, PALLYPOWER_MAXPERCLASS do
				local pButton = pButtons[pbNum]
				pButton:SetAttribute("Display", 0)
				pButton:SetAttribute("classID", 0)
				pButton:SetAttribute("playerID", 0)
			end
		end
	end
	cbNum = cbNum + 1
	for i = cbNum, PALLYPOWER_MAXCLASSES do
		local cButton = self.classButtons[i]
		cButton:SetAttribute("Display", 0)
		cButton:SetAttribute("classID", 0)
		cButton:Hide()
		local pButtons = self.playerButtons[cbNum]
		for pbNum = 1, PALLYPOWER_MAXPERCLASS do
			local pButton = pButtons[pbNum]
			pButton:SetAttribute("Display", 0)
			pButton:SetAttribute("classID", 0)
			pButton:SetAttribute("playerID", 0)
			pButton:Hide()
		end
	end
	self:ButtonsUpdate()
	self:UpdateAnchor(displayedButtons)
end

function PallyPower:SetButton(baseName)
	local time = _G[baseName.."Time"]
	local text = _G[baseName.."Text"]
	if (self.opt.display.HideCountText) then
		text:Hide()
	else
		text:Show()
	end
	if (self.opt.display.HideTimerText) then
		time:Hide()
	else
		time:Show()
	end
end

function PallyPower:SetPButton(baseName)
	local rng = _G[baseName.."Rng"]
	local dead = _G[baseName.."Dead"]
	local name = _G[baseName.."Name"]
	if (self.opt.display.HideRngText) then
		rng:Hide()
	else
		rng:Show()
	end
	if (self.opt.display.HideDeadText) then
		dead:Hide()
	else
		dead:Show()
	end
	if (self.opt.display.HideNameText) then
		name:Hide()
	else
		name:Show()
	end
end

function PallyPower:UpdateButton(button, baseName, classID)
	local button = _G[baseName]
	local classIcon = _G[baseName.."ClassIcon"]
	local buffIcon = _G[baseName.."BuffIcon"]
	local time = _G[baseName.."Time"]
	local time2 = _G[baseName.."Time2"]
	local text = _G[baseName.."Text"]
	local nneed = 0
	local nspecial = 0
	local nhave = 0
	local ndead = 0
	for playerID, unit in pairs(classes[classID]) do
		testbutton = classes
		if unit.visible then
			if not unit.hasbuff then
				if unit.specialbuff then
					nspecial = nspecial + 1
				else
					nneed = nneed + 1
				end
			else
				nhave = nhave + 1
			end
		else
			if unit.hasbuff then
				nhave = nhave + 1
			else
				nneed = nneed + 1
			end
		end
		if unit.dead then
			ndead = ndead + 1
		end
	end
	classIcon:SetTexture(self.ClassIcons[classID])
	classIcon:SetVertexColor(1, 1, 1)
	local _, gspellID = PallyPower:GetSpellID(classID)
	buffIcon:SetTexture(self.BlessingIcons[gspellID])
	if InCombatLockdown() then
		buffIcon:SetVertexColor(0.4, 0.4, 0.4)
	else
		buffIcon:SetVertexColor(1, 1, 1)
	end
	local classExpire, classDuration, specialExpire, specialDuration = self:GetBuffExpiration(classID)
	time:SetText(self:FormatTime(classExpire))
	time:SetTextColor(self:GetSeverityColor(classExpire and classDuration and (classExpire/classDuration) or 0))
	time2:SetText(self:FormatTime(specialExpire))
	time2:SetTextColor(self:GetSeverityColor(specialExpire and specialDuration and (specialExpire/specialDuration) or 0))
	if (nneed+nspecial > 0) then
		text:SetText(nneed+nspecial)
	else
		text:SetText("")
	end
	if (nhave == 0) then
		self:ApplyBackdrop(button, self.opt.cBuffNeedAll)
	elseif (nneed > 0) then
 		self:ApplyBackdrop(button, self.opt.cBuffNeedSome)
	elseif (nspecial > 0) then
  		self:ApplyBackdrop(button, self.opt.cBuffNeedSpecial)
	else
  		self:ApplyBackdrop(button, self.opt.cBuffGood)
	end
	return classExpire, classDuration, specialExpire, specialDuration, nhave, nneed, nspecial
end

function PallyPower:GetSeverityColor(percent)
	if (percent >= 0.5) then
		return (1.0-percent)*2, 1.0, 0.0
	else
		return 1.0, percent*2, 0.0
	end
end

function PallyPower:GetBuffExpiration(classID)
	local class = classes[classID]
	local classExpire, classDuration, specialExpire, specialDuration = 9999, 9999, 9999, 9999
	for playerID, unit in pairs(class) do
		if unit.unitid then
			local j = 1
			local spellID, gspellID = self:GetSpellID(classID, unit.name)
			local spell = PallyPower.Spells[spellID]
			local gspell = PallyPower.GSpells[gspellID]
			local buffName, _, _, _, buffDuration, buffExpire = LibClassicDurations:UnitAura(unit.unitid, j)
			while buffExpire do
				buffExpire = buffExpire - GetTime()
				if (buffName == gspell) then
					classExpire = min(classExpire, buffExpire)
					classDuration = min(classDuration, buffDuration)
					--self:Debug("[GetBuffExpiration] buffName: "..buffName.." | classExpire: "..classExpire.." | classDuration: "..classDuration)
					break
				elseif (buffName == spell) then
					specialExpire = min(specialExpire, buffExpire)
					specialDuration = min(specialDuration, buffDuration)
					--self:Debug("[GetBuffExpiration] buffName: "..buffName.." | specialExpire: "..classExpire.." | specialDuration: "..classDuration)
					break
				end
				j = j + 1
				buffName, _, _, _, buffDuration, buffExpire = LibClassicDurations:UnitAura(unit.unitid, j)
			end
		end
	end
	return classExpire, classDuration, specialExpire, specialDuration
end

function PallyPower:GetRFExpiration()
  local spell = PallyPower.RFSpell
  local j = 1
  local rfExpire, rfDuration = 9999, 30*60
	local buffName, _, _, _, buffDuration, buffExpire = UnitBuff("player", j)
	while buffExpire do
		if buffName == spell then
			rfExpire = buffExpire - GetTime()
			break
		end
		j = j + 1
		buffName, _, _, _, buffDuration, buffExpire = UnitBuff("player", j)
	end
	return rfExpire, rfDuration
end

function PallyPower:GetSealExpiration()
    local spell = PallyPower.Seals[self.opt.seal]
    local j = 1
    local sealExpire, sealDuration = 9999, 30*60
	local buffName, _, _, _, buffDuration, buffExpire = UnitBuff("player", j)
	while buffExpire do
		if buffName == spell then
			sealExpire = buffExpire - GetTime()
			break
		end
		j = j + 1
		buffName, _, _, _, buffDuration, buffExpire = UnitBuff("player", j)
	end
	return sealExpire, sealDuration
end

function PallyPower:UpdatePButton(button, baseName, classID, playerID)
	local button = _G[baseName]
	local buffIcon = _G[baseName.."BuffIcon"]
	local rng  = _G[baseName.."Rng"]
	local dead = _G[baseName.."Dead"]
	local name = _G[baseName.."Name"]
	local time = _G[baseName.."Time"]
	local unit = classes[classID][playerID]
	if unit then
		local nneed = 0
		local nspecial = 0
		local nhave = 0
		local ndead = 0
		if unit.visible then
			if not unit.hasbuff then
				if unit.specialbuff then
					nspecial = 1
				end
			else
				nhave = 1
			end
		else
			if unit.hasbuff then
				nhave = 1
			else
				nneed = 1
			end
		end
		if unit.dead then
			ndead = 1
		end
		local spellID, gspellID = self:GetSpellID(classID, unit.name)
		buffIcon:SetTexture(self.BlessingIcons[spellID])
		buffIcon:SetVertexColor(1, 1, 1)
		time:SetText(self:FormatTime(unit.hasbuff))
		if (not InCombatLockdown()) then
			button:SetAttribute("spell1", PallyPower.GSpells[gspellID])
			button:SetAttribute("spell2", PallyPower.Spells[spellID])
		end
		if (nspecial == 1) then
  			self:ApplyBackdrop(button, self.opt.cBuffNeedSpecial)
		elseif (nhave == 0) then
   			self:ApplyBackdrop(button, self.opt.cBuffNeedAll)
		else
   			self:ApplyBackdrop(button, self.opt.cBuffGood)
		end
		if unit.hasbuff then
			buffIcon:SetAlpha(1)
			if not unit.visible then
				rng:SetVertexColor(1, 0, 0)
				rng:SetAlpha(1)
			else
				rng:SetVertexColor(0, 1, 0)
			rng:SetAlpha(1)
			end
			dead:SetAlpha(0)
		else
			buffIcon:SetAlpha(0.4)
			if not unit.visible then
				rng:SetVertexColor(1, 0, 0)
				rng:SetAlpha(1)
			else
				rng:SetVertexColor(0, 1, 0)
				rng:SetAlpha(1)
			end
			if unit.dead then
				dead:SetVertexColor(1, 0, 0)
				dead:SetAlpha(1)
			else
				dead:SetVertexColor(0, 1, 0)
				dead:SetAlpha(0)
			end
		end
		local shortname = Ambiguate(unit.name, "short")
		name:SetText(shortname)
	else
		self:ApplyBackdrop(button, self.opt.cBuffGood)
		buffIcon:SetAlpha(0)
		rng:SetAlpha(0)
		dead:SetAlpha(0)
	end
end

function PallyPower:ButtonsUpdate()
	--self:Debug("ButtonsUpdate()")
	local minClassExpire, minClassDuration, minSpecialExpire, minSpecialDuration, sumnhave, sumnneed, sumnspecial = 9999, 9999, 9999, 9999, 0, 0, 0
	for cbNum = 1, PALLYPOWER_MAXCLASSES do -- scan classes and if populated then assign textures, etc
		local cButton = self.classButtons[cbNum]
		local classIndex = cButton:GetAttribute("classID")
		if classIndex > 0 then
			self:ScanClass(classIndex) -- scanning for in-range and buffs
			local classExpire, specialExpire, nhave, nneed, nspecial
			classExpire, classDuration, specialExpire, specialDuration, nhave, nneed, nspecial = self:UpdateButton(cButton, "PallyPowerC"..cbNum, classIndex)
			minClassExpire = min(minClassExpire, classExpire)
			minSpecialExpire = min(minSpecialExpire, specialExpire)
			minClassDuration = min(minClassDuration, classDuration)
			minSpecialDuration = min(minSpecialDuration, specialDuration)
			sumnhave = sumnhave + nhave
			sumnneed = sumnneed + nneed
			sumnspecial = sumnspecial + nspecial
			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, PALLYPOWER_MAXPERCLASS do
				local pButton = pButtons[pbNum]
				local playerIndex = pButton:GetAttribute("playerID")
				if playerIndex > 0 then
					self:UpdatePButton(pButton, "PallyPowerC".. cbNum .."P".. pbNum, classIndex, playerIndex)
				end
			end -- by pbnum
		end -- class has players
	end  -- by cnum
	local autobutton = _G["PallyPowerAuto"]
	local time = _G["PallyPowerAutoTime"]
	local time2 = _G["PallyPowerAutoTime2"]
	local text = _G["PallyPowerAutoText"]
	if (sumnhave == 0) then
  		self:ApplyBackdrop(autobutton, self.opt.cBuffNeedAll)
	elseif (sumnneed > 0) then
  		self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSome)
	elseif (sumnspecial > 0) then
		self:ApplyBackdrop(autobutton, self.opt.cBuffNeedSpecial)
	else
  		self:ApplyBackdrop(autobutton, self.opt.cBuffGood)
	end
	time:SetText(self:FormatTime(minClassExpire))
	time:SetTextColor(self:GetSeverityColor(minClassExpire and minClassDuration and (minClassExpire/minClassDuration) or 0))
	time2:SetText(self:FormatTime(minSpecialExpire))
	time2:SetTextColor(self:GetSeverityColor(minSpecialExpire and minSpecialDuration and (minSpecialExpire/minSpecialDuration) or 0))
	if (sumnneed+sumnspecial > 0) then
		text:SetText(sumnneed+sumnspecial)
	else
		text:SetText("")
	end
	local rfbutton = _G["PallyPowerRF"]
	local time1 = _G["PallyPowerRFTime1"] -- rf timer
	local time2 = _G["PallyPowerRFTime2"] -- seal timer
	local expire1, duration1 = PallyPower:GetRFExpiration()
	local expire2, duration2 = PallyPower:GetSealExpiration()
	if self.opt.rf then
		time1:SetText(self:FormatTime(expire1))
		time1:SetTextColor(self:GetSeverityColor(expire1/duration1))
	else
		time1:SetText("")
	end
	time2:SetText(self:FormatTime(expire2))
	time2:SetTextColor(self:GetSeverityColor(expire2/duration2))
	if (expire1 == 9999 and self.opt.rf) and (expire2 == 9999 and self.opt.seal == 0) then
  		self:ApplyBackdrop(rfbutton, self.opt.cBuffNeedAll)
  	elseif (expire1 == 9999 and self.opt.rf) or (expire2 == 9999 and self.opt.seal > 0) then
  	    self:ApplyBackdrop(rfbutton, self.opt.cBuffNeedSome)
	else
  		self:ApplyBackdrop(rfbutton, self.opt.cBuffGood)
	end
	if self.opt.auras then
		PallyPower:UpdateAuraButton( PallyPower_AuraAssignments[self.player] )
	end
end

function PallyPower:UpdateAnchor(displayedButtons)
	PallyPowerAnchor:SetChecked(self.opt.display.frameLocked)
	if self.opt.display.enableDragHandle and ((GetNumGroupMembers() == 0 and self.opt.ShowWhenSolo) or (GetNumGroupMembers() > 0 and self.opt.ShowInParty)) then
		PallyPowerAnchor:Show()
	else
		PallyPowerAnchor:Hide()
	end
end

function PallyPower:NormalBlessingCount(classID)
	local nbcount = 0
	if classlist[classID] then
		for pbNum = 1, math.min(classlist[classID], PALLYPOWER_MAXPERCLASS) do
			local unit  = self:GetUnit(classID, pbNum)
			if unit and unit.name and
			PallyPower_NormalAssignments[self.player] and
			PallyPower_NormalAssignments[self.player][classID] and
			PallyPower_NormalAssignments[self.player][classID][unit.name] then
				nbcount = nbcount+1
			end
		end -- by pbnum
	end
	return nbcount
end

function PallyPower:GetSpellID(classID, playerName)
	local normal = 0
	local greater = 0
	if playerName and
	   PallyPower_NormalAssignments[self.player] and
	   PallyPower_NormalAssignments[self.player][classID] and
	   PallyPower_NormalAssignments[self.player][classID][playerName] then
		normal = PallyPower_NormalAssignments[self.player][classID][playerName]
	end
	if PallyPower_Assignments[self.player] and PallyPower_Assignments[self.player][classID] then
		greater = PallyPower_Assignments[self.player][classID]
	end
	if normal == 0 then
		normal = greater
	end
	return normal, greater
end

function PallyPower:GetUnit(classID, playerID)
	return classes[classID][playerID]
end

function PallyPower:GetUnitAndSpellSmart(classID, mousebutton)
	local i, unit
	local class = classes[classID]
 	local spellID, gspellID = PallyPower:GetSpellID(classID)
	local spell, gspell
	if (mousebutton == "LeftButton") then
		gspell = PallyPower.GSpells[gspellID]
		for i, unit in pairs(class) do
			if IsSpellInRange(gspell, unit.unitid) == 1 then
				spellID, gspellID = PallyPower:GetSpellID(classID, unit.name)
				spell = PallyPower.Spells[spellID]
				gspell = PallyPower.GSpells[gspellID]
				return unit.unitid, spell, gspell
			end
		end
	elseif (mousebutton == "RightButton") then
		for i, unit in pairs(class) do
			spellID, gspellID = PallyPower:GetSpellID(classID, unit.name)
		 	spell = PallyPower.Spells[spellID]
			spell2 = PallyPower.GSpells[spellID]
			gspell = PallyPower.GSpells[gspellID]
			local buffExpire, buffDuration = self:IsBuffActive(spell, spell2, unit.unitid)
			if (not buffExpire or buffExpire/buffDuration < 0.5) and IsSpellInRange(spell, unit.unitid) == 1 then
				return unit.unitid, spell, gspell
			end
		end
	end
	return nil, "", ""
end

function PallyPower:IsBuffActive(spellName, gspellName, unitID)
	local j = 1
	while UnitBuff(unitID, j) do
		local buffName, _, _, _, buffDuration, buffExpire = LibClassicDurations:UnitAura(unitID, j)
		if (buffName == spellName) or (buffName == gspellName) then
			if buffExpire then
				buffExpire = buffExpire - GetTime()
			end
			--self:Debug("[IsBuffActive] buffName: "..buffName.." | buffExpire: "..buffExpire.." | buffDuration: "..buffDuration)
			return buffExpire, buffDuration, buffName
		end
		j = j + 1
	end
	return nil
end

function PallyPower:ButtonPreClick(button, mousebutton)
	if (not InCombatLockdown()) then
		local classID = button:GetAttribute("classID")
		local unitid, spell, gspell = PallyPower:GetUnitAndSpellSmart(classID, mousebutton)
		if not unitid then
			spell = "qq"
			gspell = "qq"
		end
		-- left click (find first nearby player and do 15 minute buff)
		button:SetAttribute("unit1", unitid)
		button:SetAttribute("spell1", gspell)
		-- right click (find first nearby player without buff and do a 5 minute buff)
		button:SetAttribute("unit2", unitid)
		button:SetAttribute("spell2", spell)
	end
end

--
-- Drag Handle
--

-- Lock & Unlock the frame on left click, and toggle config dialog with right click
function PallyPower:ClickHandle(button, mousebutton)
	local function RelockActionBars()
		self.opt.display.frameLocked = true
		if (self.opt.display.LockBuffBars) then
			LOCK_ACTIONBAR = "1"
		end
		_G["PallyPowerAnchor"]:SetChecked(true)
	end
	if (mousebutton == "RightButton") then
		if IsShiftKeyDown() then
			PallyPower:OpenConfigWindow()
			button:SetChecked(self.opt.display.frameLocked)
		else
			if GetNumGroupMembers() > 0 and PP_IsPally then
				PallyPower:SendSelf()
				PallyPower:SendMessage("REQ")
			end
			PallyPower:ScanSpells()
			PallyPower:ScanInventory()
			PallyPowerBlessings_Toggle()
			button:SetChecked(self.opt.display.frameLocked)
		end
	elseif (mousebutton == "LeftButton") then
		self.opt.display.frameLocked = not self.opt.display.frameLocked
		if (self.opt.display.frameLocked) then
			if (self.opt.display.LockBuffBars) then
				LOCK_ACTIONBAR = "1"
			end
		else
			if (self.opt.display.LockBuffBars) then
				LOCK_ACTIONBAR = "0"
			end
			self:ScheduleTimer(RelockActionBars, 30)
		end
	button:SetChecked(self.opt.display.frameLocked)
	end
end

-- Start dragging if not locked
function PallyPower:DragStart()
	if (not self.opt.display.frameLocked) then
		_G["PallyPowerFrame"]:StartMoving()
	end
end

-- End dragging
function PallyPower:DragStop()
	_G["PallyPowerFrame"]:StopMovingOrSizing()
end

function PallyPower:AutoBuff(button, mousebutton)
	self:Debug("AutoBuff(): mousebutton["..mousebutton.."]")
	if InCombatLockdown() then return end
	local now = time()
	local greater = (mousebutton == "LeftButton" or mousebutton == "Hotkey2")
	if greater then
		self:Debug("AutoBuff(): Greater Blessing")
		local groupCount = {}
		local HLspell = PallyPower.HLSpell
		if (IsInRaid() == true) then
			for _, unit in ipairs(roster) do
				local subgroup = unit.subgroup
				groupCount[subgroup] = (groupCount[subgroup] or 0) + 1
			end
		end
		local minExpire, minUnit, minSpell, maxSpell = 9999, nil, nil, nil
		for i = 1, PALLYPOWER_MAXCLASSES do
			local classMinExpire, classNeedsBuff, classMinUnitPenalty, classMinUnit, classMinSpell, classMaxSpell = 9999, true, 9999, nil, nil, nil
			for j = 1, PALLYPOWER_MAXPERCLASS do
				if (classes[i] and classes[i][j]) then
					local unit = classes[i][j]
					local spellid, gspellid = self:GetSpellID(i, unit.name)
					local spell = PallyPower.Spells[spellid]
					local spell2 = PallyPower.GSpells[spellid]
					local gspell = PallyPower.GSpells[gspellid]
					if (spellid == gspellid and unit.unitid) then
						if (IsSpellInRange(spell, unit.unitid) == 1) then
							local penalty = 0
							if (self.AutoBuffedList[unit.name] and now - self.AutoBuffedList[unit.name] < 20) then
								penalty = PALLYPOWER_GREATERBLESSINGDURATION / 2
							end
							if (self.PreviousAutoBuffedUnit and unit.name == self.PreviousAutoBuffedUnit.name) then
								penalty = penalty + PALLYPOWER_GREATERBLESSINGDURATION
							end
							if (penalty < classMinUnitPenalty) then
								classMinUnit = unit
								classMinUnitPenalty = penalty
							end
							local buffExpire = self:IsBuffActive(spell, spell2, unit.unitid)
							if ((not buffExpire or buffExpire < classMinExpire and buffExpire < PALLYPOWER_GREATERBLESSINGDURATION-5*60) and classMinExpire > 0) then
								classMinExpire = (buffExpire or 0)
								classMinSpell = spell
								classMaxSpell = gspell
							end
						elseif ((IsSpellInRange(HLspell, unit.unitid) ~= 1) and (not UnitIsAFK(unit.unitid)) and (IsInRaid() == false or groupCount[select(3, GetRaidRosterInfo(select(3, unit.unitid:find("(%d+)"))))] > 3)) then
							classNeedsBuff = false
						end
					end
				end
			end
			if ((classNeedsBuff or not self.opt.autobuff.waitforpeople) and classMinExpire + classMinUnitPenalty < minExpire and minExpire > 0) then
				minExpire = classMinExpire + classMinUnitPenalty
				minUnit = classMinUnit
				minSpell = classMinSpell
				maxSpell = classMaxSpell
			end
		end
		if (minExpire < 9999) then
			local button = self.autoButton
			button:SetAttribute("unit", minUnit.unitid)
			button:SetAttribute("spell", maxSpell)
			self.AutoBuffedList[minUnit.name] = now
			self.PreviousAutoBuffedUnit = minUnit
		end
	else
		self:Debug("AutoBuff(): Normal Blessing")
		local minExpire, minUnit, minSpell = 9999, nil, nil
		for _, unit in ipairs(roster) do
			local spellID, gspellID = self:GetSpellID(self:GetClassID(unit.class), unit.name)
			local spell = PallyPower.Spells[spellID]
			local spell2 = PallyPower.GSpells[spellID]
			local gspell = PallyPower.GSpells[gspellID]
			if (IsSpellInRange(spell, unit.unitid) == 1) then
				local penalty = 0
				if (self.AutoBuffedList[unit.name] and now - self.AutoBuffedList[unit.name] < 20) then
					penalty = PALLYPOWER_NORMALBLESSINGDURATION / 2
				end
				if (self.PreviousAutoBuffedUnit and unit.name == self.PreviousAutoBuffedUnit.name) then
					penalty = penalty + PALLYPOWER_NORMALBLESSINGDURATION
				end
				local buffExpire, _, buffName = self:IsBuffActive(spell, spell2, unit.unitid)
				if ((not buffExpire or buffExpire + penalty < minExpire and buffExpire < PALLYPOWER_NORMALBLESSINGDURATION) and minExpire > 0 ) then
					minExpire = (buffExpire or 0) + penalty
					minUnit = unit
					minSpell = spell
				end
			end
		end
		if (minExpire < 9999) then
			local button = self.autoButton
			button:SetAttribute("unit", minUnit.unitid)
			button:SetAttribute("spell", minSpell)
			self.AutoBuffedList[minUnit.name] = now
			self.PreviousAutoBuffedUnit = minUnit
		end
	end
end

function PallyPower:AutoBuffClear(button, mousebutton)
	if InCombatLockdown() then return end
	local button = self.autoButton
	button:SetAttribute("unit", nil)
	button:SetAttribute("spell", nil)
end

function PallyPower:SavePreset(preset)
    if not preset then return false end
	PallyPower_SavedPresets[preset] = {}
	self:Print("Saving preset: "..preset)
	for name in pairs(AllPallys) do
		self:Print("  Paladin: " .. name)
		PallyPower_SavedPresets[preset][name] = {}
	    local i
	    for i = 1, PALLYPOWER_MAXCLASSES do
 	        if not PallyPower_Assignments[name][i] then
	            PallyPower_SavedPresets[preset][name][i] = 0
		 	else
		 	    PallyPower_SavedPresets[preset][name][i] = PallyPower_Assignments[name][i]
			end
	    end
	end
	self:Print("Done.")
end

function PallyPower:LoadPreset(preset)
	if InCombatLockdown() then return false end
	if PallyPower_SavedPresets[preset] then
	    self:Print("Loading preset: "..preset)
		for name in pairs(PallyPower_SavedPresets[preset]) do
			if not PallyPower_Assignments[name] then PallyPower_Assignments[name] = {} end
			self:Print("       Paladin: " .. name)
			local i
			for i = 1, PALLYPOWER_MAXCLASSES do
				PallyPower_Assignments[name][i] = PallyPower_SavedPresets[preset][name][i]
				PallyPower:SendMessage("ASSIGN "..name.." "..i.." "..PallyPower_SavedPresets[preset][name][i])
			end
		end
		self:Print("Done.")
	else
		self:Print("No such preset name")
	end
end

function PallyPower:ApplySkin()
  local border = LSM3:Fetch("border", self.opt.border)
	local background = LSM3:Fetch("background", self.opt.skin)
	local tmp = {bgFile = background, edgeFile= border, tile=false, tileSize = 8, edgeSize = 8, insets = { left = 0, right = 0, top = 0, bottom = 0}}
	PallyPowerAura:SetBackdrop(tmp)
  PallyPowerRF:SetBackdrop(tmp)
  PallyPowerAuto:SetBackdrop(tmp)
	for cbNum = 1, PALLYPOWER_MAXCLASSES do
		local cButton = self.classButtons[cbNum]
		cButton:SetBackdrop(tmp)
		local pButtons = self.playerButtons[cbNum]
		for pbNum = 1, PALLYPOWER_MAXPERCLASS do
			local pButton = pButtons[pbNum]
			pButton:SetBackdrop(tmp)
		end
	end
end

-- button coloring: preset
function PallyPower:ApplyBackdrop(button, preset)
	button:SetBackdropColor(preset["r"], preset["g"], preset["b"], preset["t"])
end

function PallyPower:SetSeal(seal)
	self.opt.seal = seal
end

function PallyPower:SealCycle()
	if InCombatLockdown() then return false end
	shift = IsShiftKeyDown()
	if shift then
		self.opt.rf = not self.opt.rf
		PallyPower:RFAssign()
	else
    	if not self.opt.seal then
	    	self.opt.seal = 0
	    end
	    cur = self.opt.seal
	    for test=cur+1, 10 do
	    	cur = test
	    	if GetSpellInfo(PallyPower.Seals[cur]) then
				do break end
			end
	    end
	    if cur == 10 then
			cur = 0
		end
		PallyPower:SealAssign(cur)
	end
end

function PallyPower:SealCycleBackward()
	if InCombatLockdown() then return false end
	local shift = IsShiftKeyDown()
	if shift then
		self.opt.rf = not self.opt.rf
		PallyPower:RFAssign()
	else
		if not self.opt.seal then
			self.opt.seal = 0
		end
		cur = self.opt.seal
		if cur == 0 then
			cur = 10
		end
		for test=cur-1, 0, -1 do
		    cur = test
			if GetSpellInfo(PallyPower.Seals[test]) then
				do break end
			end
		end
		PallyPower:SealAssign(cur)
	end
end

function PallyPower:RFAssign()
	local name, _, icon = GetSpellInfo(PallyPower.RFSpell)
	local rfIcon = _G["PallyPowerRFIcon"]
	if self.opt.rf then
		rfIcon:SetTexture(icon)
		self.rfButton:SetAttribute("spell1", name)
	else
		rfIcon:SetTexture(nil)
		self.rfButton:SetAttribute("spell1", nil)
	end
end

function PallyPower:SealAssign(seal)
	self.opt.seal = seal
	local name, _, icon = GetSpellInfo(PallyPower.Seals[seal])
	local sealIcon = _G["PallyPowerRFIconSeal"] -- seal icon
	sealIcon:SetTexture(icon)
	self.rfButton:SetAttribute("spell2", name)
end

function PallyPower:AutoAssign()
	local shift = (IsShiftKeyDown() and PallyPowerBlessingsFrame:IsMouseOver())
	if InCombatLockdown() then return end
	local precedence
	if IsInRaid() and not (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() or shift) then
		precedence = { 6, 1, 3, 2, 4, 5, 7 }	 -- fire, devotion, concentration, retribution, shadow, frost, sanctity
	else
		precedence = { 1, 3, 2, 4, 5, 6, 7 }	 -- devotion, concentration, retribution, shadow, frost, fire, sanctity
	end
	PallyPowerBlessings_Clear()
	WisdomPallysw, MightPallys, KingsPallys,  SalvPallys, LightPallys, SancPallys = {}, {}, {}, {}, {}, {}
	PallyPower:AutoAssignBlessings(shift)
	PallyPower:AutoAssignAuras(precedence)
	PallyPower:UpdateRoster()
end

function PallyPower:CalcSkillRanks1(name)
	local wisdom, might, kings, salv, light, sanct
	if AllPallys[name][1] ~= nil then
		wisdom = tonumber(AllPallys[name][1].rank) + tonumber(AllPallys[name][1].talent)/12
	end
	if  AllPallys[name][2] ~= nil then
		might  = tonumber(AllPallys[name][2].rank) + tonumber(AllPallys[name][2].talent)/10
	end
	if AllPallys[name][3] ~= nil then
		kings  = tonumber(AllPallys[name][3].rank)
	end
	if AllPallys[name][4] ~= nil then
		salv  = tonumber(AllPallys[name][4].rank)
	end
	if AllPallys[name][5] ~= nil then
		light  = tonumber(AllPallys[name][5].rank)
	end
	if AllPallys[name][6] ~= nil then
		sanct  = tonumber(AllPallys[name][6].rank)
	end
	return wisdom, might, kings, salv, light, sanct
end

function PallyPower:AutoAssignBlessings(shift)
	local pallycount = 0
	local pallytemplate
	for name in pairs(AllPallys) do
		pallycount = pallycount + 1
	end
	if pallycount == 0 then return end
	if pallycount > 5 then pallycount = 5 end
	for name in pairs(AllPallys) do
		local wisdom, might, kings, salv, light, sanct = PallyPower:CalcSkillRanks1(name)
		if wisdom then
			tinsert(WisdomPallys, {pallyname = name, skill = wisdom})
		end
		if might then
			tinsert(MightPallys, {pallyname = name, skill = might})
		end
		if kings then
			tinsert(KingsPallys, {pallyname = name, skill = kings})
		end
		if salv then
			tinsert(SalvPallys, {pallyname = name, skill = salv})
		end
		if light then
			tinsert(LightPallys, {pallyname = name, skill = light})
		end
		if sanct then
			tinsert(SancPallys, {pallyname = name, skill = sanct})
		end
	end
	-- get template for the number of available paladins in the raid
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() or shift then
		pallytemplate = PallyPower.BattleGroundTemplates[pallycount]
	else
		if IsInRaid() then
			pallytemplate = PallyPower.RaidTemplates[pallycount]
		else
			pallytemplate = PallyPower.Templates[pallycount]
		end
	end
	-- assign based on the class templates
	PallyPower:SelectBuffsByClass(pallycount, 1, pallytemplate[1])  -- warrior
	PallyPower:SelectBuffsByClass(pallycount, 2, pallytemplate[2])  -- rogue
	PallyPower:SelectBuffsByClass(pallycount, 3, pallytemplate[3])  -- priest
	PallyPower:SelectBuffsByClass(pallycount, 4, pallytemplate[4]) 	-- druid
	PallyPower:SelectBuffsByClass(pallycount, 5, pallytemplate[5]) 	-- paladin
	PallyPower:SelectBuffsByClass(pallycount, 6, pallytemplate[6]) 	-- hunter
	PallyPower:SelectBuffsByClass(pallycount, 7, pallytemplate[7]) 	-- mage
	PallyPower:SelectBuffsByClass(pallycount, 8, pallytemplate[8]) 	-- lock
	PallyPower:SelectBuffsByClass(pallycount, 9, pallytemplate[9]) 	-- pets
end

function PallyPower:SelectBuffsByClass(pallycount, class, prioritylist)
	local pallys = {}
	for name in pairs(AllPallys) do
		if PallyPower:CanControl(name) then
			tinsert(pallys, name)
		end
	end
	local bufftable = prioritylist
	if pallycount > 0 then
		local pallycounter = 1
		for i, nextspell in pairs(bufftable) do
			if pallycounter <= pallycount then
				local buffer = PallyPower:BuffSelections(nextspell, class, pallys)
				for i, v in pairs(pallys) do
					if buffer == pallys[i] then
						tremove(pallys, i)
					end
				end
				if buffer ~= "" then pallycounter = pallycounter + 1 end
			end
		end
	end
end

function PallyPower:BuffSelections(buff, class, pallys)
	local t = {}
	if buff == 1 then t = WisdomPallys end
	if buff == 2 then t = MightPallys end
	if buff == 3 then t = KingsPallys end
	if buff == 4 then t = SalvPallys end
	if buff == 5 then t = LightPallys end
	if buff == 6 then t = SancPallys end
	local Buffer = ""
	local BufferSkill = 0
	local pclass
	tsort(t, function(a, b) return a.skill > b.skill end)
	for i, v in pairs(t) do
		if PallyPower:PallyAvailable(v.pallyname, pallys) and v.skill > 0 then
			Buffer = v.pallyname
			BufferSkill = v.skill
			break
		end
	end
	if Buffer ~= "" then
		if (IsInRaid()) and (buff > 2) then
			if Buffer == PallyPower.player and (not IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) then
				SalvPallys = {}; tinsert(SalvPallys, {pallyname = Buffer, skill = BufferSkill})
				for pclass = 1, PALLYPOWER_MAXCLASSES do
					PallyPower_Assignments[Buffer][pclass] = buff
				end
				PallyPower:SendMessage("MASSIGN "..Buffer.." "..buff)
			else
				if buff == 3 then KingsPallys = {}; tinsert(KingsPallys, {pallyname = Buffer, skill = BufferSkill}) end
				if buff == 5 then LightPallys = {}; tinsert(LightPallys, {pallyname = Buffer, skill = BufferSkill}) end
				if buff == 6 then SancPallys = {}; tinsert(SancPallys, {pallyname = Buffer, skill = BufferSkill}) end
				for pclass = 1, PALLYPOWER_MAXCLASSES do
					PallyPower_Assignments[Buffer][pclass] = buff
				end
				PallyPower:SendMessage("MASSIGN "..Buffer.." "..buff)
			end
			-----------------------------------------------------------------------------------------------------------------
			-- Warriors
			-----------------------------------------------------------------------------------------------------------------
			if (buff == PallyPower.opt.mainTankGSpellsW) and (class == 1) then
				for i = 1, MAX_RAID_MEMBERS do
					local playerName, _, _, _, playerClass = GetRaidRosterInfo(i)
					if playerName and PallyPower:CheckRaidTanks(playerName) and (class == PallyPower:GetClassID(string.upper(playerClass)))  then
						SetNormalBlessings(Buffer, class, playerName, PallyPower.opt.mainTankSpellsW)
					end
				end
			end
			if (buff == PallyPower.opt.mainAssistGSpellsW) and (class == 1) then
				for i = 1, MAX_RAID_MEMBERS do
					local playerName, _, _, _, playerClass = GetRaidRosterInfo(i)
					if playerName and PallyPower:CheckRaidTanks(playerName) and (class == PallyPower:GetClassID(string.upper(playerClass)))  then
						SetNormalBlessings(Buffer, class, playerName, PallyPower.opt.mainAssistSpellsW)
					end
				end
			end
			-----------------------------------------------------------------------------------------------------------------
			-- Druids and Paladins
			-----------------------------------------------------------------------------------------------------------------
			if (buff == PallyPower.opt.mainTankGSpellsDP) and (class == 4 or class == 5) then
				for i = 1, MAX_RAID_MEMBERS do
					local playerName, _, _, _, playerClass = GetRaidRosterInfo(i)
					if playerName and PallyPower:CheckRaidTanks(playerName) and (class == PallyPower:GetClassID(string.upper(playerClass)))  then
						SetNormalBlessings(Buffer, class, playerName, PallyPower.opt.mainTankSpellsDP)
					end
				end
			end
			if (buff == PallyPower.opt.mainAssistGSpellsDP) and (class == 4 or class == 5) then
				for i = 1, MAX_RAID_MEMBERS do
					local playerName, _, _, _, playerClass = GetRaidRosterInfo(i)
					if playerName and PallyPower:CheckRaidTanks(playerName) and (class == PallyPower:GetClassID(string.upper(playerClass)))  then
						SetNormalBlessings(Buffer, class, playerName, PallyPower.opt.mainAssistSpellsDP)
					end
				end
			end
			-----------------------------------------------------------------------------------------------------------------
		else
			PallyPower_Assignments[Buffer][class] = buff
			PallyPower:SendMessage("ASSIGN "..Buffer.." "..class.." "..buff)
		end
	else end
	return Buffer
end

function PallyPower:PallyAvailable(pally, pallys)
	local available = false
	for i, v in pairs(pallys) do
		if pallys[i] == pally then available = true end
	end
	return available
end

-- Aura assignment support follows...
function PallyPowerAuraButton_OnClick(btn, mouseBtn)
	if InCombatLockdown() then return false end
	local _, _, pnum = sfind(btn:GetName(), "PallyPowerBlessingsFramePlayer(.+)Aura1")
	pnum = pnum + 0
	local pname = getglobal("PallyPowerBlessingsFramePlayer"..pnum.."Name"):GetText()
	if not PallyPower:CanControl(pname) then return false end
	if (mouseBtn == "RightButton") then
		PallyPower_AuraAssignments[pname] = 0
		PallyPower:SendMessage("AASSIGN "..pname.." 0")
	else
		PallyPower:PerformAuraCycle(pname)
	end
end

function PallyPowerAuraButton_OnMouseWheel(btn, arg1)
	if InCombatLockdown() then return false end
	local _, _, pnum = sfind(btn:GetName(), "PallyPowerBlessingsFramePlayer(.+)Aura1")
	pnum = pnum + 0
	local pname = getglobal("PallyPowerBlessingsFramePlayer"..pnum.."Name"):GetText()
	if not PallyPower:CanControl(pname) then return false end
	if (arg1==-1) then  --mouse wheel down
		PallyPower:PerformAuraCycle(pname)
	else
		PallyPower:PerformAuraCycleBackwards(pname)
	end
end

function PallyPower:HasAura(name, test)
	if (not AllPallys[name].AuraInfo[test]) or (AllPallys[name].AuraInfo[test].rank == 0) then
		return false
	end
	return true
end

function PallyPower:PerformAuraCycle(name, skipzero)
	if not PallyPower_AuraAssignments[name] then
		PallyPower_AuraAssignments[name] = 0
	end
	local cur = PallyPower_AuraAssignments[name]
	for test = cur+1, PALLYPOWER_MAXAURAS do
		if PallyPower:HasAura(name, test) then
			cur = test
			do break end
		end
	end
	if ( cur == PallyPower_AuraAssignments[name] ) then
		if skipzero and PallyPower:HasAura(name, 1) then
			cur = 1
		else
			cur = 0
		end
	end
	PallyPower_AuraAssignments[name] = cur
	PallyPower:SendMessage("AASSIGN "..name.." "..cur)
end

function PallyPower:PerformAuraCycleBackwards(name, skipzero)
	if not PallyPower_AuraAssignments[name] then
		PallyPower_AuraAssignments[name] = 0
	end
	local cur = PallyPower_AuraAssignments[name] - 1
	if (cur < 0) or (skipzero and (cur < 1)) then
		cur = PALLYPOWER_MAXAURAS
	end
	for test = cur, 0, -1 do
		if PallyPower:HasAura(name, test) or (test == 0 and not skipzero) then
			PallyPower_AuraAssignments[name] = test
			PallyPower:SendMessage("AASSIGN "..name.." "..test)
			do break end
		end
	end
end

function PallyPower:IsAuraActive(aura)
  local bFound = false
	local bSelfCast = false
	if ( aura and aura > 0 ) then
		local spell = PallyPower.Auras[aura]
		local j = 1
		local buffName, _, _, _, _, buffExpire, castBy = UnitBuff("player", j)
		while buffExpire do
			if buffName == spell then
				bFound = true
				bSelfCast = (castBy == "player")
				do break end
			end
			j = j + 1
			buffName, _, _, _, _, buffExpire, castBy = UnitBuff("player", j)
		end
	end
	return bFound, bSelfCast
end

function PallyPower:UpdateAuraButton(aura)
	local pallys = {}
	local auraBtn = _G["PallyPowerAura"]
	local auraIcon = _G["PallyPowerAuraIcon"]
	if ( aura and aura > 0 ) then
		for name in pairs(AllPallys) do
			if (name ~= self.player) and (aura == PallyPower_AuraAssignments[name]) then
				tinsert(pallys, name)
			end
		end
		local name, _, icon = GetSpellInfo(PallyPower.Auras[aura])
		if (not InCombatLockdown()) then
			auraIcon:SetTexture(icon)
			auraBtn:SetAttribute("spell", name)
		end
	else
		if (not InCombatLockdown()) then
			auraIcon:SetTexture(nil)
			auraBtn:SetAttribute("spell", "")
		end
	end
	-- only support two lines of text, so only deal with the first two players in the list...
	local player1 = _G["PallyPowerAuraPlayer1"]
	if pallys[1] then
		local shortpally1 = Ambiguate(pallys[1], "short")
		player1:SetText(shortpally1)
		player1:SetTextColor(1.0, 1.0, 1.0)
	else
		player1:SetText("")
	end
	local player2 = _G["PallyPowerAuraPlayer2"]
	if pallys[2] then
		local shortpally2 = Ambiguate(pallys[2], "short")
		player2:SetText(shortpally2)
		player2:SetTextColor(1.0, 1.0, 1.0)
	else
		player2:SetText("")
	end
	local btnColour = self.opt.cBuffGood
	local active, selfCast = self:IsAuraActive(aura)
	if ( active == false ) then
		btnColour = self.opt.cBuffNeedAll
	elseif ( selfCast == false ) then
		btnColour = self.opt.cBuffNeedSome
	end
	self:ApplyBackdrop(auraBtn, btnColour)
end

function PallyPower:AutoAssignAuras(precedence)
	local pallys = {}
	for i = 1, 8 do
		pallys[("subgroup%d"):format(i)] = {}
	end
	for name in pairs(AllPallys) do
		if AllPallys[name].subgroup then
			local subgroup = "subgroup"..AllPallys[name].subgroup
			if PallyPower:CanControl(name) then
				tinsert(pallys[subgroup], name)
			end
		end
	end
	for _, subgroup in pairs(pallys) do
		for _, aura in pairs(precedence) do
			local assignee = ""
			local testRank = 0
			local testTalent = 0
			for _, pally in pairs(subgroup) do
				if PallyPower:HasAura(pally, aura) and (AllPallys[pally].AuraInfo[aura].rank >= testRank) then
					testRank = AllPallys[pally].AuraInfo[aura].rank
					if AllPallys[pally].AuraInfo[aura].talent >= testTalent then
						testTalent = AllPallys[pally].AuraInfo[aura].talent
						assignee = pally
					end
				end
			end
			if assignee ~= "" then
				for i, name in pairs(subgroup) do
					if assignee == name then
						tremove(subgroup, i)
						PallyPower_AuraAssignments[assignee] = aura
						PallyPower:SendMessage("AASSIGN "..assignee.." "..aura)
					end
				end
			end
		end
	end
end
