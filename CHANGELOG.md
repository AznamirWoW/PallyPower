v11.08:

* Added an Oath of Light button in the drop-out beside each class (only shows once you have the talent). Left or right click swears the Oath on a player of that class: a tank first, otherwise whoever is missing it. It shows the time left (5 minutes) and tracks that only one Oath can be active at a time.
* Added an Oath of Light timer inside the aura button so you can see when it runs out.

v11.05:

* Removed the Salvation checkbox and the Salvation / Mass Salvation drop-out. Blizzard removed Salvation from the game, so it is no longer assignable or tracked.
* Fixed a "tried to call the protected function StartMoving()" error when trying to drag the bar during combat. Dragging is now ignored in combat.

v10.17:

* Fixed Wisdom and Might not tracking in battlegrounds when buffing players under level 60 (their ranked cast name did not match what the game reports). They now light up green and count down like Kings.

v10.12:

* Fixed class-button clicks (left or right) buffing the same player over and over in raids and battlegrounds. Clicks now rotate through the class, and with Buff Duration checked they skip players who already have a blessing with 4+ minutes left.
* Battlegrounds/arenas: the game hides other players' buffs there, so the bars stayed red. The addon now remembers the blessings you cast and tracks them (60 min countdown) until you leave.

* Battlegrounds: your own aura, Righteous Fury and seal are hidden there too. The aura is now remembered when you cast it, and Righteous Fury/seal timers restart on cast using the duration last measured outside the battleground.

* Battlegrounds: a player who dies loses their remembered blessing, so their bar turns red until you rebuff them.


v10.10 (Merging with Laxativum's build on PallyPower discord):

* Auto Buff “Buff Duration” option in the Auto Buff Button section, unchecked by default. Unchecked, the button always casts and lets you refresh buffs no matter the duration. Checked, it only buffs players who are missing a blessing or have under 4 minutes left.
* Left-click fallback: left-click on the class, player and Auto Buff buttons casts the normal blessing while no Greater Blessing is known. It switches back to Greater Blessings automatically once you learn one.
* Seal tracker restored: Seals now track in combat in latest beta build.

v10.03:

* Fixed an occasional lua error for SpellInfo calls, and made sure all legacy calls were fallbacks only. Minor code fixes.

v10.02:

* Fixed an occasional lua error that was coming up from unit-state wrappers after the latest beta patch.

v10.01:

* Removed Pets from assignment pane, they can no longer receive buffs in WoW Forever and scale with gear now.
* Removed Last names from top of assignment pane under each class icon, so individual buff icons are visible next to each First name.
* Spell handler fix for Lua error. (It was trying to track cooldown for Lay on Hands and Divine Shield in combat which is blocked now outside CDM. It will now check after you get out of combat to refresh).
* Seal duration tracker removed, seals can no longer be tracked by addons in combat outside of CDM, which is useless since you swing them in combat. Seal button only tracks Righteous Fury. (Go to Options > Buttons > Seal Button/Righteous Fury to disable/enable).

v9.30.2:

* Lua error fixes.  Some reported minor errors, did some cleanup.

v9.30.1:

* Added shamans to assignment list, they were missing since originally Alliance didn't have shamans, and horde didn't have paladins.  Works for both now, and has a pet assignment as well.

Original changes v9.30:

* Ported over to Forever Beta
* Fixed First Name / Last Name format for Forever
* Added Seal of Fury for Protection (New Seal in Forever)
