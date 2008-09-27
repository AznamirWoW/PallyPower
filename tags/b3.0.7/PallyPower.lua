PallyPower = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0","AceDB-2.0","AceEvent-2.0","AceDebug-2.0", "AceComm-2.0")

local dewdrop = AceLibrary("Dewdrop-2.0")
local RL = AceLibrary("Roster-2.1")
local L = AceLibrary("AceLocale-2.2"):new("PallyPower")

local classlist, classes = {}, {}
LastCast = {}
PallyPower_Assignments = {}
PallyPower_NormalAssignments = {}

PallyPower_SavedPresets = {}

AllPallys = {}

ChatControl = {}

local initalized = false
PP_Symbols = 0
PP_IsPally = false

function PallyPower:OnInitialize()
	self:RegisterDB("PallyPowerDB")
	self:RegisterChatCommand({"/pp"}, self.options)
	self:RegisterDefaults("profile", PALLYPOWER_DEFAULT_VALUES)
	self.player = UnitName("player")
	self.opt = self.db.profile
	self:ScanInventory()
	self:CreateLayout()
	dewdrop:Register(PallyPowerConfigFrame, "children",
		function(level, value) dewdrop:FeedAceOptionsTable(self.options) end,
		"dontHook", true
	)

	self.AutoBuffedList = {}
	self.PreviousAutoBuffedUnit = nil
end

function PallyPower:OnEnable()
	-- events
	self:ScanSpells()
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("SPELLS_CHANGED")
	self:RegisterBucketEvent("RosterLib_RosterUpdated", 1, "UpdateRoster")
	self:ScheduleRepeatingEvent("PallyPowerInventoryScan", self.InventoryScan, 60, self)
	self:UpdateRoster()
	self:BindKeys()
end

function PallyPower:BindKeys()
	-- First unbind stuff because clearing one removes both.
	if not self.opt.autobuff.autokey1 then
		self.opt.autobuff.autokey1 = false
	end
	if not self.opt.autobuff.autokey2 then
		self.opt.autobuff.autokey2 = false
	end
	if not self.opt.autobuff.autokey1 or not self.opt.autobuff.autokey2 then
		self:UnbindKeys()
	end
	if self.opt.autobuff.autokey1 then
		SetOverrideBindingClick(self.autoButton, false, self.opt.autobuff.autokey1, "PallyPowerAuto", "Hotkey1")
	end
	if self.opt.autobuff.autokey2 then
		SetOverrideBindingClick(self.autoButton, false, self.opt.autobuff.autokey2, "PallyPowerAuto", "Hotkey2")
	end
end

function PallyPower:OnDisable()
	-- events
	for i = 1, PALLYPOWER_MAXCLASSES do
		classlist[i] = 0
		classes[i] = {}
	end
	self:UpdateLayout()
	self:UnbindKeys()
end

function PallyPower:UnbindKeys()
	ClearOverrideBindings(self.autoButton)
end

--
--  Config Window functionality
--

function PallyPowerConfig_Clear()
	if InCombatLockdown() then return false end
	PallyPower:ClearAssignments(UnitName("player"))
	if PallyPower:CheckRaidLeader(UnitName("player")) then
		PallyPower:SendMessage("CLEAR")
	end
end

function PallyPowerConfig_Options()

end

function PallyPower:Reset()
	local h = _G["PallyPowerFrame"]
	h:ClearAllPoints()
	h:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	local c = _G["PallyPowerConfigFrame"]
	c:ClearAllPoints()
    c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
	self:UpdateLayout()
end

function PallyPowerConfig_Refresh()
	AllPallys = {}
	PallyPower:ScanSpells()
	PallyPower:ScanInventory()
	PallyPower:SendSelf()
	PallyPower:SendMessage("REQ")
	PallyPower:UpdateLayout()
end

function PallyPowerConfig_Toggle(msg)
	if PallyPowerConfigFrame:IsVisible() then
		PallyPowerConfigFrame:Hide()
	else
		local c = _G["PallyPowerConfigFrame"]
		c:ClearAllPoints()
    	c:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
		PallyPowerConfigFrame:Show()
	end
end

function PallyPowerConfig_ShowCredits()
	GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
	GameTooltip:SetText(PallyPower_Credits1, 1, 1, 1)
--   GameTooltip:AddLine(PallyPower_Credits2, 1, 1, 1)
--   GameTooltip:AddLine(PallyPower_Credits3)
--   GameTooltip:AddLine(PallyPower_Credits4, 0, 1 ,0)
--   GameTooltip:AddLine(PallyPower_Credits5)
	GameTooltip:Show()
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
		local tempoptions = {
			type = "group",
			args = {
				close = {
					name = "Close",
					desc = "Closes the menu.",
					order = 10,
					type = "execute",
					func = function() dewdrop:Close() end
				}
			}
		}
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
			local blessings = {["0"] = string.format("%s%s%s", pre, "(none)", suf)}
			for index, blessing in ipairs(PallyPower.Spells) do
				if PallyPower:CanBuff(pally, index) then
					if PallyPower:NeedsBuff(class, index, pname) then
						blessings[tostring(index)] = string.format("%s%s%s", pre, blessing, suf)
					end
				end
			end
			tempoptions.args[pally] = {
				name = string.format("%s%s%s", pre, pally, suf),
				type = "text",
				desc = pally,
				order = 5,
				get = function() return GetNormalBlessings(pally, class, pname) end,
				set = function(value) if control then SetNormalBlessings(pally, class, pname, value + 0) end end,
				validate = blessings,

			}
		end
		dewdrop:Register(btn, "children", 
			function(level, value) dewdrop:FeedAceOptionsTable(tempoptions) end,
			"dontHook", true,
			'point', "TOPLEFT",
			'relativePoint', "BOTTOMLEFT"
		)
		dewdrop:Open(btn)
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
	local _, _, class, pnum = string.find(btn:GetName(), "PallyPowerConfigFrameClassGroup(.+)PlayerButton(.+)")
	local pname = getglobal("PallyPowerConfigFrameClassGroup"..class.."PlayerButton"..pnum.."Text"):GetText()
	class = tonumber(class)
	PallyPowerGrid_NormalBlessingMenu(btn, mouseBtn, pname, class)
