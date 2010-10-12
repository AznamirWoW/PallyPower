﻿local L = AceLibrary("AceLocale-2.2"):new("PallyPower")

-- Simp.Chinese by Diablohu
-- http://www.dreamgen.cn
-- last update: 5/12/2008

L:RegisterTranslations("zhCN", function()
	return {
		---- Options menu ----
		["BAS"] 		= "祝福管理",
		["BAS_DESC"] 		= "打开祝福管理窗口",
		["BRPT"] 		= "祝福分配报告",
		["BRPT_DESC"] 		= "向团队/小队报告祝福分配情况",
		["BSC"] 		= "主窗口大小",
		["BSC_DESC"] 		= "设置祝福施加窗口的大小",
		["CSC"] 		= "选项窗口大小",
		["CSC_DESC"] 		= "设置选项窗口的大小",
		["SBUFF"] 		= "智能选择祝福",
		["SBUFF_DESC"] 		= "在选择祝福时为某些职业忽略特定的祝福",
		["DISP"] 		= "显示设置",
		["DISP_DESC"] 		= "祝福施加窗口的设置",
		["DISPCOL"] 		= "列数",
		["DISPCOL_DESC"] 	= "设置列数",
		["DISPROWS"] 		= "行数",
		["DISPROWS_DESC"] 	= "设置行数",
		["DISPGAP"] 		= "间隔",
		["DISPGAP_DESC"] 	= "设置按钮间距",
		["DISPCL"] 		= "职业按钮",
		["DISPCL_DESC"] 	= "职业按钮方向设置",
		["DISPPL"] 		= "玩家按钮",
		["DISPPL_DESC"] 	= "玩家按钮方向设置",
		["DISABLED"]		= "禁用",
		["ENABLED"]		= "启用",
		["HIDEPB"]              = "隐藏玩家按钮",
		["HIDEPB_DESC"]		= "显示/隐藏玩家按钮",
		["HIDEDH"]		= "隐藏拖动柄",
		["HIDEDH_DESC"]		= "显示/隐藏拖动柄",
		["SHOWPARTY"]		= "在小队时显示",
		["SHOWPARTY_DESC"]	= "当加入一个小队后显示/隐藏祝福施加窗口",
		["SHOWSINGLE"]		= "在单独时显示",
		["SHOWSINGLE_DESC"]	= "当单独一人显示/隐藏祝福施加窗口",
		["GREATER"]             = "强效祝福",
		["GREATER_DESC"]	= "启用/禁用强效祝福",
		["AUTOBUFF"]		= "自动祝福",
		["AUTOBUFF_DESC"]	= "自动祝福设置",
  		["AUTOKEY1"]		= "自动施放弱效祝福按键",
		["AUTOKEY1_DESC"]	= "为自动施加弱效祝福功能绑定按键。",
		["AUTOKEY2"]		= "自动施放强效祝福按键",
		["AUTOKEY2_DESC"]	= "为自动施加强效祝福功能绑定按键。",
		["AUTOBTN"]		= "显示自动祝福按钮",
		["AUTOBTN_DESC"]	= "显示/隐藏自动祝福按钮",
		["WAIT"]		= "等待所有队友",
		["WAIT_DESC"]		= "是否等待所有队友都在线且都在祝福范围内才施放祝福",
		["RESET"]		= "重置位置",
		["RESET_DESC"]		= "将所有PallyPower窗口的位置重置回屏幕中央",
		["RFBUFF"] 			= "正义之怒",
		["RFBUFF_DESC"] 	= "启用/禁用正义之怒监视器",
		["FREEASSIGN"] 		= "自由配置",
		["FREEASSIGN_DESC"] 	= "允许其他非团队领袖/助理人员更改你的祝福配置",		-- more to come
		--- Variables
		["DRAGHANDLE"] 		= "左键拖动以移动\n单击以锁定或解锁\n右键单击以打开设置",
		["PP_CLEAR"]		= "清除",
		["PP_REFRESH"]		= "刷新",
		["PP_OPTIONS"]		= "设置",
		["PP_RAS1"]		= "--- 圣骑士祝福分配 ---",
		["PP_RAS2"]		= "--- 分配通告结束 ---",
		["PP_TSEARCH"]		= "强化(.*)",
		["PP_BNSEARCH"]		= "(.*)祝福",
		["PP_RANK1"]		= "等级 1",
		["PP_RSEARCH"]		= "等级 (.*)",
		["PP_SYMBOL"]		= "王者印记",
	}
end)