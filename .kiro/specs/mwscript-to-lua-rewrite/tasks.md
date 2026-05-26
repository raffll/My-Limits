# Tasks

## Task 1: Create the Limit_Engine player script (player.lua)

- [x] 1.1 Create `scripts/raffll_limits/player.lua` with module requires (openmw.core, openmw.self, openmw.types, openmw.ui, openmw.storage, openmw.interfaces)
- [x] 1.2 Implement state initialization in onInit handler (active=false, drinkCount=0, timer=0, drinkHour=0, all settings=false, cap tracking vars)
- [x] 1.3 Implement onSave handler that returns serializable state table (active, drinkCount, timer, drinkHour, potionsOnly, progressivePotions, progressiveStats)
- [x] 1.4 Implement onLoad handler that restores saved state and recomputes caps from current player level
- [x] 1.5 Implement cap computation functions: computeAttributeCap(level, progressive), computeSkillCap(level, progressive), computeMaxPotions(level, progressive)
- [x] 1.6 Implement attribute checking logic: iterate all 8 attributes, compare against cap, return limitAttribute boolean
- [x] 1.7 Implement skill checking logic: iterate all 27 skills, compare against cap, skip Acrobatics if Icarian Flight active, return limitSkill boolean
- [x] 1.8 Implement Icarian Flight detection using types.Actor.activeSpells or activeEffects to check for "sc_icarianflight_en"
- [x] 1.9 Implement potion timer logic: accumulate dt, hour-skip detection (compare current GameHour to drinkHour, expire if delta > 1), expiry at 20s resets state
- [x] 1.10 Implement knockout/recovery state machine: transitions between active/inactive based on limit flags, fatigue manipulation, menu close, recovery message
- [x] 1.11 Implement potionConsumed event handler: reset timer, increment drinkCount, check overdose (maxCount+1) and death (maxCount+2) thresholds
- [x] 1.12 Implement settingChanged event handler: update local settings state from event data
- [x] 1.13 Implement onUpdate combining all per-frame logic: compute caps, notify changes, check stats, update timer, determine limits, handle knockout/recovery
- [x] 1.14 Implement storage write: each frame write active, drinkCount, maxCount, countdown, drinkOverdose to playerSection('raffll_limits_state')
- [x] 1.15 Wire up engineHandlers (onInit, onSave, onLoad, onUpdate) and eventHandlers (potionConsumed, raffll_limits_settingChanged) in the return table

## Task 2: Rewrite the Item_Blocker global script (global.lua)

- [x] 2.1 Remove all world.mwscript.getGlobalVariables references from global.lua
- [x] 2.2 Implement Potion handler: skip non-players, read player storage raffll_limits_state, block if active (message), block if drinkOverdose (different message), otherwise send potionConsumed event to player
- [x] 2.3 Implement Apparatus handler: read player storage, block if active with message
- [x] 2.4 Implement Repair handler: read player storage, block if active with message
- [x] 2.5 Implement Miscellaneous handler: read player storage, block if active with message
- [x] 2.6 Remove the onUpdate handler that relayed MWScript globals to storage (no longer needed)

## Task 3: Rewrite the Settings_Manager global script (settings.lua)

- [x] 3.1 Remove all world.mwscript.getGlobalVariables references from settings.lua
- [x] 3.2 Replace setPotionsOnly/setProgressivePotions/setProgressiveStats functions to send events to player instead of writing MWScript globals
- [x] 3.3 Implement event sending: on setting change, iterate world.players and send raffll_limits_settingChanged event with key and value
- [x] 3.4 Send initial setting values as events on script load (so player script receives current settings on game start)

## Task 4: Update the HUD_Counter menu script (counter.lua)

- [x] 4.1 Change storage read from globalSection('raffll_limits') to playerSection('raffll_limits_state')
- [x] 4.2 Update field names to match new storage schema (countdown, drinkCount, maxCount)
- [x] 4.3 Compute countdown display value as (20 - timer) or use the countdown field written by Limit_Engine

## Task 5: Update the omwscripts registration file

- [x] 5.1 Add `PLAYER: scripts/raffll_limits/player.lua` to `Stats & Potions Limit.omwscripts`
- [x] 5.2 Verify GLOBAL entries for global.lua and settings.lua remain
- [x] 5.3 Verify MENU entries for menu.lua and counter.lua remain
- [x] 5.4 Remove any ESP-related omwscripts file (`Stats & Potions Limit.omwscripts.esp`) or references

## Task 6: Clean up deprecated files

- [x] 6.1 Delete or archive `Stats & Potions Limit.esp` (no longer needed)
- [x] 6.2 Delete `Stats & Potions Limit.omwscripts.esp` if it was only for ESP-bound scripts
- [x] 6.3 Update README.md to reflect that no ESP is required

## Task 7: Integration verification

- [~] 7.1 Verify the mod loads in OpenMW without errors (check openmw.log for script loading)
- [~] 7.2 Test potion drinking sequence: drink potions up to limit, verify HUD counter, verify cooldown expiry
- [~] 7.3 Test attribute/skill cap enforcement: use console to set stats above cap, verify knockout triggers
- [~] 7.4 Test overdose and death: drink beyond limit, verify overdose message and knockout, then death
- [~] 7.5 Test settings changes: toggle potionsOnly/progressive modes, verify behavior changes immediately
- [~] 7.6 Test save/load: save during active cooldown, reload, verify state persists
- [~] 7.7 Test hour-skip: rest/wait during cooldown, verify timer expires early
- [~] 7.8 Test Icarian Flight exception: apply spell, verify Acrobatics over cap does not trigger knockout
