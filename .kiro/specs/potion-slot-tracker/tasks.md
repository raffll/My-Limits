# Implementation Plan: Potion Slot Tracker

## Overview

Add an alternative "slots" potion tracking mode to the SPT Limits mod. Implementation proceeds bottom-up: config defaults → settings definitions → l10n keys → player.lua slot logic → global.lua mode awareness → slotCounter.lua HUD → counter.lua mode gate → omwscripts registration. Each step builds on the previous, ending with full wiring.

## Tasks

- [x] 1. Add config defaults and settings definitions
  - [x] 1.1 Add new default values to config.lua
    - Add `potionTrackingMode = "counter"` and `potionSlotCount = 4` to the config return table
    - _Requirements: 1.1, 12.1_

  - [x] 1.2 Add new setting definitions to settings.lua
    - Add `potionTrackingMode` definition (select renderer, options "counter"/"slots", group sptLimitsPotions, order 1)
    - Add `potionSlotCount` definition (number renderer, min 1, max 10, group sptLimitsPotions, order 2)
    - Shift existing `potionLimit` order to 3, `potionCooldown` to 4, `hudCounterEnabled` to 5, `excludeSunsDusk` to 6
    - Add `"sptLimitsPotions"` group subscription for the new keys
    - _Requirements: 1.2, 12.1, 12.4_

  - [x] 1.3 Add new l10n keys to en.yaml
    - Add `settingPotionTrackingModeName`, `settingPotionTrackingModeDesc`, `settingPotionSlotCountName`, `settingPotionSlotCountDesc`
    - _Requirements: 1.2_

- [x] 2. Implement Slot Tracker logic in player.lua
  - [x] 2.1 Add slot state initialization and helper functions
    - Add `state.slots` array, `state.potionTrackingMode` tracking
    - Implement `initSlots()` — creates `potionSlotCount + 1` empty entries (activeSpellId nil, countdown 0)
    - Implement `getOccupiedNormalCount()` — returns count of occupied normal slots
    - Implement `isOverflowOccupied()` — returns whether overflow slot is occupied
    - Gate existing counter logic behind `potionTrackingMode == "counter"` check
    - _Requirements: 2.1, 3.1, 11.1, 11.2, 11.3, 12.2, 12.5_

  - [x] 2.2 Implement slot assignment and overflow logic
    - Implement `assignDrinkToSlot(activeSpellId, longestDuration)` — finds lowest-index empty normal slot, assigns drink
    - Implement `assignDrinkToOverflow(activeSpellId, longestDuration)` — assigns to overflow slot, triggers overdose (knockedOut=true, fatigue=-1, overdose message)
    - Handle case where all slots (normal + overflow) are occupied — ignore drink
    - _Requirements: 3.1, 3.2, 4.1, 4.2, 4.3, 4.4, 7.3, 9.1_

  - [x] 2.3 Implement per-slot countdown tick and validation
    - Implement `tickSlots(dt)` — decrements each occupied slot's countdown by dt, clamps to 0, marks expired slots empty
    - Implement `validateSlots(activeSpells)` — checks each occupied slot's activeSpellId still exists; clears if gone
    - Handle overflow slot expiry → recovery (restore fatigue, set knockedOut=false)
    - Ensure slots tick independently and positions never shift
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 9.2, 9.3, 9.4_

  - [x] 2.4 Implement slot storage writes and state event dispatch
    - Implement `writeSlotStorage()` — writes trackingMode, slotCount, slot{i}Countdown keys, occupiedSlots, overflowOccupied to storage.playerSection("sptLimitsState")
    - Send `sptLimitsStateUpdate` event with knockedOut, allNormalSlotsFull, potionTrackingMode to global script
    - Use lastSent pattern to avoid redundant writes/events
    - _Requirements: 14.1, 14.3, 15.1, 15.2, 15.3, 15.5, 15.6, 15.7_

  - [x] 2.5 Integrate slot logic into onUpdate handler
    - Add mode branch in onUpdate: if "slots" → run slot detection, tick, validate, storage write, state event
    - Reuse existing activeSpell iteration pattern for drink detection (new activeSpellId = new drink)
    - Compute longestDuration from spell.effects for each new drink
    - Excluded potions bypass slot assignment (track in knownPotionSpellIds only)
    - _Requirements: 1.3, 1.4, 3.1, 3.2, 8.3, 11.1, 11.2, 11.3_

  - [x] 2.6 Implement mode switch handling and save/load
    - In settings.subscribe callback: handle potionTrackingMode change — reset to clean state for new mode
    - In onSave: persist slot array when mode is "slots", omit slot data when mode is "counter"
    - In onLoad: restore slots from save data, validate activeSpellIds against active spells, pad/truncate to potionSlotCount+1
    - Handle corrupted save data defensively (nil slots, malformed entries, invalid types)
    - _Requirements: 1.7, 1.8, 1.9, 2.2, 2.3, 2.4, 7.4, 13.1, 13.2, 13.3, 13.4, 13.5, 13.6, 13.7, 13.8_

