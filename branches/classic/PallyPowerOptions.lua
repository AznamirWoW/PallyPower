local L = LibStub("AceLocale-3.0"):GetLocale("PallyPower")

PallyPower.options =
{
	type = "group",
	name = "PallyPower",
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
			get = function(info) return PallyPower.opt.buffscale end,
			set = function(info, val)
					PallyPower.opt.buffscale = val
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
			get = function(info) return PallyPower.opt.display.ShowInParty end,
			set = function(info, val)
				PallyPower.opt.display.ShowInParty = val
				--PallyPower:UpdateRoster()
				end,
		},
		showsingle = {
			type = "toggle",
			order = 18,
			name = L["SHOWSINGLE"],
			desc = L["SHOWSINGLE_DESC"],
			get = function(info) return PallyPower.opt.display.ShowWhenSingle end,
			set = function(info, val)
					PallyPower.opt.display.ShowWhenSingle = val
					--PallyPower:UpdateRoster()
				end,
		},
		extras = {
			type = "toggle",
			order = 19,
			name = L["IGNOREEXTRA"],
			desc = L["IGNOREEXTRADESC"],
			get = function(info) return PallyPower.opt.extras end,
			set = function(info, val)
					PallyPower.opt.extras = val
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
					get = function(info) return PallyPower.opt.layout end,
					set = function(info,val)
						PallyPower.opt.layout = val
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
					get = function(info) return PallyPower.opt.skin end,
					set = function(info,val)
						PallyPower.opt.skin = val
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
					get = function(info) return PallyPower.opt.border end,
					set = function(info,val)
						PallyPower.opt.border = val
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
					get = function() return PallyPower.opt.cBuffGood.r, PallyPower.opt.cBuffGood.g, PallyPower.opt.cBuffGood.b, PallyPower.opt.cBuffGood.t end,
					set = function (info, r, g, b, t)
							PallyPower.opt.cBuffGood.r = r
							PallyPower.opt.cBuffGood.g = g
							PallyPower.opt.cBuffGood.b = b
							PallyPower.opt.cBuffGood.t = t
						end,
					hasAlpha = true,
				},
				color_partial = {
					type = "color",
					order = 9,
					name = L["Partially Buffed"],
					get = function() return PallyPower.opt.cBuffNeedSome.r, PallyPower.opt.cBuffNeedSome.g, PallyPower.opt.cBuffNeedSome.b, PallyPower.opt.cBuffNeedSome.t end,
					set = function (info, r, g, b, t)
							PallyPower.opt.cBuffNeedSome.r = r
							PallyPower.opt.cBuffNeedSome.g = g
							PallyPower.opt.cBuffNeedSome.b = b
							PallyPower.opt.cBuffNeedSome.t = t
						end,
					hasAlpha = true,
				},
				color_missing = {
					type = "color",
					order = 10,
					name = L["None Buffed"],
					get = function() return PallyPower.opt.cBuffNeedAll.r, PallyPower.opt.cBuffNeedAll.g, PallyPower.opt.cBuffNeedAll.b, PallyPower.opt.cBuffNeedAll.t end,
					set = function (info, r, g, b, t)
							PallyPower.opt.cBuffNeedAll.r = r
							PallyPower.opt.cBuffNeedAll.g = g
							PallyPower.opt.cBuffNeedAll.b = b
							PallyPower.opt.cBuffNeedAll.t = t
						end,
					hasAlpha = true,
				},
				rfs = {
					type = "group",
					order = 11,
					name = L["RFM"],
					desc = L["RFM_DESC"],
					args = {
						rfury = {
							type = "toggle",
							order = 12,
							name = L["RFUSE"],
							desc = L["RFUSE_DESC"],
							get = function(info) return PallyPower.opt.rf end,
							set = function(info, val)
								PallyPower.opt.rf = val
								PallyPower:RFAssign(PallyPower.opt.rf)
								end,
						},
						seal = {
							type = "select",
							order = 16,
							name = L["SEAL"],
							desc = L["SEAL_DESC"],
							get = function(info) return PallyPower.opt.seal end,
							set = function(info, val)
								PallyPower.opt.seal = val
								PallyPower:SealAssign(PallyPower.opt.seal)
								end,
							values = {
								[0] = L["None"],
								[1] = PallyPower.Seals[1],
								[2] = PallyPower.Seals[2],
								[3] = PallyPower.Seals[3],
								[4] = PallyPower.Seals[4],
								[5] = PallyPower.Seals[5],
							},
						},
					},
				},
			},      -- display args
		}, -- main args
	},
}