end

function PallyPowerPlayerButton_OnMouseWheel(btn, arg1)
	if InCombatLockdown() then return false end
	local _, _, class, pnum = string.find(btn:GetName(), "PallyPowerConfigFrameClassGroup(.+)PlayerButton(.+)")
	local pname = getglobal("PallyPowerConfigFrameClassGroup"..class.."PlayerButton"..pnum.."Text"):GetText()
	class = tonumber(class)

	PallyPower:PerformPlayerCycle(arg1, pname, class)
end

function PallyPowerGridButton_OnClick(btn, mouseBtn)
	if InCombatLockdown() then return false end
	_, _, pnum, class = string.find(btn:GetName(), "PallyPowerConfigFramePlayer(.+)Class(.+)")
	pnum = pnum + 0
	class = class + 0
	pname = getglobal("PallyPowerConfigFramePlayer"..pnum.."Name"):GetText()
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
	_,_,pnum,class = string.find(btn:GetName(), "PallyPowerConfigFramePlayer(.+)Class(.+)")
	pnum = pnum + 0
	class = class + 0
	pname = getglobal("PallyPowerConfigFramePlayer"..pnum.."Name"):GetText()
	if not PallyPower:CanControl(pname) then return false end

	if (arg1==-1) then  --mouse wheel down
		PallyPower:PerformCycle(pname, class)
	else
		PallyPower:PerformCycleBackwards(pname, class)
	end
end

function PallyPowerConfigFrame_MouseUp()
	if ( PallyPowerConfigFrame.isMoving ) then
		PallyPowerConfigFrame:StopMovingOrSizing()
		PallyPowerConfigFrame.isMoving = false
	end
end

function PallyPowerConfigFrame_MouseDown(arg1)
	if ( ( ( not PallyPowerConfigFrame.isLocked ) or ( PallyPowerConfigFrame.isLocked == 0 ) ) and ( arg1 == "LeftButton" ) ) then
		PallyPowerConfigFrame:StartMoving()
		PallyPowerConfigFrame.isMoving = true
	end
end

local point, relativeTo, relativePoint, xOfs, yOfs, movingPlayerFrame
function PlayerButton_DragStart(frame)
	movingPlayerFrame = frame
	point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
	frame:SetMovable(true)
	frame:StartMoving()
end

function PlayerButton_DragStop(frame)
	if movingPlayerFrame then
		frame:StopMovingOrSizing()
		for i = 1, PALLYPOWER_MAXCLASSES do
		    if MouseIsOver(getglobal("PallyPowerConfigFrameClassGroup"..i.."ClassButton")) then
			local _, _, pclass, pnum = string.find(movingPlayerFrame:GetName(), "PallyPowerConfigFrameClassGroup(.+)PlayerButton(.+)")
			pclass, pnum = tonumber(pclass), tonumber(pnum)
			local unit = classes[pclass][pnum]
			PallyPower:AssignPlayerAsClass(unit.name, pclass, i)
		    end
		end
		frame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
		frame:SetMovable(false)
		movingPlayerFrame = nil
	end
end

function PallyPowerConfigGrid_Update()
	if not initalized then PallyPower:ScanSpells() end
	if PallyPowerConfigFrame:IsVisible() then
		local i = 1
		local numPallys = 0
		local numMaxClass = 0
		local name, skills
		for i = 1, PALLYPOWER_MAXCLASSES do
			local fname = "PallyPowerConfigFrameClassGroup"..i
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
					getglobal(pbnt.."Text"):SetText(unit.name)
					local normal, greater = PallyPower:GetSpellID(i, unit.name)
					local icon
					if normal ~= greater and movingPlayerFrame ~= getglobal(pbnt) then
						if normal ~= greater then
							getglobal(pbnt.."Icon"):SetTexture(PallyPower.NormalBlessingIcons[normal])
						else
							--getglobal("PallyPowerConfigFrameClassGroup"..i.."PlayerButton"..j.."Icon"):SetTexture(PallyPower.BlessingIcons[normal])
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
		PallyPowerConfigFrame:SetScale(PallyPower.opt.configscale)
		for name in pairs(AllPallys) do
			local fname = "PallyPowerConfigFramePlayer" .. i

			local SkillInfo = AllPallys[name]
			local BuffInfo = PallyPower_Assignments[name]
			local NormalBuffInfo = PallyPower_NormalAssignments[name]
			getglobal(fname .. "Name"):SetText(name)

			if PallyPower:CanControl(name) then
				getglobal(fname.."Name"):SetTextColor(1,1,1)
			else
				if PallyPower:CheckRaidLeader(name) then
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
					if SkillInfo[id].talent + 0 > 0 then 
					txt = txt.. "+" .. SkillInfo[id].talent
					end
					getglobal(fname.."Skill"..id):SetText(txt)
				else
					getglobal(fname.."Icon"..id):Hide()
					getglobal(fname.."Skill"..id):Hide()
				end
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
		PallyPowerConfigFrame:SetHeight(14 + 24 + 56 + (numPallys * 56) + 22 + 13 * numMaxClass)
		getglobal("PallyPowerConfigFramePlayer1"):SetPoint("TOPLEFT", 8, -80 - 13 * numMaxClass)
		for i = 1, PALLYPOWER_MAXCLASSES do
			getglobal("PallyPowerConfigFrameClassGroup" .. i .. "Line"):SetHeight(56 + 13 * numMaxClass)
		end
		for i = 1, PALLYPOWER_MAXPERCLASS do
			local fname = "PallyPowerConfigFramePlayer" .. i
			if i <= numPallys then
				getglobal(fname):Show()
			else
				getglobal(fname):Hide()
			end
		end
		getglobal("PallyPowerConfigFrameFreeAssign"):SetChecked(PallyPower.opt.freeassign)
	end
