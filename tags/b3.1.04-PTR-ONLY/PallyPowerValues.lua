local L = AceLibrary("AceLocale-2.2"):new("PallyPower");
--local BS = AceLibrary("Babble-Spell-2.2")

PallyPower.commPrefix = "PLPWR";

PALLYPOWER_MAXCLASSES = 11;
PALLYPOWER_MAXPERCLASS = 8;
PALLYPOWER_NORMALBLESSINGDURATION = 10*60;
PALLYPOWER_GREATERBLESSINGDURATION = 30*60;
PALLYPOWER_MAXAURAS = 7;

PallyPower.CONFIG_DRAGHANDLE = L["DRAGHANDLE"];

PALLYPOWER_DEFAULT_VALUES = {
	buffscale = 0.90,
	configscale = 0.90,
	smartbuffs = true,
	greaterbuffs = true,
	rfbuff = true,
	rf = true,
	auras = true,
	autobuff = {
		autokey1 = ",",
		autokey2 = "CTRL-,",
		autobutton = true,
		waitforpeople = true,
	},
	display = {
		-- buttons
		rows = 9,
		columns = 1,
		gapping = 0,
		buttonWidth = 100,
		buttonHeight = 34,
		alignClassButtons = "9",
		alignPlayerButtons = "compact-left",
        frameLocked = false,
		hideDragHandle = false,
		hidePlayerButtons = false,
		PlainButtons = false,
		HideKeyText = false,
		HideCount = false,
        LockBuffBars = false,
        HideCountText = false,
		HideTimerText = false,
	},
	ShowInParty = true,
	ShowWhenSingle = true,
	skin = "Smooth",
	cBuffNeedAll     = {r = 1.0, g = 0.0, b = 0.0, t = 0.5},
 	cBuffNeedSome    = {r = 1.0, g = 1.0, b = 0.5, t = 0.5},
 	cBuffNeedSpecial = {r = 0.0, g = 0.0, b = 1.0, t = 0.5},
	cBuffGood        = {r = 0.0, g = 0.7, b = 0.0, t = 0.5},
	seal = 0, -- default wisdom
	disabled = false,
	};

PallyPower_Credits1 = "Pally Power - by Aznamir";
--PallyPower_Credits2 = "Version "..PallyPower_Version;

PallyPower.BuffBarTitle = "Pally Buffs (%d)";

PallyPower.ClassID = { 
	[1] = "WARRIOR",
	[2] = "ROGUE",
	[3] = "PRIEST",
	[4] = "DRUID",
	[5] = "PALADIN",
	[6] = "HUNTER",
	[7] = "MAGE",
	[8] = "WARLOCK",
	[9] = "SHAMAN",
	[10] = "DEATHKNIGHT",
	[11] = "PET"};
	
PallyPower.ClassToID = {
	["WARRIOR"] 	= 1,
	["ROGUE"] 		= 2,
	["PRIEST"] 		= 3,
	["DRUID"] 		= 4,
	["PALADIN"] 	= 5,
	["HUNTER"] 		= 6,
	["MAGE"] 		= 7,
	["WARLOCK"]		= 8,
	["SHAMAN"]		= 9,
	["DEATHKNIGHT"]	= 10,
	["PET"]			= 11};	

PallyPower.ClassIcons = {
	[1] = "Interface\\AddOns\\PallyPower\\Icons\\Warrior",
	[2] = "Interface\\AddOns\\PallyPower\\Icons\\Rogue",
	[3] = "Interface\\AddOns\\PallyPower\\Icons\\Priest",
	[4] = "Interface\\AddOns\\PallyPower\\Icons\\Druid",
	[5] = "Interface\\AddOns\\PallyPower\\Icons\\Paladin",
	[6] = "Interface\\AddOns\\PallyPower\\Icons\\Hunter",
	[7] = "Interface\\AddOns\\PallyPower\\Icons\\Mage",
	[8] = "Interface\\AddOns\\PallyPower\\Icons\\Warlock",
	[9] = "Interface\\AddOns\\PallyPower\\Icons\\Shaman",
	[10] = "Interface\\AddOns\\PallyPower\\Icons\\DeathKnight",
	[11] = "Interface\\AddOns\\PallyPower\\Icons\\Pet"};