- [x] 3. Implement global script mode awareness
  - [x] 3.1 Extend global.lua state cache and ItemUsage handler
    - Add `allNormalSlotsFull` and `potionTrackingMode` to playerState cache
    - Modify ItemUsage potion handler: when mode is "slots", check `allNormalSlotsFull` instead of `drinkOverdose`
    - When `allNormalSlotsFull` is true and player is not knocked out, send `cantDrinkMore` message and return false
    - When `knockedOut` is true in slots mode, send `cantDrinkNow` message and return false
    - Update `sptLimitsStateUpdate` event handler to accept new fields (allNormalSlotsFull, potionTrackingMode)
    - _Requirements: 8.1, 8.2, 8.4, 16.1, 16.2, 16.3, 16.4_

- [x] 4. Implement Slot HUD (slotCounter.lua)
  - [x] 4.1 Create slotCounter.lua MENU script
    - Create new file `scripts/sptLimits/slotCounter.lua`
    - Read `trackingMode`, `slotCount`, per-slot countdowns, `overflowOccupied` from storage.playerSection("sptLimitsState")
    - Read `hudCounterEnabled` and `potionLimitEnabled` from storage.playerSection("sptLimitsPotions")
    - If mode is not "slots" or hudCounterEnabled is false or potionLimitEnabled is false: hide all elements
    - Create slotCount+1 text elements positioned vertically from bottom-right (slot 1 at same position as counter.lua element)
    - Occupied slots show countdown formatted as "%.1fs" (e.g. "12.3s"); empty slots hidden
    - Overflow slot uses red color to indicate overdose state
    - Update every frame via onFrame handler
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8, 10.9, 10.10, 15.4_

- [x] 5. Modify counter.lua mode gate
  - [x] 5.1 Add mode check to counter.lua
    - Read `trackingMode` from storage.playerSection("sptLimitsState")
    - If trackingMode is "slots", hide the counter element and skip updates
    - _Requirements: 1.5, 1.6_

- [x] 6. Register new script and final wiring
  - [x] 6.1 Update SPT Limits.omwscripts
    - Add `MENU: scripts/sptLimits/slotCounter.lua` line between counter.lua and global.lua registrations
    - _Requirements: 10.1_

## Notes

- Each task references specific requirements for traceability
- The design uses Lua throughout — all code examples and implementations use Lua
- Config values are defaults only; runtime uses settings.get() per project conventions
- Interface version remains 1 per project conventions

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3"] },
    { "id": 4, "tasks": ["2.4", "2.5"] },
    { "id": 5, "tasks": ["2.6"] },
    { "id": 6, "tasks": ["3.1"] },
    { "id": 7, "tasks": ["4.1", "5.1"] },
    { "id": 8, "tasks": ["6.1"] }
  ]
}
```
