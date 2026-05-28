# Requirements Document

## Introduction

In-game settings menu for the SPT Limits mod, allowing players to toggle features and adjust numeric limits during gameplay without editing `config.lua`. Settings are persisted per player via `storage.playerSection` and propagated to all script contexts (PLAYER, GLOBAL, MENU) so the mod reacts immediately to changes.

## Glossary

- **Settings_Page** — An OpenMW settings page registered via `openmw.interfaces.Settings`, appearing in the game's Options menu under the SPT Limits section.
- **Settings_Storage** — A `storage.playerSection` section holding the player's current setting values, readable by PLAYER and MENU scripts, writable by the PLAYER script.
- **Settings_Module** — A shared Lua module (`scripts/sptLimits/settings.lua`) that defines setting keys, defaults, and provides access to current values.
- **PLAYER_Script** — The player-context script (`scripts/sptLimits/player.lua`) responsible for stat checks, potion tracking, training limits, and settings registration.
- **GLOBAL_Script** — The global-context script (`scripts/sptLimits/global.lua`) responsible for ItemUsage handlers.
- **MENU_Script** — The menu-context script (`scripts/sptLimits/counter.lua`) responsible for the HUD potion counter.
- **Config_Module** — The existing `scripts/sptLimits/config.lua` module providing compile-time default values.

## Requirements

### Requirement 1: Settings Page Registration

**User Story:** As a player, I want to see an SPT Limits settings page in the game's Options menu, so that I can find and adjust all mod settings in one place.

#### Acceptance Criteria

1. WHEN the PLAYER_Script initializes, THE Settings_Page SHALL register a settings page with the key `"sptLimits"` via `openmw.interfaces.Settings`.
2. THE Settings_Page SHALL display a localized page title using the l10n key `"settingsTitle"`.
3. THE Settings_Page SHALL use `permanentStorage = false` so that settings are stored per-player rather than globally.
4. THE Settings_Page SHALL organize settings into three groups: Potions, Stats, and Training.
5. THE Potions group SHALL contain: `potionLimitEnabled`, `potionLimit`, `potionCooldown`, `hudCounterEnabled`, `excludeSunsDusk`.
6. THE Stats group SHALL contain: `statLimitEnabled`, `attributeCap`, `skillCap`.
7. THE Training group SHALL contain: `trainingLimitEnabled`, `trainingLimit`.

### Requirement 2: Toggle Settings

**User Story:** As a player, I want to toggle individual mod features on or off during gameplay, so that I can customize which limits apply to my character.

#### Acceptance Criteria

1. THE Settings_Page SHALL expose the following boolean settings with checkbox renderers: `potionLimitEnabled`, `statLimitEnabled`, `trainingLimitEnabled`, `hudCounterEnabled`, `excludeSunsDusk`.
2. WHEN the Settings_Page loads, THE Settings_Module SHALL use the corresponding value from Config_Module as the default for each toggle.
3. WHEN a player changes a toggle value, THE Settings_Storage SHALL persist the new value immediately.

### Requirement 3: Numeric Limit Settings

**User Story:** As a player, I want to adjust numeric limits (caps, cooldowns, session counts) during gameplay, so that I can fine-tune difficulty to my preference.

#### Acceptance Criteria

1. THE Settings_Page SHALL expose the following numeric settings with number renderers: `attributeCap`, `skillCap`, `potionLimit`, `trainingLimit`, `potionCooldown`.
2. THE Settings_Page SHALL enforce the following minimum values: `attributeCap` minimum 1, `skillCap` minimum 1, `potionLimit` minimum 1, `trainingLimit` minimum 1, `potionCooldown` minimum 1.
3. THE Settings_Page SHALL enforce the following maximum values: `attributeCap` maximum 999, `skillCap` maximum 999, `potionLimit` maximum 99, `trainingLimit` maximum 99, `potionCooldown` maximum 300.
4. WHEN the Settings_Page loads, THE Settings_Module SHALL use the corresponding value from Config_Module as the default for each numeric setting.
5. WHEN a player changes a numeric value, THE Settings_Storage SHALL persist the new value immediately.

### Requirement 4: Settings Propagation to PLAYER_Script

**User Story:** As a player, I want the mod to react immediately when I change a setting, so that I do not need to reload the game for changes to take effect.

#### Acceptance Criteria

1. WHEN a setting value changes in Settings_Storage, THE PLAYER_Script SHALL read the updated value on the next frame via the Settings_Module.
2. THE PLAYER_Script SHALL use Settings_Module values instead of Config_Module values for all runtime checks (stat caps, potion limit, cooldown, training limit, feature toggles).
3. WHEN `trainingLimitEnabled` changes from true to false, THE PLAYER_Script SHALL call `unblockTrainingWindow` to restore the default Training window.
4. WHEN `trainingLimitEnabled` changes from false to true, THE PLAYER_Script SHALL re-evaluate the training count and call `blockTrainingWindow` if the limit is already reached.