function PallyPower:BuffScale(value)
	if not value then return self.opt.buffscale end
	self.opt.buffscale = value;
	PallyPower:UpdateLayout();
end

function PallyPower:ConfigScale(value)
	if not value then return self.opt.configscale end
	self.opt.configscale = value;
end

function PallyPower:skinButtons(value)
	if not value then
		return self.opt.skin
	else
    	self.opt.skin = value
		PallyPower:ApplySkin(value)
	end
end

function PallyPower:ToggleEdges(value)
	if type(value) == "nil" then return self.opt.display.edges end
	self.opt.display.edges = value
	PallyPower:ApplySkin(self.opt.skin)
end

function PallyPower:layout(value)
	if not value then
		return self.opt.layout;
	else
    	self.opt.layout = value;
		PallyPower:UpdateLayout();
	end
end
function PallyPower:displayRows(value)
	if not value then return self.opt.display.rows end
	self.opt.display.rows = value;
	PallyPower:UpdateLayout();
end

function PallyPower:displayColumns(value)
	if not value then return self.opt.display.columns end
	self.opt.display.columns = value;
	PallyPower:UpdateLayout();
end

function PallyPower:displayGapping(value)
	if not value then return self.opt.display.gapping end
	self.opt.display.gapping = value
	PallyPower:UpdateLayout();
end

function PallyPower:displayAlignClassButtons(value)
	if not value then return self.opt.display.alignClassButtons end
	self.opt.display.alignClassButtons = value
	PallyPower:UpdateLayout();
end

function PallyPower:displayAlignPlayerButtons(value)
	if not value then return self.opt.display.alignPlayerButtons end
	self.opt.display.alignPlayerButtons = value;
	PallyPower:UpdateLayout();
end

function PallyPower:ToggleSmartBuffs(value)
	if type(value) == "nil" then return self.opt.smartbuffs end
	self.opt.smartbuffs = value;
end

function PallyPower:ToggleSmartPets(value)
	if type(value) == "nil" then return self.opt.smartpets end
	self.opt.smartpets = value;
end

function PallyPower:ToggleRFButton(value)
	if type(value) == "nil" then return self.opt.rfbuff end
	self.opt.rfbuff = value
	PallyPower:UpdateLayout()
end

function PallyPower:ToggleRF(value)
	if type(value) == "nil" then return self.opt.rf end
	self.opt.rf = value
	PallyPower:RFAssign(self.opt.rf)
end

function PallyPower:ToggleSeal(value)
	if type(value) == "nil" then return self.opt.seal end
	self.opt.seal = value
	PallyPower:SealAssign(self.opt.seal)
end

function PallyPower:ToggleFA(value)
	if type(value) == "nil" then return self.opt.freeassign end
	self.opt.freeassign = value
	PallyPower:UpdateLayout()
end

function PallyPower:ToggleShowParty(value)
	if type(value) == "nil" then return self.opt.ShowInParty end
	self.opt.ShowInParty = value;
end

function PallyPower:ToggleShowSingle(value)
	if type(value) == "nil" then return self.opt.ShowWhenSingle end
	self.opt.ShowWhenSingle = value;
end

function PallyPower:ToggleDragHandle(value)
	if type(value) == "nil" then return self.opt.display.hideDragHandle end
	self.opt.display.hideDragHandle = value;
	PallyPower:UpdateLayout();
end

function PallyPower:TogglePlayerButtons(value)
	if type(value) == "nil" then return self.opt.display.hidePlayerButtons end
	self.opt.display.hidePlayerButtons = value;
	PallyPower:UpdateLayout();
end

function PallyPower:ToggleClassButtons(value)
	if type(value) == "nil" then return self.opt.hideClassButtons end
	self.opt.hideClassButtons = value;
	PallyPower:UpdateLayout();
end

function PallyPower:ToggleAutoButton(value)
	if type(value) == "nil" then return self.opt.autobuff.autobutton end
	self.opt.autobuff.autobutton = value;
	PallyPower:UpdateLayout();
end

function PallyPower:ToggleWaitPeople(value)
	if type(value) == "nil" then return self.opt.autobuff.waitforpeople end
	self.opt.autobuff.waitforpeople = value;
end

function PallyPower:ToggleAuras(value)
	if type(value) == "nil" then return self.opt.auras end
	self.opt.auras = value;
	PallyPower:UpdateLayout();
end

function PallyPower:ToggleExtras(value)
	if type(value) == "nil" then return self.opt.extras end
	self.opt.extras = value;
	PallyPower:UpdateRoster();
end