end

--
-- Main functionality
--

function PallyPower:Report(type)
	if self:GetNumUnits() > 0 then
	if not type then
		if GetNumRaidMembers() > 0 then
			type = "RAID"
		else
			type = "PARTY"
		end
	end
		if PallyPower:CheckRaidLeader(self.player) then
			SendChatMessage(PALLYPOWER_ASSIGNMENTS1, type)
			local list = {}
			for name in pairs(AllPallys) do
				local blessings
				for i = 1, 4 do
					list[i] = 0
				end
				for id = 1, PALLYPOWER_MAXCLASSES do
					local bid = PallyPower_Assignments[name][id]
					if bid and bid > 0 then
						list[bid] = list[bid] + 1
					end
				end
				for id = 1, 4 do
					if (list[id] > 0) then
						if (blessings) then
							blessings = blessings .. ", "
						else
							blessings = ""
						end
						local _,_, spell = string.find(PallyPower.Spells[id], PallyPower_BlessingNameSearch)
						blessings = blessings .. spell
					end
				end
				if not (blessings) then
					blessings = "Nothing"
				end
				SendChatMessage(name ..": ".. blessings, type)
			end
			SendChatMessage(PALLYPOWER_ASSIGNMENTS2, type)
		else
			self:Print(ERR_NOT_LEADER)
		end
	else
		self:Print(ERR_NOT_IN_RAID)
	end
end

function PallyPower:PerformCycle(name, class, skipzero)
	shift = IsShiftKeyDown()

	if shift then class = 4 end

	if not PallyPower_Assignments[name] then
		PallyPower_Assignments[name] = { }
	end

	if not PallyPower_Assignments[name][class] then
		cur=0
	else
		cur=PallyPower_Assignments[name][class]
	end

	PallyPower_Assignments[name][class] = 0

	for test = cur+1, 5 do
		if PallyPower:CanBuff(name, test) and (PallyPower:NeedsBuff(class, test) or shift) then
		cur = test
			do break end
		end
	end

	if cur == 5 then
		if skipzero then
			cur = 1
		else
			cur = 0 
		end
	end

	if shift then
		for test = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[name][test] = cur
		end
		PallyPower:SendMessage("MASSIGN "..name.." "..cur)
	else
		PallyPower_Assignments[name][class] = cur
		PallyPower:SendMessage("ASSIGN "..name.." "..class.." "..cur)
	end
end

function PallyPower:PerformCycleBackwards(name, class, skipzero)
	shift=IsShiftKeyDown()

	if shift then class=4 end

	if not PallyPower_Assignments[name] then
		PallyPower_Assignments[name] = { }
	end

	if not PallyPower_Assignments[name][class] then
		cur=5
	else
		cur=PallyPower_Assignments[name][class]
		if cur == 0 or skipzero and cur == 1 then cur = 5 end
	end

	PallyPower_Assignments[name][class] = 0

	for test = cur-1, 0, -1 do
		cur = test
		if PallyPower:CanBuff(name, test) and (PallyPower:NeedsBuff(class, test) or shift) then
			do break end
		end
	end

	if shift then
		for test = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[name][test] = cur
		end
		PallyPower:SendMessage("MASSIGN "..name.." "..cur)
	else
		PallyPower_Assignments[name][class] = cur
		PallyPower:SendMessage("ASSIGN "..name.." "..class.." "..cur)
	end
end

function PallyPower:PerformPlayerCycle(arg1, pname, class)
	local blessing = 0
	local playername = PallyPower.player
	if PallyPower_NormalAssignments[playername] and PallyPower_NormalAssignments[playername][class] and PallyPower_NormalAssignments[playername][class][pname] then
		blessing = PallyPower_NormalAssignments[playername][class][pname]
	end

	local test = (blessing - arg1) % 5
	while not (PallyPower:CanBuff(playername, test) and PallyPower:NeedsBuff(class, test, pname)) and test > 0 do
		test = (test - arg1) % 5
		if test == blessing then
			test = 0
			break
		end
	end

	SetNormalBlessings(playername, class, pname, test)
end

function PallyPower:AssignPlayerAsClass(pname, pclass, tclass)
	local greater, target, targetsorted, freepallies =  {}, {}, {}, {}
	-- Find blessings we want
	for pally, classes in pairs(PallyPower_Assignments) do
		if AllPallys[pally] and classes[tclass] and classes[tclass] > 0 then
			target[classes[tclass]] = pally
			table.insert(targetsorted, classes[tclass])
		end
	end
	-- Sort blessings because we want to look at might > wisdom > the rest
	table.sort(targetsorted, function(a,b) return a == 2 or a == 1 and b ~= 2 end)
	-- Find greater blessings we have
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
	-- Find blessings we will have to assign
	for index, blessing in pairs(targetsorted) do
		if greater[blessing] then
			local pally = greater[blessing]
			-- Use greater blessing if already assigned
			if PallyPower_NormalAssignments[pally] and 
			   PallyPower_NormalAssignments[pally][pclass] and 
			   PallyPower_NormalAssignments[pally][pclass][pname] then
				SetNormalBlessings(pally, pclass, pname, 0)
			end
		else
			-- We got a blessing we want, find best paladin (greedy approach)
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
	if test==5 then
		return true
	end

	if (not AllPallys[name][test]) or (AllPallys[name][test].rank == 0) then
		return false
	end
	return true
end