### Requirement 5: Settings Propagation to GLOBAL_Script

**User Story:** As a player, I want the global item-usage blocking to respect my current settings, so that toggling potion limits off immediately allows me to drink freely.

#### Acceptance Criteria

1. WHEN a setting value changes in Settings_Storage, THE PLAYER_Script SHALL send an `sptLimitsSettingsUpdate` event to GLOBAL_Script containing the current values of `potionLimitEnabled`, `statLimitEnabled`, and `excludeSunsDusk`.
2. WHEN the GLOBAL_Script receives an `sptLimitsSettingsUpdate` event, THE GLOBAL_Script SHALL update its local settings cache with the received values.
3. THE GLOBAL_Script SHALL use the locally cached setting values for all ItemUsage handler decisions.
4. WHEN the PLAYER_Script initializes or loads a save, THE PLAYER_Script SHALL send the current settings to GLOBAL_Script via `sptLimitsSettingsUpdate`.

### Requirement 6: Settings Propagation to MENU_Script (HUD Counter)

**User Story:** As a player, I want the HUD potion counter to appear or disappear immediately when I toggle it in settings, so that I get instant visual feedback.

#### Acceptance Criteria

1. THE MENU_Script SHALL read `hudCounterEnabled` and `potionLimitEnabled` from Settings_Storage on each frame.
2. WHEN `hudCounterEnabled` is false or `potionLimitEnabled` is false, THE MENU_Script SHALL hide the HUD counter element.
3. WHEN `hudCounterEnabled` is true and `potionLimitEnabled` is true and the drink count is greater than zero, THE MENU_Script SHALL show the HUD counter element.

### Requirement 7: Default Value Fallback

**User Story:** As a player loading the mod for the first time, I want the mod to behave identically to the current static config, so that the settings menu does not change the default experience.

#### Acceptance Criteria

1. WHEN Settings_Storage contains no value for a setting key, THE Settings_Module SHALL return the corresponding default from Config_Module.
2. THE Settings_Module SHALL provide a single function or table that returns the current effective value for any setting key, abstracting the storage-with-fallback logic.

### Requirement 8: Localization

**User Story:** As a player, I want all settings labels and descriptions to be localized, so that the settings menu is readable in my language.

#### Acceptance Criteria

1. THE Settings_Page SHALL use l10n keys from the `"sptLimits"` namespace for all setting names and descriptions.
2. THE l10n file (`l10n/sptLimits/en.yaml`) SHALL contain English entries for the page title, each setting name, and each setting description.

### Requirement 9: Settings Persistence Across Sessions

**User Story:** As a player, I want my settings to be saved with my character, so that I do not need to reconfigure the mod every time I load a save.

#### Acceptance Criteria

1. THE Settings_Storage SHALL persist setting values as part of the player save data via `storage.playerSection`.
2. WHEN a save is loaded, THE Settings_Module SHALL read persisted values from Settings_Storage and make them available to all consuming scripts on the first frame.

### Requirement 10: Exclusion Toggle Propagation

**User Story:** As a player, I want the Sun's Dusk exclusion toggle to take effect immediately, so that toggling it off starts counting those potions toward my limit right away.

#### Acceptance Criteria

1. WHEN `excludeSunsDusk` changes in Settings_Storage, THE PLAYER_Script SHALL use the updated value for all subsequent potion exclusion checks.
2. WHEN `excludeSunsDusk` changes in Settings_Storage, THE PLAYER_Script SHALL send the updated value to GLOBAL_Script via `sptLimitsSettingsUpdate`.
3. THE GLOBAL_Script SHALL use the received `excludeSunsDusk` value when evaluating `isPotionExcluded` in ItemUsage handlers.

### Requirement 11: Settings Window Stays Open During Knockout

**User Story:** As a player, I want the settings window to remain open if a knockout triggers while I am adjusting settings, so that I do not lose my place in the menu.

#### Acceptance Criteria

1. WHEN a knockout triggers (stat limit exceeded or overdose collapse) while the Settings_Page is the active UI mode, THE PLAYER_Script SHALL NOT call `interfaces.UI.setMode()` to close all windows.
2. THE knockout state (fatigue collapse) SHALL still apply normally — only the `setMode()` call is suppressed.
3. WHEN the player closes the Settings_Page manually after a knockout triggered while it was open, THE player SHALL see themselves in the collapsed state.
