# Design Document

## Overview

Adds an in-game settings menu to SPT Limits using OpenMW's built-in `openmw.interfaces.Settings` framework. Settings are persisted per-player via `storage.playerSection`, organized into three groups (Potions, Stats, Training), and propagated to all script contexts so the mod reacts immediately to changes.

## Architecture

### New Module: `scripts/sptLimits/settings.lua`

A shared settings module that:
- Defines all setting keys, their types, defaults (sourced from `config.lua`), renderer info, and validation bounds
- Provides a `get(key)` function that reads from `storage.playerSection("sptLimitsSettings")` with fallback to `config.lua` defaults
- Registers the settings page and groups via `openmw.interfaces.Settings` (called from PLAYER script context)
- Subscribes to storage changes and sends `sptLimitsSettingsUpdate` events to GLOBAL

### Storage Section

- Key: `"sptLimitsSettings"`
- Context: `storage.playerSection` (writable from PLAYER, readable from PLAYER + MENU)
- Each setting is stored under its camelCase config key name

### Settings Page Structure

```
Page: "sptLimits" (title: l10n "settingsTitle")
├── Group: "sptLimitsPotions" (title: l10n "settingsPotionsTitle")
│   ├── potionLimitEnabled (checkbox, default: true)
│   ├── potionLimit (number, min: 1, max: 99, default: 3)
│   ├── potionCooldown (number, min: 1, max: 300, default: 20)
│   ├── hudCounterEnabled (checkbox, default: true)
│   └── excludeSunsDusk (checkbox, default: true)
├── Group: "sptLimitsStats" (title: l10n "settingsStatsTitle")
│   ├── statLimitEnabled (checkbox, default: true)
│   ├── attributeCap (number, min: 1, max: 999, default: 300)
│   └── skillCap (number, min: 1, max: 999, default: 150)
└── Group: "sptLimitsTraining" (title: l10n "settingsTrainingTitle")
    ├── trainingLimitEnabled (checkbox, default: true)
    └── trainingLimit (number, min: 1, max: 99, default: 5)
```

### Inter-Script Communication

```
┌─────────────────────────────────────────────────────────┐
│ PLAYER script                                           │
│  ┌──────────────┐                                       │
│  │ settings.lua │──subscribe──► storage change callback  │
│  └──────────────┘              │                        │
│        │ get()                  │ sendGlobalEvent        │
│        ▼                        ▼                       │
│  player.lua reads          "sptLimitsSettingsUpdate"     │
│  settings.get(key)          → GLOBAL script             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ GLOBAL script                                           │
│  eventHandler: sptLimitsSettingsUpdate                   │
│  → updates local settingsCache table                    │
│  → ItemUsage handlers read from settingsCache           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ MENU script (counter.lua)                               │
│  reads storage.playerSection("sptLimitsSettings")       │
│  → checks hudCounterEnabled + potionLimitEnabled        │
│  → shows/hides HUD element accordingly                  │
└─────────────────────────────────────────────────────────┘
```

### Changes to Existing Files

#### `player.lua`
- Replace all `config.xxx` references with `settings.get("xxx")` for runtime-changeable values
- Keep `config.attributes` and `config.skills` (spell exclusion tables) as-is — these are not settings-menu items
- Keep `config.potions` as-is — pattern-based exclusion list is not a settings-menu item
- Register settings page on init (call `settings.registerPage()`)
- Subscribe to settings changes; on `trainingLimitEnabled` toggle, manage training window block state
- Send `sptLimitsSettingsUpdate` to GLOBAL on init, load, and whenever a relevant setting changes
- In `handleKnockoutRecovery`, skip the `interfaces.UI.setMode()` call when the current UI mode is the Settings/Options screen — the knockout still applies (fatigue collapse), but the settings window stays open so the player doesn't lose their place

#### `global.lua`
- Add `sptLimitsSettingsUpdate` event handler that caches `potionLimitEnabled`, `statLimitEnabled`, `excludeSunsDusk`
- Replace `config.potionLimitEnabled` / `config.statLimitEnabled` reads with cached values
- Pass cached `excludeSunsDusk` to `isPotionExcluded` (requires the exclusions module to accept it as a parameter)