function PallyPower:NeedsBuff(class, test, playerName)
	if test==5 or test==0 then
		return true
	end

	if self.opt.smartbuffs then
		-- no wisdom for warriors and rogues
		if (class == 1 or class==2) and test == 1 then
			return false
		end
		-- no salv for warriors except normal blessings
		--if not playerName and class == 1 and test == 3 then
		--	return false
		--end
		-- no might for casters
		if (class == 3 or class == 7 or class == 8) and test == 2 then
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
	self:Debug("Scan Spells -- begin")
	_, class=UnitClass("player")
	if (class == "PALADIN") then
		local RankInfo = {}
		for i = 1, 4 do -- find max spell ranks
			local spellName, spellRank = GetSpellInfo(PallyPower.GSpells[i])
			if not spellName then -- fallback to lower blessings
				spellName, spellRank = GetSpellInfo(PallyPower.Spells[i])
			end
			if not spellRank or spellRank == "" then -- spells without ranks
				spellRank = PallyPower_Rank1		 -- BoK and BoS
			end
			local rank = select(3, string.find(spellRank, "(%d+)"))
			local talent = 0
			rank = tonumber(rank)
			if spellName then
				RankInfo[i] = {}
				RankInfo[i].rank = rank
				if i == 1 then
					talent = talent + select(5, GetTalentInfo(1, 10))
				elseif i == 2 then
			    	talent = talent + select(5, GetTalentInfo(3, 5))
			    elseif i == 3 then
			    	talent = talent + select(5, GetTalentInfo(2, 2))
				end

				RankInfo[i].talent = talent
			end
		end
		AllPallys[self.player] = RankInfo
		PP_IsPally = true
	else
		PP_IsPally = false
		initalized=true
	end
		self:Debug("Scan Spells -- end")
end

function PallyPower:ScanInventory()
	self:Debug("Scan Inventory -- begin")
	if not PP_IsPally then return end

	PP_Symbols = GetItemCount(21177)
	AllPallys[self.player].symbols = PP_Symbols
	self:Debug("Scan Inventory -- end")
end

function PallyPower:InventoryScan()
	self:ScanInventory()
	if self:GetNumUnits() > 0 and PP_IsPally then
		self:SendMessage("SYMCOUNT " .. PP_Symbols)
	end
end

function PallyPower:SendSelf()
	self:Debug("Send self -- begin")
	if not initalized then PallyPower:ScanSpells() end
	if not AllPallys[self.player] then return end
--    local name = UnitName("player")
	local s

	local SkillInfo = AllPallys[self.player]
	s = ""
	for i = 1, 4 do
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

	local AssignList = {}
	local inraid = GetNumRaidMembers() > 0
	if PallyPower_NormalAssignments[self.player] then
		for class_id, tnames in pairs(PallyPower_NormalAssignments[self.player]) do
			for tname, blessing_id in pairs(tnames) do
				table.insert(AssignList, string.format("%s %s %s %s", self.player, class_id, tname, blessing_id))
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
	self:Debug("Send self -- end")
end

function PallyPower:SendMessage(msg)
	self:Debug("Sending message")
	local type
	if GetNumRaidMembers() == 0 then
		type = "PARTY"
	else
		type = "RAID"
	end
	SendAddonMessage(PallyPower.commPrefix, msg, type, self.player)
end

function PallyPower:SPELLS_CHANGED()
	self:ScanSpells()
end

function PallyPower:CHAT_MSG_ADDON(prefix, message, distribution, sender)
	self:Debug("CHAT_MSG_ADDON event")
	if prefix == PallyPower.commPrefix and (distribution == "PARTY" or distribution == "RAID") then
		if not ChatControl[sender] then
			ChatControl[sender]={}
			ChatControl[sender].time=0
		end
		if message == "REQ" then
			if (GetTime() - ChatControl[sender].time) < 1 then 
				return
			else
				ChatControl[sender].time = GetTime()
			end
		end
		self:ParseMessage(sender, message)
	end
end

function PallyPower:CHAT_MSG_SYSTEM()
	self:Debug("CHAT_MSG_SYSTEM event")
	if string.find(arg1, ERR_RAID_YOU_JOINED) then
		self:SendSelf()
		self:SendMessage("REQ")
	end
end

function PallyPower:PLAYER_REGEN_ENABLED()
	if PP_IsPally then self:UpdateLayout() end
end

function PallyPower:CanControl(name)
	return (IsPartyLeader() or IsRaidLeader() or IsRaidOfficer() or (name==self.player) or (AllPallys[name] and AllPallys[name].freeassign == true))
end

function PallyPower:CheckRaidLeader(nick)
	local unit = RL:GetUnitObjectFromName(nick)
	return unit and unit.rank >= 1
end

function PallyPower:ClearAssignments(sender)
	local leader = self:CheckRaidLeader(sender)
	for name, skills in pairs(PallyPower_Assignments) do
		if leader or name == sender then
			--self:Print("Clearing: %s", name)
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
end