PallyPower.BlessingIcons = {
    [-1] = "",
	[1] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofWisdom",
	[2] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
	[3] = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
	[4] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofSanctuary"};
	
PallyPower.NormalBlessingIcons = {
    [-1] = "",
	[1] = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
	[2] = "Interface\\Icons\\Spell_Holy_FistOfJustice",
	[3] = "Interface\\Icons\\Spell_Magic_MageArmor",
	[4] = "Interface\\Icons\\Spell_Nature_LightningShield"};

PallyPower.AuraIcons = {
    [-1] = "",
	[1] = "Interface\\Icons\\Spell_Holy_DevotionAura",
	[2] = "Interface\\Icons\\Spell_Holy_AuraOfLight",
	[3] = "Interface\\Icons\\Spell_Holy_MindSooth",
	[4] = "Interface\\Icons\\Spell_Shadow_SealOfKings",
	[5] = "Interface\\Icons\\Spell_Frost_WizardMark",
	[6] = "Interface\\Icons\\Spell_Fire_SealOfFire",
	[7] = "Interface\\Icons\\Spell_Holy_CrusaderAura",
};

--
-- Need to add localizations
--
PALLYPOWER_CLEAR = L["PP_CLEAR"];
PALLYPOWER_REFRESH = L["PP_REFRESH"];
PALLYPOWER_OPTIONS = L["PP_OPTIONS"];

PALLYPOWER_ASSIGNMENTS1 = L["PP_RAS1"];
PALLYPOWER_ASSIGNMENTS2 = L["PP_RAS2"];

PallyPower_TalentSearch = L["PP_TSEARCH"];
PallyPower_RankSearch = L["PP_RSEARCH"];
PallyPower_BlessingNameSearch = L["PP_BNSEARCH"];
PallyPower_Rank1 = L["PP_RANK1"];

PallyPower_Symbol = L["PP_SYMBOL"];

-- get translations directly
PallyPower.Spells = {
	[0] = "",
	[1] = GetSpellInfo(19742), --BS["Blessing of Wisdom"],
	[2] = GetSpellInfo(19740), --BS["Blessing of Might"],
	[3] = GetSpellInfo(20217), --BS["Blessing of Kings"],
	[4] = GetSpellInfo(20911), --BS["Blessing of Sanctuary"],
};

PallyPower.GSpells = {
	[0] = "",
	[1] = GetSpellInfo(25894), --BS["Greater Blessing of Wisdom"],
	[2] = GetSpellInfo(25782), --BS["Greater Blessing of Might"],
	[3] = GetSpellInfo(25898), --BS["Greater Blessing of Kings"],
	[4] = GetSpellInfo(25899), --BS["Greater Blessing of Sanctuary"],
};

PallyPower.RFSpell = GetSpellInfo(25780) --BS["Righteous Fury"]

PallyPower.HLSpell = GetSpellInfo(635)

PallyPower.Skins = {
    ["None"] = "Interface\\Tooltips\\UI-Tooltip-Background",
	["Banto"] = "Interface\\AddOns\\PallyPower\\Skins\\Banto",
	["BantoBarReverse"] = "Interface\\AddOns\\PallyPower\\Skins\\BantoBarReverse",
	["Glaze"] = "Interface\\AddOns\\PallyPower\\Skins\\Glaze",
	["Gloss"] = "Interface\\AddOns\\PallyPower\\Skins\\Gloss",
	["Healbot"] = "Interface\\AddOns\\PallyPower\\Skins\\Healbot",
	["oCB"] = "Interface\\AddOns\\PallyPower\\Skins\\oCB",
	["Smooth"] = "Interface\\AddOns\\PallyPower\\Skins\\Smooth",
};
	
PallyPower.Seals = {
    [0] = "",
    [1] = GetSpellInfo(20164), -- seal of justice
	[2] = GetSpellInfo(20165), -- seal of light
    [3] = GetSpellInfo(20166), -- seal of wisdom
    [4] = GetSpellInfo(21084), -- seal of right
    [5] = GetSpellInfo(53720), -- seal of martyr
    [6] = GetSpellInfo(31801), -- seal of vengeance
    [7] = GetSpellInfo(20375), -- seal of command
    [8] = GetSpellInfo(53736), -- seal of corruption
    [9] = GetSpellInfo(31892), -- seal of blood
    [10] = "",
};

PallyPower.Auras = {
	[0] = "",
	[1] = GetSpellInfo(465), --BS["Devotion Aura"],
	[2] = GetSpellInfo(7294), --BS["Retribution Aura"],
	[3] = GetSpellInfo(19746), --BS["Concentration Aura"],
	[4] = GetSpellInfo(19876), --BS["Shadow Resistance Aura"],
	[5] = GetSpellInfo(19888), --BS["Frost Resistance Aura"],
	[6] = GetSpellInfo(19891), --BS["Fire Resistance Aura"],
	[7] = GetSpellInfo(32223), --BS["Crusader Aura"],
};
