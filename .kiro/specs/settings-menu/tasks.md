# Implementation Plan

## Overview

Implement an in-game settings menu for SPT Limits using OpenMW's `openmw.interfaces.Settings` framework. All config toggles and numeric limits become adjustable per player during gameplay, persisted via `storage.playerSection`, and propagated to GLOBAL (via events) and MENU (via storage reads).

## Tasks

- [x] 1. Create Settings Module (`scripts/sptLimits/settings.lua`)
  - [x] 1.1 Create file with setting definitions (keys, types, defaults from config, min/max bounds, renderer types, group assignments, l10n keys)
  - [x] 1.2 Implement `settings.get(key)` that reads from `storage.playerSection("sptLimitsSettings")` and falls back to `config.lua` default if nil
  - [x] 1.3 Implement `settings.registerPage()` that registers the page and three groups (Potions, Stats, Training) via `openmw.interfaces.Settings`
  - [x] 1.4 Implement `settings.subscribe(callback)` that subscribes to storage section changes and invokes callbacks with `(key, newValue)`
  - [x] 1.5 Add numeric bounds clamping in `settings.get()` — clamp returned values to defined min/max

- [x] 2. Add Localization Entries
  - [x] 2.1 Add page title entry: `settingsTitle`
  - [x] 2.2 Add group title entries: `settingsPotionsTitle`, `settingsStatsTitle`, `settingsTrainingTitle`
  - [x] 2.3 Add name and description entries for each of the 10 settings

- [x] 3. Modify player.lua to Use Settings Module
  - [x] 3.1 Replace all static `config.*` references for runtime-changeable values with `settings.get("key")` calls
  - [x] 3.2 Call `settings.registerPage()` in the `onInit` engine handler
  - [x] 3.3 Subscribe to settings changes; on `trainingLimitEnabled` toggle: call `unblockTrainingWindow()` when false, re-evaluate and call `blockTrainingWindow()` when true and limit reached
  - [x] 3.4 Send `sptLimitsSettingsUpdate` event to GLOBAL on init, on load, and whenever `potionLimitEnabled`, `statLimitEnabled`, or `excludeSunsDusk` changes
  - [x] 3.5 Update the `potionLimit` value written to `sptLimitsState` storage to come from `settings.get("potionLimit")`
  - [x] 3.6 In `handleKnockoutRecovery`, skip the `interfaces.UI.setMode()` call when the current UI mode is the Settings/Options screen (Requirement 11)

- [x] 4. Modify global.lua to Use Cached Settings
  - [x] 4.1 Add local `settingsCache` table initialized from config defaults
  - [x] 4.2 Add `sptLimitsSettingsUpdate` event handler that updates `settingsCache` with received values
  - [x] 4.3 Replace `config.potionLimitEnabled` and `config.statLimitEnabled` reads in ItemUsage handlers with `settingsCache` values
  - [x] 4.4 Pass `settingsCache.excludeSunsDusk` to `isPotionExcluded` calls

- [x] 5. Modify exclusions.lua for Runtime excludeSunsDusk
  - [x] 5.1 Add optional `excludeSunsDuskOverride` parameter to `isPotionExcluded(id, excludeSunsDuskOverride)`
  - [x] 5.2 When override is non-nil, use it instead of `config.excludeSunsDusk` for the Sun's Dusk interface check
  - [x] 5.3 Ensure backward compatibility — when called without the parameter, behavior is unchanged

- [x] 6. Modify counter.lua for Dynamic Settings
  - [x] 6.1 Remove the top-level early-return guard (`if not config.potionLimitEnabled or not config.hudCounterEnabled`)
  - [x] 6.2 Always create the HUD element (initially hidden)
  - [x] 6.3 In `tick()`, read `hudCounterEnabled` and `potionLimitEnabled` from `storage.playerSection("sptLimitsSettings")`
  - [x] 6.4 Hide the HUD element when either setting is false or drinkCount is 0; show otherwise
  - [x] 6.5 Read `potionLimit` from settings storage for the counter display format string

- [x] 7. Verify and Test
  - [x] 7.1 Verify settings page appears in Options menu with three groups and all 10 settings
  - [x] 7.2 Verify toggling `potionLimitEnabled` off immediately allows unlimited potion drinking
  - [x] 7.3 Verify toggling `hudCounterEnabled` off immediately hides the HUD counter
  - [x] 7.4 Verify changing `potionLimit` numeric value is reflected in the next potion drink cycle
  - [x] 7.5 Verify toggling `trainingLimitEnabled` off unblocks the Training window
  - [x] 7.6 Verify settings persist across save/load
  - [x] 7.7 Verify first-time load with no stored settings uses config.lua defaults
  - [x] 7.8 Verify settings window stays open when knockout triggers while settings are active (Requirement 11)

## Task Dependency Graph

```
1 (settings module) ──► 3 (player.lua)
                    ──► 4 (global.lua)
                    ──► 6 (counter.lua)
2 (l10n) ──► 3 (player.lua)
5 (exclusions.lua) ──► 4 (global.lua)
3, 4, 5, 6 ──► 7 (verify)
```

## Notes

- `config.lua` remains the source of default values; it is not modified.
- `config.attributes`, `config.skills`, and `config.potions` (spell/pattern exclusion tables) are NOT exposed in the settings menu — they require list editing UI which is out of scope.
- The `SPT Limits.omwscripts` registration file does not need changes — settings registration happens inside the existing PLAYER script.
- Interface version stays at 1.