function PallyPower:ParseMessage(sender, msg)
--    self:Print("Received from: %s, message: %s", sender, msg)
	if sender == self.player then return end

	local leader = self:CheckRaidLeader(sender)
	if msg == "REQ" then
		self:SendSelf()
	end

	if string.find(msg, "^SELF") then
		PallyPower_NormalAssignments[sender] = {}
		PallyPower_Assignments[sender] = { }
		AllPallys[sender] = { }
		_, _, numbers, assign = string.find(msg, "SELF ([0-9n]*)@([0-9n]*)")
		for i = 1, 6 do
			rank = string.sub(numbers, (i - 1) * 2 + 1, (i - 1) * 2 + 1)
			talent = string.sub(numbers, (i - 1) * 2 + 2, (i - 1) * 2 + 2)
			if rank ~= "n" then
				AllPallys[sender][i] = { }
				AllPallys[sender][i].rank = tonumber(rank)
				AllPallys[sender][i].talent = tonumber(talent)
			end
		end
		if assign then
			for i = 1, PALLYPOWER_MAXCLASSES do
				tmp =string.sub(assign, i, i)
				if tmp == "n" or tmp == "" then tmp = 0 end
				PallyPower_Assignments[sender][i] = tmp + 0
			end
		end
	end

	if string.find(msg, "^ASSIGN") then
		_, _, name, class, skill = string.find(msg, "^ASSIGN (.*) (.*) (.*)")
		if name ~= sender and not (leader or PallyPower.opt.freeassign) then return false end
		if not PallyPower_Assignments[name] then PallyPower_Assignments[name] = {} end
		class = class + 0
		skill = skill + 0
		PallyPower_Assignments[name][class] = skill
	end

	if string.find(msg, "^NASSIGN") then
		for pname, class, tname, skill in string.gmatch(string.sub(msg, 9), "([^@]*) ([^@]*) ([^@]*) ([^@]*)") do
			if pname ~= sender and not (leader or PallyPower.opt.freeassign) then return end
			if not PallyPower_NormalAssignments[pname] then PallyPower_NormalAssignments[pname] = {} end
			class = class + 0
			if not PallyPower_NormalAssignments[pname][class] then PallyPower_NormalAssignments[pname][class] = {} end
			skill = skill + 0
			if skill == 0 then skill = nil end
			PallyPower_NormalAssignments[pname][class][tname] = skill
		end
	end

	if string.find(msg, "^MASSIGN") then
		_, _, name, skill = string.find(msg, "^MASSIGN (.*) (.*)")
		if name ~= sender and not (leader or PallyPower.opt.freeassign) then return false end
		if not PallyPower_Assignments[name] then PallyPower_Assignments[name] = {} end
		skill = skill + 0
		for i = 1, PALLYPOWER_MAXCLASSES do
			PallyPower_Assignments[name][i] = skill
		end
	end

	if string.find(msg, "^SYMCOUNT") then
		_, _, count = string.find(msg, "^SYMCOUNT ([0-9]*)")
		if AllPallys[sender] then
			AllPallys[sender].symbols = count
		else
			self:SendMessage("REQ")
		end
	end

	if string.find(msg, "^CLEAR") then
		if leader then
			self:ClearAssignments(sender)
		end
	end

	if msg == "FREEASSIGN YES" and AllPallys[sender] then
		AllPallys[sender].freeassign = true
	end
	if msg == "FREEASSIGN NO" and AllPallys[sender] then
		AllPallys[sender].freeassign = false
	end
end

function PallyPower:FormatTime(time)
	if not time or time < 0 or time == 9999 then
		return ""
	end
	mins = floor(time / 60)
	secs = time - (mins * 60)
	return string.format("%d:%02d", mins, secs)
end

function PallyPower:GetClassID(class)
	for id, name in pairs(self.ClassID) do
		if (name==class) then
			return id
		end
	end
	return -1
end

function PallyPower:ShouldIDisplay()
	if GetNumRaidMembers() > 0 then
		return true
	end
	if GetNumPartyMembers() > 0 and self.opt.ShowInParty then
		return true
	end
	return false
end

function PallyPower:GetNumUnits()
	if GetNumRaidMembers() > 0 then
		return GetNumRaidMembers()
	end
	if GetNumPartyMembers() > 0 and self.opt.ShowInParty or self.opt.ShowWhenSingle then
		return GetNumPartyMembers() + 1
	end
	return 0
end

function PallyPower:UpdateRoster()
	-- unregister events
	self:Debug("Update Roster")
	self:CancelScheduledEvent("PallyPowerUpdateButtons")

	local num = self:GetNumUnits()

	for i = 1, PALLYPOWER_MAXCLASSES do
		classlist[i] = 0
		classes[i] = {}
	end

	if num > 0 then -- and PP_IsPally then
		for unit in RL:IterateRoster(true) do
			for i = 1, PALLYPOWER_MAXCLASSES do
				if unit.class == self.ClassID[i] then
					local tmp = unit
					tmp.visible = false
					tmp.hasbuff = false
					tmp.specialbuff = false
					tmp.dead = false
					classlist[i] = classlist[i] + 1
					table.insert(classes[i], tmp)
				end
			end
		end
	end

	self:UpdateLayout()

	if num > 0 and PP_IsPally then
		-- register events
		self:ScheduleRepeatingEvent("PallyPowerUpdateButtons", self.ButtonsUpdate, 2.0, self)
	end
	self:Debug("Update Roster - end")
end

