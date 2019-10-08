local L = LibStub("AceLocale-3.0"):GetLocale("PallyPower")

PallyPower.options = {
	name = L["PP_NAME"],
  type = "group",
  childGroups = "tab",
	args = {
		settings = {
			order = 1,
			name = L["SETTINGS"],
			desc = L["SETTINGS_DESC"],
			type = "group",
			args = {
				settings_show = {
					order = 1,
					name = L["PP_SHOW"],
					type = "group",
					inline = true,
					args = {
						globally = {
							order = 1,
							name = L["SHOWGLOBAL"],
							desc = L["SHOWGLOBAL_DESC"],
							type = "toggle",
							get = function(info) return PallyPower.opt.enabled end,
							set = function(info, val)
								PallyPower.opt.enabled = val
								if PallyPower.opt.enabled then
									PallyPower:OnEnable()
								else
									PallyPower:OnDisable()
								end
							end,
						},
						showparty = {
							order = 2,
							name = L["SHOWPARTY"],
							desc = L["SHOWPARTY_DESC"],
							type = "toggle",
							disabled = function(info) return PallyPower.opt.enabled == false end,
							get = function(info) return PallyPower.opt.ShowInParty end,
							set = function(info, val)
								PallyPower.opt.ShowInParty = val
								PallyPower:UpdateRoster()
							end,
						},
						showsingle = {
							order = 3,
							name = L["SHOWSOLO"],
							desc = L["SHOWSOLO_DESC"],
							type = "toggle",
							disabled = function(info) return PallyPower.opt.enabled == false end,
							get = function(info) return PallyPower.opt.ShowWhenSolo end,
							set = function(info, val)
								PallyPower.opt.ShowWhenSolo = val
								PallyPower:UpdateRoster()
							end,
						},
					},
				},
				settings_frames = {
					order = 2,
					name = L["PP_LOOKS"],
					type = "group",
					inline = true,
					args = {
						buffscale = {
							order = 1,
							name = L["BSC"],
							desc = L["BSC_DESC"],
							type = "range",
							width = 1.65,
							min = 0.4,
							max = 1.5,
							step = 0.05,
							get = function(info) return PallyPower.opt.buffscale end,
							set = function(info, val)
								PallyPower.opt.buffscale = val
								PallyPower:UpdateLayout()
							end,
						},
						skin = {
							order = 2,
							name = L["SKIN"],
							desc = L["SKIN_DESC"],
							type = "select",
							width = 1.65,
							dialogControl = "LSM30_Background",
							values = AceGUIWidgetLSMlists.background,
							get = function(info) return PallyPower.opt.skin end,
							set = function(info,val)
								PallyPower.opt.skin = val
								PallyPower:ApplySkin()
							end,
						},
						edges = {
							order = 3,
							name = L["DISPEDGES"],
							desc = L["DISPEDGES_DESC"],
							type = "select",
							width = 1.65,
							dialogControl = "LSM30_Border",
							values = AceGUIWidgetLSMlists.border,
							get = function(info) return PallyPower.opt.border end,
							set = function(info,val)
								PallyPower.opt.border = val
								PallyPower:ApplySkin()
							end,
						},
						frame_layout = {
							order = 4,
							name = "",
							type = "group",
							inline = true,
							args = {
								layout = {
									order = 1,
									type = "select",
									width = 1.2,
									name = L["LAYOUT"],
									desc = L["LAYOUT_DESC"],
									get = function(info) return PallyPower.opt.layout end,
									set = function(info,val)
										PallyPower.opt.layout = val
										PallyPower:UpdateLayout()
									end,
									values = {
										["Layout 1"] = L["Right"],
										["Layout 2"] = L["Left"],
										["Layout 3"] = L["Down"],
										["Layout 4"] = L["Up"],
									},
								},
							},
						},
					},
				},
				settings_color = {
					order = 3,
					name = L["PP_COLOR"],
					type = "group",
					inline = true,
					args = {
						color_good = {
							order = 1,
							name = L["Fully Buffed"],
							type = "color",
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
							order = 2,
							name = L["Partially Buffed"],
							type = "color",
							width = 1.1,
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
							order = 3,
							name = L["None Buffed"],
							type = "color",
							get = function() return PallyPower.opt.cBuffNeedAll.r, PallyPower.opt.cBuffNeedAll.g, PallyPower.opt.cBuffNeedAll.b, PallyPower.opt.cBuffNeedAll.t end,
							set = function (info, r, g, b, t)
								PallyPower.opt.cBuffNeedAll.r = r
								PallyPower.opt.cBuffNeedAll.g = g
								PallyPower.opt.cBuffNeedAll.b = b
								PallyPower.opt.cBuffNeedAll.t = t
							end,
							hasAlpha = true,
						},
					},
				},
				settings_reset = {
					order = 4,
					name = L["PP_RESET"],
					type = "group",
					inline = true,
					args = {
						reset = {
							order = 1,
							name = L["RESET"],
							desc = L["RESET_DESC"],
							type = "execute",
							func = function() PallyPower:Reset() end,
						},
					},
				},
			},
		},
		buttons = {
			order = 2,
			name = L["BUTTONS"],
			desc = L["BUTTONS_DESC"],
			type = "group",
			args = {
				aura_button = {
					order = 1,
					name = L["AURA"],
					type = "group",
					inline = true,
					args = {
						aura_desc = {
							order = 0,
							type = "description",
							name = L["AURA_DESC"],
						},
						aura_enable = {
							order = 1,
							type = "toggle",
							name = L["AURABTN"],
							desc = L["AURABTN_DESC"],
							width = 1.1,
							get = function(info) return PallyPower.opt.auras end,
							set = function(info, val)
								PallyPower.opt.auras = val
								PallyPower:RFAssign(PallyPower.opt.auras)
								PallyPower:UpdateRoster()
							end,
						},
						aura = {
							order = 2,
							type = "select",
							name = L["AURATRACKER"],
							desc = L["AURATRACKER_DESC"],
							get = function(info) return PallyPower_AuraAssignments[PallyPower.player] end,
							set = function(info, val)
								PallyPower_AuraAssignments[PallyPower.player] = val
							end,
							values = {
								[0] = L["None"],
								[1] = PallyPower.Auras[1],
								[2] = PallyPower.Auras[2],
								[3] = PallyPower.Auras[3],
								[4] = PallyPower.Auras[4],
								[5] = PallyPower.Auras[5],
								[6] = PallyPower.Auras[6],
								[7] = PallyPower.Auras[7],
							},
						},
					},
				},
				seal_button = {
					order = 2,
					name = L["SEAL"],
					type = "group",
					inline = true,
					args = {
						seal_desc = {
							order = 0,
							type = "description",
							name = L["SEAL_DESC"],
						},
						seal_enable = {
							order = 1,
							type = "toggle",
							name = L["SEALBTN"],
							desc = L["SEALBTN_DESC"],
							width = 1.1,
							get = function(info) return PallyPower.opt.rfbuff end,
							set = function(info, val)
								PallyPower.opt.rfbuff = val
								PallyPower:UpdateRoster()
							end,
						},
						rfury = {
							order = 2,
							type = "toggle",
							name = L["RFM"],
							desc = L["RFM_DESC"],
							get = function(info) return PallyPower.opt.rf end,
							set = function(info, val)
								PallyPower.opt.rf = val
								PallyPower:RFAssign(PallyPower.opt.rf)
							end,
						},
						seal = {
							order = 3,
							type = "select",
							name = L["SEALTRACKER"],
							desc = L["SEALTRACKER_DESC"],
							width = .9,
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
								[6] = PallyPower.Seals[6],
							},
						},
					},
				},
				auto_button = {
					order = 3,
					name = L["AUTO"],
					type = "group",
					inline = true,
					args = {
						auto_desc = {
							order = 0,
							type = "description",
							name = L["AUTO_DESC"],
						},
						auto_enable = {
							order = 1,
							type = "toggle",
							name = L["AUTOBTN"],
							desc = L["AUTOBTN_DESC"],
							width = 1.1,
							get = function(info) return PallyPower.opt.autobuff.autobutton end,
							set = function(info, val)
								PallyPower.opt.autobuff.autobutton = val
								PallyPower:UpdateRoster()
							end,
						},
						auto_wait = {
							order = 2,
							type = "toggle",
							name = L["WAIT"],
							desc = L["WAIT_DESC"],
							get = function(info) return PallyPower.opt.autobuff.waitforpeople end,
							set = function(info, val)
								PallyPower.opt.autobuff.waitforpeople = val
								PallyPower:UpdateRoster()
							end,
						},
					},
				},
				cp_button = {
					order = 4,
					name = L["CPBTNS"],
					type = "group",
					inline = true,
					args = {
						pc_desc = {
							order = 0,
							type = "description",
							name = L["CPBTNS_DESC"],
						},
						class_enable = {
							order = 1,
							type = "toggle",
							name = L["CLASSBTN"],
							desc = L["CLASSBTN_DESC"],
							width = 1.1,
							get = function(info) return PallyPower.opt.display.showClassButtons end,
							set = function(info, val)
								PallyPower.opt.display.showClassButtons = val
								if (PallyPower.opt.display.showPlayerButtons and not PallyPower.opt.display.showClassButtons) then
									PallyPower.opt.display.showPlayerButtons = false
								end
								PallyPower:UpdateRoster()
							end,
						},
						player_enable = {
							order = 2,
							type = "toggle",
							name = L["PLAYERBTNS"],
							desc = L["PLAYERBTNS_DESC"],
							disabled = function(info) return PallyPower.opt.display.showClassButtons == false end,
							get = function(info) return PallyPower.opt.display.showPlayerButtons end,
							set = function(info, val)
								PallyPower.opt.display.showPlayerButtons = val
								if not PallyPower.opt.display.showClassButtons then
									PallyPower.opt.display.showPlayerButtons = false
								end
								PallyPower:UpdateRoster()
							end,
						},
					},
				},
				misc_button = {
					order = 5,
					name = L["MISCBTNS"],
					type = "group",
					inline = true,
					args = {
						misc_desc = {
							order = 0,
							type = "description",
							name = L["MISCBTNS_DESC"],
						},
						drag_enable = {
							order = 1,
							type = "toggle",
							name = L["DRAGHANDLE_ENABLED"] ,
							desc = L["DRAGHANDLE_ENABLED_DESC"] ,
							width = 1.1,
							get = function(info) return PallyPower.opt.display.enableDragHandle end,
							set = function(info, val)
								PallyPower.opt.display.enableDragHandle = val
								PallyPower:UpdateRoster()
							end,
						},
						smart_buffs = {
							order = 2,
							type = "toggle",
							name = L["SMARTBUFF"],
							desc = L["SMARTBUFF_DESC"],
							get = function(info) return PallyPower.opt.smartbuffs end,
							set = function(info, val)
								PallyPower.opt.smartbuffs = val
								PallyPower:UpdateRoster()
							end,
						},
					},
				},
			},
		},
	},
}
