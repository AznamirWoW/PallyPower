# PallyPower Forever (WoW: Forever beta)

This project has been merged with PallyPower Forever by Laxativum, with the permission of the original
author, Aznamir. Forever port by Pallyblaze and Laxativum.

## Changes since 9.30.26
- Shaman column added for both factions; pet column and Show Pets option removed (pets cannot be buffed).
- Surnamed characters ("First Last") are identified by full name: no duplicate paladin rows, individual assignments sync correctly. First names only on the assignment page and side panels.
- Lua errors fixed in dungeons and combat: hidden ("secret") auras, unit checks, spellcast events, cooldowns, aura button.
- Buff bar stays green in combat: timers keep counting from the last readable values.
- Seal tracker with Seal of Fury; its timer holds through combat and restarts on an in-combat recast.
- API layer reworked to use the modern C_ calls first, legacy calls only as a fallback; spell lookups no longer error on bad input.
- Left-click casts normal blessings until Greater Blessings exist, then switches back automatically.
- Auto Buff button always casts, with its own Buff Duration option (off by default). Class & Player Buff Duration now works with 60 minute blessings and is no longer switched off by Righteous Fury.
- Options button opens on the first click; Preset button no longer errors with nothing saved.
- Talent scanning skipped (no improved blessings on Forever).
- Credits, title and version updated (v10.10.26-forever).
## Earlier notes

# PallyPower - WoW: Forever beta port (experimental)

Install to: World of Warcraft\_classic_beta_\Interface\AddOns\PallyPower\  (restart client)
Tick "Load out of date AddOns" if it shows as out of date.

First run: type /ppforever and send the output. It prints the client build, which
APIs exist, which blessing names/ranks resolve and which spell IDs you know.

Changes vs 1.5.22-classic:
- PallyPower_Camelot.toc (Interface 16001; "Camelot" is the reported temporary TOC suffix)
- Compat.lua: shims for GetSpellInfo, GetSpellSubtext, GetSpellCooldown, IsSpellKnown,
  IsSpellInRange, GetItemCount, UnitBuff/UnitAura, SendChatMessage; stubs for the old talent API
- Forever uses the Vanilla blessing set; LibClassicDurations is not loaded
- All blessing durations set to 60 minutes
- Options-panel registration wrapped in pcall (old bundled Ace3 may fail on modern clients)
- Talent scanning is skipped on Forever: there are no improved blessings or auras, every paladin has every buff at full strength

Untested in-game. Known unknowns: Forever spell IDs, rank text, Greater Blessings (absent in beta).
If the options panel or drop-downs error, install the current standalone Ace3 addon; LibStub will use the newer libraries.
- Surnames: on Forever the player is keyed by the full name ("First Last") so you no longer appear twice
- Added Seal of Fury (spell 1311656) to the seal tracker; seal timer now uses the real aura duration
- NASSIGN (per-player blessing assignments) encodes the space in "First Last" names so they sync correctly
- Window title, keybinding category and options panel say "PallyPower Forever"; credits line reads "Updated for Forever by Pallyblaze"
- "Hide count text" is switched on once by default on Forever (re-enable in Options if wanted)
- Shaman is class slot 9 (both factions). There is no pet column: pets cannot be buffed on Forever. Uses the standard 9-column PallyPower_Vanilla.xml.
- Aura shims are pcall-protected so restricted ("secret") auras no longer raise errors; the Preset button tolerates an empty saved preset
- Player name refreshed at login and zone-in, and UpdateLayout self-heals a missing paladin entry (fixes a nil error after the surname change)
- Assignment page shows first names only on Forever
- Show Pets option is hidden on Forever (pets cannot be buffed there)
- UNIT_SPELLCAST_SUCCEEDED only handles the player and ignores secret values (fixes the error flood in instances)
- Options button opens the panel on the first click (upstream bug: it was created shown, then immediately toggled closed)
- Righteous Fury spell name is resolved on demand (cold-start safe); /ppforever prints RF status
- Hidden (secret) auras such as active seals or personal cooldowns are returned as placeholders, so a buff scan no longer stops early and the bar no longer turns red in combat
- Buff expiry/duration hidden in combat: last readable values are remembered per unit and aura so timers keep counting down instead of turning red
- Buff detection in combat: when aura names are hidden, the addon now falls back to the last readable expiry it saw for that unit+blessing (and for Righteous Fury), so bars stay green and timers keep counting. The memory is cleared by any fully readable scan that no longer shows the buff. /ppaura [unit] shows what the client exposes (run it in combat).
- Aura button (e.g. Retribution Aura) no longer turns red in combat: last readable active/self-cast state is remembered while the player's auras are hidden.
- ScanCooldowns ignores secret cooldown numbers in combat (keeps last readable start/duration and ticks remaining down); fixes the 'arithmetic on secret number' error on opening the window in combat.
- Unit-state checks (dead, AFK, connected, visible, in combat, spell range) are wrapped so hidden values fall back to safe defaults instead of raising errors ("boolean test on a secret boolean")
- Spell API shims validate their input (empty string, 0, non-spell values) and catch client errors, fixing "bad argument #1 ... C_Spell.GetSpellInfo" on load
- v10.03.26: API layer reworked. Compat.lua now provides a private PPAPI table that calls the modern C_ functions first (C_Spell, C_SpellBook, C_UnitAuras, C_Item, C_ChatInfo, C_AddOns) and uses the legacy globals only as a fallback; PallyPower files alias the names locally, and no replacement globals are defined for other addons to see. /ppforever lists which implementation each function resolved to.
- Left-click on class buttons, player buttons and the auto-buff button casts the normal blessing while the character knows no Greater Blessing (none exist yet on Forever); it switches back to Greater Blessings automatically once one is learned
- Buff bar side panels (the player buttons that pop out) show first names only on Forever
- Seal tracker is back on (Seal of Fury restored once if it had been switched off). Its timer uses the same remembered-aura lookup as Righteous Fury, holds the last measured countdown through combat, and restarts from the last measured duration when you recast the seal in combat. Left-click on the Auto Buff button, while no Greater Blessing is known, buffs players who need it first and otherwise steps through every eligible player; the 0.2 s window keeps mouse-down and mouse-up on the same target.
- v10.10.26: projects merged with Laxativum's Forever port (permission from the original author); mouseover credit reads "Updated for Forever by Pallyblaze / Laxativum"
- Auto Buff Button has its own "Buff Duration" option (off by default): off = the button always casts, stepping through players even if their buff is running; on = only players missing a blessing or under 4 minutes. Right-click and the first hotkey use the same selector as left-click.
- Class & Player "Buff Duration" unchecked now works for right-click on class buttons on Forever: the old spam logic assumed 5-10 minute blessings and never refreshed a 60 minute one. It now buffs players missing a blessing first, then whoever was buffed longest ago.