function PallyPower:ScanClass(classID)
	--    self:Print("Scanning class: %s -- begin", classID)

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
	self:Debug("Create Layout -- begin")

	local p = _G["PallyPowerFrame"]
	self.Header = p

	self.classButtons = {}
	self.playerButtons = {}

	for cbNum = 1, PALLYPOWER_MAXCLASSES do
	-- create class buttons
		local cButton = CreateFrame("Button", "PallyPowerC" .. cbNum, self.Header, "SecureHandlerEnterLeaveTemplate, SecureHandlerStateTemplate, SecureActionButtonTemplate, PallyPowerButtonTemplate")
		--cButton:SetID(cbNum)
 		-- new show/hide functionality 
	    cButton:Execute([[others = table.new()]]); 
	    cButton:SetAttribute("_onenter", [[ 
	     									for _, other in ipairs(others) do
	       										other:SetAttribute("state-active", self)
	     									end 
	     									control:ChildUpdate("doshow")
										]] 
	    					)

	    cButton:SetAttribute("_onstate-active", [[
	     									control:ChildUpdate("dohide")
										]] 
	    					)
	    					
	    cButton:SetAttribute("_onleave", [[ 
											elap=0
											control:SetAnimating(true)
										]] 
	    					)
		cButton:SetAttribute("_onupdate", [[
		                                    if self:IsUnderMouse(true) then
		                                        elap = 0
									  		else
									  		    elap = elap + elapsed
									  		    if elap>=1 then
									  		    	control:ChildUpdate("dohide")
									  		    	control:SetAnimating(false)
									  		    end
									  		end
										  ]]
							)
	    
		--
		cButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		cButton:EnableMouseWheel(1)
        self.classButtons[cbNum] = cButton

		-- create player buttons
		self.playerButtons[cbNum] = {}
		local pButtons = self.playerButtons[cbNum]

		for pbNum = 1, PALLYPOWER_MAXPERCLASS do -- create player buttons for each class
			local pButton = CreateFrame("Button","PallyPowerC".. cbNum .. "P" .. pbNum, UIParent, "SecureHandlerEnterLeaveTemplate, SecureActionButtonTemplate, PallyPowerPopupTemplate")
			--pButton:SetID(cbNum)
			pButton:SetParent(self.classButtons[cbNum])
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
	        	--SecureHandlerExecute(cButton, [[table.insert(others, self:GetAttribute('frameref-other'));]]);  
	        	SecureHandlerExecute(cButton, [[
												local other = self:GetFrameRef("other")
												others[#others+1] = other;
											  ]]) 
			end
		end
	end

	self.autoButton = CreateFrame("Button", "PallyPowerAuto", self.Header, "PallyPowerAutoButtonTemplate")
	self.autoButton:RegisterForClicks("LeftButtonDown", "RightButtonDown")

	self.rfButton = CreateFrame("Button", "PallyPowerRF", self.Header, "PallyPowerRFButtonTemplate")
	self.rfButton:RegisterForClicks("LeftButtonDown")

	self:UpdateLayout()
	self:Debug("Create Layout -- end")
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
	self:Debug("Update Layout -- begin")
	if InCombatLockdown() then return false end
	PallyPowerFrame:SetScale(self.opt.buffscale)
	local rows = self.opt.display.rows
	local columns = self.opt.display.columns
	local gapping = self.opt.display.gapping
	local buttonWidth = self.opt.display.buttonWidth
	local buttonHeight = self.opt.display.buttonHeight
	local centerShiftX = 0
	local centerShiftY = 0
	local point = "BOTTOMLEFT"
	local pointOpposite = "TOPLEFT"
	local x = (buttonWidth + gapping)
	local y = (buttonHeight + gapping)
	local displayedButtons = math.min(self:CountClasses(),rows, columns)
	local displayedColumns = math.min(displayedButtons, columns)
	local displayedRows = math.floor((displayedButtons - 1) / columns) + 1

	if (self.opt.display.alignClassButtons == "1") then
		point = "BOTTOMLEFT"
		pointOpposite = "TOPLEFT"
	elseif (self.opt.display.alignClassButtons == "3") then
		x = x * -1
		point = "BOTTOMRIGHT"
		pointOpposite = "TOPRIGHT"
	elseif (self.opt.display.alignClassButtons == "7") then
		x = x * -1
		y = y * -1
		point = "TOPRIGHT"
		pointOpposite = "BOTTOMRIGHT"
	elseif (self.opt.display.alignClassButtons == "9") then
		y = y * -1
		point = "TOPLEFT"
		pointOpposite = "BOTTOMLEFT"
	end

	for cbNum = 1, PALLYPOWER_MAXCLASSES do -- position class buttons
		local cButton = self.classButtons[cbNum]
		-- set visual attributes
		self:SetButton("PallyPowerC" .. cbNum)
		-- set position
		cButton.x = (math.fmod(cbNum - 1, columns) * x + centerShiftX)
		cButton.y = math.floor((cbNum - 1) / columns) * y + centerShiftY
		cButton:ClearAllPoints()
		cButton:SetPoint(point, self.Header, "CENTER", cButton.x, cButton.y)

		local pButtons = self.playerButtons[cbNum]
		for pbNum = 1, PALLYPOWER_MAXPERCLASS do -- position player buttons
			local pButton = pButtons[pbNum]
			self:SetPButton("PallyPowerC".. cbNum .. "P" .. pbNum)
			--pButton:SetAttribute("showstates", tostring(cbNum))
			pButton:ClearAllPoints()
			if (self.opt.display.alignPlayerButtons == "bottom") then
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x,
									cButton.y - pbNum * (buttonHeight + gapping)
								)
			elseif (self.opt.display.alignPlayerButtons == "left") then
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x - pbNum * (buttonWidth + gapping),
									cButton.y
								)
			elseif (self.opt.display.alignPlayerButtons == "right") then
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x + pbNum * (buttonWidth + gapping),
									cButton.y
								)
			elseif (self.opt.display.alignPlayerButtons == "top") then
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x,
									cButton.y + pbNum * (buttonHeight + gapping)
								)
			elseif (self.opt.display.alignPlayerButtons == "compact-right") then
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x + (buttonWidth + gapping),
									cButton.y + (pbNum - 1) * (buttonHeight + gapping)
								)
			elseif (self.opt.display.alignPlayerButtons == "compact-left") then
				pButton:SetPoint(	point, self.Header, "CENTER",
									cButton.x - (buttonWidth + gapping),
									cButton.y + (pbNum - 1) * (buttonHeight + gapping)
								)
			end
		end
	end

	local autob = self.autoButton
 	autob:ClearAllPoints()
	autob:SetPoint(pointOpposite, self.Header, "CENTER", 0, 0)
	autob:SetAttribute("type", "spell")
	if self:GetNumUnits() > 0 and self.opt.autobuff.autobutton and not (PallyPowerDB.disabled and PallyPowerDB.disabled.Default) and PP_IsPally then
		autob:Show()
	else
		autob:Hide()
	end

	local rfb = self.rfButton
	rfb:ClearAllPoints()
	if self.opt.autobuff.autobutton then
		rfb:SetPoint(pointOpposite, self.Header, "CENTER", 0, -y)
	else
  		rfb:SetPoint(pointOpposite, self.Header, "CENTER", 0, 0)
	end
	rfb:SetAttribute("type1", "spell")
	rfb:SetAttribute("unit1", "player")
	rfb:SetAttribute("spell1", PallyPower.RFSpell)
	if self:GetNumUnits() > 0 and self.opt.rfbuff and not (PallyPowerDB.disabled and PallyPowerDB.disabled.Default) and PP_IsPally then
		rfb:Show()
	else
		rfb:Hide()
	end

	local cbNum = 0
	for classIndex = 1, PALLYPOWER_MAXCLASSES do
	local _, gspellID = PallyPower:GetSpellID(classIndex)
        if (classlist[classIndex] and classlist[classIndex] ~= 0 and (gspellID ~= 0 or PallyPower:NormalBlessingCount(classIndex) > 0)) then
		cbNum = cbNum + 1
		local cButton = self.classButtons[cbNum]
			cButton:Show()
			cButton:SetAttribute("classID", classIndex)
			cButton:SetAttribute("type1", "spell")
			cButton:SetAttribute("type2", "spell")
			local pButtons = self.playerButtons[cbNum]
			for pbNum = 1, math.min(classlist[classIndex], PALLYPOWER_MAXPERCLASS) do
				local pButton = pButtons[pbNum]
				if not self.opt.display.hidePlayerButtons then
					--pButton:SetAttribute("_childupdate-update", [[if class==self:GetID() then self:Show() else self:Hide(); end]])
				    pButton:SetAttribute("_childupdate-doshow", [[self:Show()]])
				else
					pButton:SetAttribute("_childupdate-doshow", [[self:Hide()]])
				end
				pButton:SetAttribute("_childupdate-dohide", [[self:Hide()]])
				pButton:SetAttribute("classID", classIndex)
				pButton:SetAttribute("playerID", pbNum)
				local unit  = self:GetUnit(classIndex, pbNum)
				local spellID, gspellID = self:GetSpellID(classIndex, unit.name)
				local spell = PallyPower.Spells[spellID]
				local gspell = PallyPower.GSpells[spellID]
				-- left click (target a specific player and do 15 minute buff)
				pButton:SetAttribute("type1", "spell")
				pButton:SetAttribute("unit1", unit.unitid)
				pButton:SetAttribute("spell1", gspell)
				-- right click (target a specific player and do 5 minute buff)
				pButton:SetAttribute("type2", "spell")
				pButton:SetAttribute("unit2", unit.unitid)
				pButton:SetAttribute("spell2", spell)
			end -- by pbnum
			for pbNum = classlist[classIndex]+1, PALLYPOWER_MAXPERCLASS do
				local pButton = pButtons[pbNum]
				pButton:SetAttribute("_childupdate-doshow", [[self:Hide()]])
				pButton:SetAttribute("_childupdate-dohide", [[self:Hide()]])
				pButton:SetAttribute("classID", 0)
				pButton:SetAttribute("playerID", 0)
			end
		end
	end
	cbNum = cbNum + 1
	for i = cbNum, PALLYPOWER_MAXCLASSES do
		local cButton = self.classButtons[i]
		cButton:SetAttribute("classID", 0)
		cButton:Hide()
		local pButtons = self.playerButtons[cbNum]
		for pbNum = 1, PALLYPOWER_MAXPERCLASS do
			local pButton = pButtons[pbNum]
			pButton:SetAttribute("classID", 0)
			pButton:SetAttribute("playerID", 0)
			pButton:Hide()
		end
	end

	self:ButtonsUpdate()
	self:UpdateAnchor(displayedButtons)

	self:Debug("Update Layout -- end")
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
--    self:Print("Update Button: %s, Class: %s", baseName, classID)
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
	--self:Print("Scaninfo: %s", PP_ScanInfo[classID])
	for playerID, unit in pairs(classes[classID]) do
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
			nhave = nhave + 1
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
		button:SetBackdropColor(1.0, 0.0, 0.0, 0.5)
	elseif (nneed > 0) then
		button:SetBackdropColor(1.0, 1.0, 0.5, 0.5)
	elseif (nspecial > 0) then
		button:SetBackdropColor(0.0, 0.0, 1.0, 0.5)
	else
		button:SetBackdropColor(0.0, 0.0, 0.0, 0.5)
	end

	return classExpire, classDuration, specialExpire, specialDuration, nhave, nneed, nspecial