#### `counter.lua`
- Read `hudCounterEnabled` and `potionLimitEnabled` from `storage.playerSection("sptLimitsSettings")` each frame
- Remove the early-return module guard that currently exits if disabled (since settings can change at runtime)
- Read `potionLimit` from settings storage for the counter display format

#### `exclusions.lua`
- Modify `isPotionExcluded` to accept an optional `excludeSunsDusk` parameter override (defaults to config value for backward compatibility)

#### `l10n/sptLimits/en.yaml`
- Add entries for: `settingsTitle`, `settingsPotionsTitle`, `settingsStatsTitle`, `settingsTrainingTitle`
- Add name/description entries for each setting (e.g., `settingPotionLimitEnabledName`, `settingPotionLimitEnabledDesc`)

#### `SPT Limits.omwscripts`
- No changes needed — settings registration happens inside the existing PLAYER script

## Correctness Properties

### Property 1: Default Fallback Consistency

For every setting key defined in the Settings_Module, when no value is stored in Settings_Storage, `settings.get(key)` returns the exact value from `config.lua` for that key.

- **Covers:** Requirement 7 (AC 7.1), Requirement 2 (AC 2.2), Requirement 3 (AC 3.4)
- **Type:** Property (holds for all defined setting keys)

### Property 2: Numeric Bounds Enforcement

For every numeric setting, the effective value returned by `settings.get(key)` is always within the defined minimum and maximum bounds, regardless of what value is stored.

- **Covers:** Requirement 3 (AC 3.2, 3.3)
- **Type:** Property (holds for all numeric inputs)

### Property 3: Storage Round-Trip

For every setting key, storing a valid value via `storage.playerSection("sptLimitsSettings"):set(key, value)` and then reading it back via `settings.get(key)` returns the same value.

- **Covers:** Requirement 9 (AC 9.1)
- **Type:** Round-trip property

### Property 4: HUD Visibility Invariant

The HUD counter element is visible only when all three conditions hold: `hudCounterEnabled` is true, `potionLimitEnabled` is true, and `drinkCount` is greater than zero. In all other combinations, the element is hidden.

- **Covers:** Requirement 6 (AC 6.1, 6.2, 6.3)
- **Type:** Property (holds for all boolean combinations)

### Property 5: Settings Event Contains Required Keys

Every `sptLimitsSettingsUpdate` event payload sent to GLOBAL contains exactly the keys `potionLimitEnabled`, `statLimitEnabled`, and `excludeSunsDusk`, each with a boolean value.

- **Covers:** Requirement 5 (AC 5.1)
- **Type:** Property (holds for every event emission)

## File Structure

```
scripts/sptLimits/
├── config.lua          (unchanged — remains source of defaults)
├── settings.lua        (NEW — settings definition, registration, get() accessor)
├── player.lua          (modified — uses settings.get(), registers page, sends events)
├── global.lua          (modified — handles sptLimitsSettingsUpdate, uses cached settings)
├── counter.lua         (modified — reads settings from storage each frame)
└── exclusions.lua      (modified — isPotionExcluded accepts excludeSunsDusk param)

l10n/sptLimits/
└── en.yaml             (modified — new settings l10n entries)
```

## API Design

### `settings.lua` Public Interface

```lua
local settings = require("scripts.sptLimits.settings")

-- Get current effective value for a setting (storage value or config default)
settings.get("potionLimit")  -- returns number
settings.get("statLimitEnabled")  -- returns boolean

-- Register the settings page (call once from PLAYER script onInit)
settings.registerPage()

-- Subscribe to changes (callback receives key, newValue)
settings.subscribe(function(key, newValue) ... end)
```

### Event: `sptLimitsSettingsUpdate`

```lua
-- Payload structure
{
    potionLimitEnabled = true,   -- boolean
    statLimitEnabled = true,     -- boolean
    excludeSunsDusk = true,      -- boolean
}
```

Sent from PLAYER to GLOBAL:
- On script init/load
- Whenever any of the three keys changes in storage