--    self:Print("Update button -- end")
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
			local buffName, _, _, _, _, buffDuration, buffExpire = UnitBuff(unit.unitid, j)
			while buffExpire do
				buffExpire = buffExpire - GetTime()
				if (buffName == gspell) then
					classExpire = min(classExpire, buffExpire)
					classDuration = min(classDuration, buffDuration)
					break
				elseif (buffName == spell) then
					specialExpire = min(specialExpire, buffExpire)
					specialDuration = min(specialDuration, buffDuration)
					break
				end

				j = j + 1
				buffName, _, _, _, _, buffDuration, buffExpire = UnitBuff(unit.unitid, j)
			end
		end
	end
	return classExpire, classDuration, specialExpire, specialDuration
end

function PallyPower:GetRFExpiration()
    local spell = PallyPower.RFSpell
    local j = 1
    local rfExpire, rfDuration = 9999, 30*60
	local buffName, _, _, _, _, buffDuration, buffExpire = UnitBuff("player", j)
	while buffExpire do
		
		if buffName == spell then
			rfExpire = buffExpire - GetTime()
			break
		end
		j = j + 1
		buffName, _, _, _, _, buffDuration, buffExpire = UnitBuff("player", j)
	end
	return rfExpire, rfDuration
end

function PallyPower:UpdatePButton(button, baseName, classID, playerID)
	--self:Print("Update PButton: %s, Class: %s, Player: %s", baseName, classID, playerID)
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
			nhave = 1
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
			button:SetBackdropColor(0.0, 0.0, 1.0, 0.5)
		elseif (nhave == 0) then
			button:SetBackdropColor(1.0, 0.0, 0.0, 0.5)
		--elseif (nneed == 1) then
		--    button:SetBackdropColor(1.0, 1.0, 0.5, 0.5)
		else
			button:SetBackdropColor(0.0, 0.0, 0.0, 0.5)
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
		name:SetText(unit.name)
	else
		button:SetBackdropColor(0.0, 0.0, 0.0, 0.5)
		buffIcon:SetAlpha(0)
		rng:SetAlpha(0)
		dead:SetAlpha(0)
	end
	--    self:Print("Update PopupButton -- end")
end

function PallyPower:ButtonsUpdate()
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
		autobutton:SetBackdropColor(1.0, 0.0, 0.0, 0.5)
	elseif (sumnneed > 0) then
		autobutton:SetBackdropColor(1.0, 1.0, 0.5, 0.5)
	elseif (sumnspecial > 0) then
		autobutton:SetBackdropColor(0.0, 0.0, 1.0, 0.5)
	else
		autobutton:SetBackdropColor(0.0, 0.0, 0.0, 0.5)
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
	local time = _G["PallyPowerRFTime"]
	local expire, duration = PallyPower:GetRFExpiration()
	if expire == 9999 then
		rfbutton:SetBackdropColor(1.0, 0.0, 0.0, 0.5)
	else
		rfbutton:SetBackdropColor(0.0, 0.0, 0.0, 0.5)
	end
	time:SetText(self:FormatTime(expire))
	time:SetTextColor(self:GetSeverityColor(expire/duration))
end

function PallyPower:UpdateAnchor(displayedButtons)
	PallyPowerAnchor:SetChecked(self.opt.display.frameLocked)
	if (self.opt.display.hideDragHandle) then
		PallyPowerAnchor:Hide()
	else
		PallyPowerAnchor:Show()
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
			if not self:IsBuffActive(spell, spell2, unit.unitid) and IsSpellInRange(spell, unit.unitid) == 1 then
				return unit.unitid, spell, gspell
			end
		end
	end
	return nil, "", ""
end

function PallyPower:IsBuffActive(spellName, gspellName, unitID)
	local j = 1
	while UnitBuff(unitID, j) do
		local buffName, _, _, _, _, buffDuration, buffExpire = UnitBuff(unitID, j)
		if (buffName == spellName) or (buffName == gspellName) then
			if buffExpire then
				buffExpire = buffExpire - GetTime()
			end		
			return buffExpire, buffDuration, buffName
		end
		j = j + 1
	end
	return nil
end

function PallyPower:ButtonPreClick(button, mousebutton)
	if (not InCombatLockdown()) then
		--local button = this
		local classID = button:GetAttribute("classID")
		local unitid, spell, gspell = PallyPower:GetUnitAndSpellSmart(classID, mousebutton)
		--local spell = PallyPower:GetSpellName(classID)
		--local gspell = L["SPELL_GTPREF"] .. spell .. L["SPELL_GTSUFF"]
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

function PallyPower:DewClick()
	dewdrop:Open(PallyPowerConfigFrame)
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
		PallyPowerConfig_Toggle()
		button:SetChecked(self.opt.display.frameLocked)
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
			self:ScheduleEvent("PallyPowerTemporaryUnlock", RelockActionBars, 30)
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

function PallyPower:AutoBuff(mousebutton)
	if InCombatLockdown() then return end
	local now = time()
	local greater = (mousebutton == "LeftButton" or mousebutton == "Hotkey2")
	if greater then
		local groupCount = {}
		local HLspell = PallyPower.HLSpell
		if (GetNumRaidMembers() > 0) then
			for unit in RL:IterateRoster(false) do
				local subgroup = select(3, GetRaidRosterInfo(select(3, unit.unitid:find("(%d+)"))))
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
					--self:Print(unit.name .. ": " .. groupCount[select(3, GetRaidRosterInfo(select(3, unit.unitid:find("(%d+)"))))])
					if (spellid == gspellid and unit.unitid) then
						if (IsSpellInRange(spell, unit.unitid) == 1) then
							local penalty = 0
							if (self.AutoBuffedList[unit.name] and now - self.AutoBuffedList[unit.name] < 20) then
								penalty = PALLYPOWER_GREATERBLESSINGDURATION / 2
							end
							if (self.PreviousAutoBuffedUnit and unit.name == self.PreviousAutoBuffedUnit.name) then
								penalty = penalty + PALLYPOWER_GREATERBLESSINGDURATION
							end
							--self:Print("unit.name " .. unit.name)
							--self:Print("penalty " .. penalty)
							if (penalty < classMinUnitPenalty) then
								--self:Print(unit.name .. " has lowest penalty (" .. penalty .. ")")
								classMinUnit = unit
								classMinUnitPenalty = penalty
							end
							local buffExpire = self:IsBuffActive(spell, spell2, unit.unitid)
							if ((not buffExpire or buffExpire < classMinExpire and buffExpire < PALLYPOWER_GREATERBLESSINGDURATION-5*60) and classMinExpire > 0) then
								--self:Print(unit.name .. " has new min expire (" .. (buffExpire or 0) .. ")")
								classMinExpire = (buffExpire or 0)
								classMinSpell = spell
								classMaxSpell = gspell
							end
						elseif ((IsSpellInRange(HLspell, unit.unitid) ~= 1) and (not UnitIsAFK(unit.unitid)) and (GetNumRaidMembers() == 0 or groupCount[select(3, GetRaidRosterInfo(select(3, unit.unitid:find("(%d+)"))))] > 3)) then
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
		local minExpire, minUnit, minSpell = 9999, nil, nil
		for unit in RL:IterateRoster(true) do
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
				--self:Print("penalty on " .. unit.name .. ": " .. penalty)
				local buffExpire, _, buffName = self:IsBuffActive(spell, spell2, unit.unitid)
				if ((not buffExpire or buffExpire + penalty < minExpire and buffExpire < PALLYPOWER_NORMALBLESSINGDURATION) and minExpire > 0 and not (buffName == PallyPower.GSpells[6])) then
					--self:Print("buff needed " .. unit.name)
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

function PallyPower:AutoBuffClear(mousebutton)
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
	--if not self:CheckRaidLeader(self.player) then return false end
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