# Requirements Document

## Introduction

This specification covers the complete rewrite of the "Stats & Potions Limit" OpenMW mod from a hybrid MWScript/Lua architecture to pure OpenMW Lua. The ESP file and all `world.mwscript.getGlobalVariables` references will be eliminated. All game logic currently handled by the `raffll_limits` MWScript will be reimplemented in Lua scripts using OpenMW's Lua API, with state persisted via Lua storage for proper save/load support.

## Glossary

- **Limit_Engine**: The core Lua player script that enforces attribute caps, skill caps, potion limits, knockout, and recovery logic (replaces the MWScript `raffll_limits` script)
- **Item_Blocker**: The Lua global script that intercepts item usage (potions, apparatus, repair, miscellaneous) and blocks usage during knockout state
- **Settings_Manager**: The Lua global script that registers and manages mod settings, broadcasting changes to the Limit_Engine via events
- **HUD_Counter**: The Lua menu script that displays the potion countdown timer and drink count on the player's HUD
- **Knockout_State**: The condition where the player's fatigue is set to zero and item usage is blocked because a limit has been exceeded
- **Overdose_State**: The condition triggered when the player drinks one potion beyond the maximum allowed count within a cooldown window
- **Progressive_Mode**: A settings-driven scaling mode where caps increase with player level
- **Cooldown_Window**: The 20-second timer that resets after each potion drink, during which subsequent drinks accumulate toward the limit
- **Icarian_Exception**: The special case where Acrobatics skill exceeding the cap does not trigger knockout if the Icarian Flight spell effect is active on the player

## Requirements

### Requirement 1: Eliminate MWScript Dependency

**User Story:** As a mod author, I want all game logic implemented in pure OpenMW Lua, so that the ESP file is no longer required and the mod is easier to maintain.

#### Acceptance Criteria

1. THE Limit_Engine SHALL implement all stat-capping, potion-counting, cooldown, knockout, and recovery logic without referencing `world.mwscript.getGlobalVariables`
2. THE Item_Blocker SHALL block item usage based on state communicated from the Limit_Engine via Lua events or storage, without referencing `world.mwscript.getGlobalVariables`
3. THE Settings_Manager SHALL communicate setting changes to the Limit_Engine via Lua events, without writing to MWScript global variables
4. THE HUD_Counter SHALL read countdown and drink-count data from Lua player storage relayed via events, without referencing MWScript globals

### Requirement 2: Attribute Cap Enforcement

**User Story:** As a player, I want my attributes capped at a defined maximum, so that the game maintains balanced difficulty.

#### Acceptance Criteria

1. WHILE the potionsOnly setting is disabled, THE Limit_Engine SHALL check all eight player attributes (Strength, Intelligence, Willpower, Agility, Speed, Endurance, Personality, Luck) against the attribute cap each frame
2. WHILE the progressiveStats setting is disabled, THE Limit_Engine SHALL use a fixed attribute cap of 300
3. WHILE the progressiveStats setting is enabled, THE Limit_Engine SHALL calculate the attribute cap as 100 + (playerLevel * 5), clamped to a maximum of 300
4. WHEN the attribute cap value changes (due to level-up or setting change) AND the player is NOT in Knockout_State, THE Limit_Engine SHALL display the MessageBox: `"Your attribute cap is now %G."` with the new cap value
5. WHEN any attribute exceeds the attribute cap AND the player is NOT already in Knockout_State, THE Limit_Engine SHALL display the MessageBox: `"You have reached your attribute limit!"` and enter Knockout_State

### Requirement 3: Skill Cap Enforcement

**User Story:** As a player, I want my skills capped at a defined maximum, so that the game maintains balanced difficulty.

#### Acceptance Criteria

1. WHILE the potionsOnly setting is disabled, THE Limit_Engine SHALL check all 27 player skills against the skill cap each frame
2. WHILE the progressiveStats setting is disabled, THE Limit_Engine SHALL use a fixed skill cap of 150
3. WHILE the progressiveStats setting is enabled, THE Limit_Engine SHALL calculate the skill cap as 100 + playerLevel, clamped to a maximum of 150
4. WHEN the skill cap value changes (due to level-up or setting change) AND the player is NOT in Knockout_State, THE Limit_Engine SHALL display the MessageBox: `"Your skill cap is now %G."` with the new cap value
5. WHEN any skill exceeds the skill cap AND the player is NOT already in Knockout_State, THE Limit_Engine SHALL display the MessageBox: `"You have reached your skill limit!"` and enter Knockout_State
6. WHILE the Icarian Flight spell effect (`sc_icarianflight_en`) is active on the player, THE Limit_Engine SHALL exclude Acrobatics from skill cap enforcement

### Requirement 4: Potion Limit Enforcement

**User Story:** As a player, I want a limit on how many potions I can drink in a short time, so that potion-stacking is prevented.

#### Acceptance Criteria

1. WHILE the progressivePotions setting is disabled, THE Limit_Engine SHALL use a fixed maximum potion count of 3
2. WHILE the progressivePotions setting is enabled, THE Limit_Engine SHALL calculate the maximum potion count as floor(playerLevel / 10) + 3, clamped between 3 and 8
3. WHEN the maximum potion count value changes (due to level-up or setting change) AND the player is NOT in Knockout_State, THE Limit_Engine SHALL display the MessageBox: `"You can drink up to %G potions."` with the new max count
4. WHEN the player drinks a potion, THE Limit_Engine SHALL increment the drink count and reset the cooldown timer to zero
5. WHEN the drink count exceeds the maximum potion count (first drink past the limit = overdose), THE Limit_Engine SHALL display the MessageBox: `"You have overdosed potions!"` and enter Knockout_State
6. WHEN the player drinks again while in Overdose_State (death), THE Limit_Engine SHALL display the MessageBox: `"You have died from the potion overdose!"` and set the player's health to zero
7. WHEN the cooldown timer reaches 20 seconds without another potion being consumed, THE Limit_Engine SHALL reset the drink count to zero and clear the potion limit state

### Requirement 5: Cooldown Timer and Hour-Skip Detection

**User Story:** As a player, I want the potion cooldown to expire naturally or when I rest/wait, so that the mechanic does not persist unreasonably.

#### Acceptance Criteria

1. WHILE the drink count is greater than zero and the game is not paused, THE Limit_Engine SHALL increment the cooldown timer by the elapsed frame time each frame
2. WHEN the game hour advances by more than one hour since the last potion was consumed (rest or wait), THE Limit_Engine SHALL immediately expire the cooldown timer
3. WHEN the cooldown timer expires, THE Limit_Engine SHALL reset the drink count to zero, clear the Knockout_State caused by potion overdose, and reset the timer

### Requirement 6: Knockout and Recovery

**User Story:** As a player, I want to be knocked out when I exceed limits and recover when I return below them, so that the penalty is temporary and fair.

#### Acceptance Criteria

1. WHEN the Limit_Engine enters Knockout_State, THE Limit_Engine SHALL set the player's fatigue to zero
2. WHILE the Limit_Engine is in Knockout_State and any limit is still exceeded, THE Limit_Engine SHALL keep the player's fatigue at zero each frame
3. WHEN all limits return below their caps while in Knockout_State, THE Limit_Engine SHALL display the MessageBox: `"You have fully recovered!"`, restore the player's fatigue to its base maximum (Strength + Willpower + Agility + Endurance), then drain current fatigue to zero, and exit Knockout_State
4. WHEN the Limit_Engine enters Knockout_State for the first time (transition from inactive to active), THE Limit_Engine SHALL close any open menu (equivalent to MenuTest behavior)

### Requirement 7: Item Usage Blocking During Knockout

**User Story:** As a player, I want item usage blocked during knockout, so that I cannot circumvent the penalty.

#### Acceptance Criteria

1. WHILE the Limit_Engine is in Knockout_State, THE Item_Blocker SHALL prevent the player from using potions and display the MessageBox: `"You can't drink potions right now."`
2. WHILE the Limit_Engine is in Knockout_State, THE Item_Blocker SHALL prevent the player from using apparatus and display the MessageBox: `"You can't create potions right now."`
3. WHILE the Limit_Engine is in Knockout_State, THE Item_Blocker SHALL prevent the player from using repair items and display the MessageBox: `"You can't repair right now."`
4. WHILE the Limit_Engine is in Knockout_State, THE Item_Blocker SHALL prevent the player from using miscellaneous items and display the MessageBox: `"You can't use this right now."`
5. WHEN the player attempts to drink a potion and the drink count has reached the overdose threshold (drinkCount >= maxCount), THE Item_Blocker SHALL prevent usage and display the MessageBox: `"You can't drink any more potions."`

### Requirement 8: HUD Countdown Display

**User Story:** As a player, I want to see a countdown timer and drink count on my HUD, so that I know how many potions I have consumed and when the cooldown expires.

#### Acceptance Criteria

1. WHILE the drink count is greater than zero, THE HUD_Counter SHALL display the remaining cooldown time (formatted to one decimal place) and the current drink count out of the maximum count
2. WHILE the drink count is zero, THE HUD_Counter SHALL hide the countdown display
3. THE HUD_Counter SHALL position the display at the bottom-right of the screen, matching the current layout

### Requirement 9: Settings Management

**User Story:** As a player, I want to configure the mod through the OpenMW settings UI, so that I can customize which limits are active.

#### Acceptance Criteria

1. THE Settings_Manager SHALL register three boolean settings: potionsOnly, progressivePotions, and progressiveStats
2. WHEN a setting value changes, THE Settings_Manager SHALL send an event to the Limit_Engine containing the updated setting key and value
3. THE Limit_Engine SHALL apply setting changes immediately upon receiving the event

### Requirement 10: State Persistence

**User Story:** As a player, I want the mod state to persist across save and load, so that my potion count and knockout status are not lost.

#### Acceptance Criteria

1. THE Limit_Engine SHALL save all runtime state (drink count, cooldown timer, active/knockout flag, last drink hour, current caps) using the onSave engine handler
2. WHEN a save is loaded, THE Limit_Engine SHALL restore all runtime state from the saved data using the onLoad engine handler
3. THE Limit_Engine SHALL initialize all state to default values (zero counts, inactive knockout) on a new game using the onInit engine handler

### Requirement 11: Script Registration

**User Story:** As a mod author, I want the omwscripts file to register all scripts correctly, so that the mod loads without the ESP file.

#### Acceptance Criteria

1. THE omwscripts file SHALL register the Limit_Engine as a PLAYER script
2. THE omwscripts file SHALL register the Item_Blocker as a GLOBAL script
3. THE omwscripts file SHALL register the Settings_Manager as a GLOBAL script
4. THE omwscripts file SHALL register the HUD_Counter and menu page as MENU scripts
5. THE omwscripts file SHALL NOT reference any ESP file or MWScript-dependent scripts

### Requirement 12: Exact Message Text Parity

**User Story:** As a mod author, I want all player-facing messages to use the exact same text as the original MWScript, so that the user experience is identical after the rewrite.

#### Acceptance Criteria

The following messages SHALL be displayed using the exact text shown, under the specified conditions:

| # | Condition | Message Text |
|---|-----------|-------------|
| 1 | Attribute cap value changes (not in knockout) | `"Your attribute cap is now %G."` (with cap value) |
| 2 | Skill cap value changes (not in knockout) | `"Your skill cap is now %G."` (with cap value) |
| 3 | Max potion count changes (not in knockout) | `"You can drink up to %G potions."` (with max count) |
| 4 | Any attribute exceeds cap (first detection, not in knockout) | `"You have reached your attribute limit!"` |
| 5 | Any skill exceeds cap (first detection, not in knockout) | `"You have reached your skill limit!"` |
| 6 | Potion overdose (drink count exceeds max) | `"You have overdosed potions!"` |
| 7 | Potion death (drink while in overdose state) | `"You have died from the potion overdose!"` |
| 8 | Recovery (all limits clear while in knockout) | `"You have fully recovered!"` |
| 9 | Potion blocked (knockout active) | `"You can't drink potions right now."` |
| 10 | Potion blocked (at overdose threshold) | `"You can't drink any more potions."` |
| 11 | Apparatus blocked (knockout active) | `"You can't create potions right now."` |
| 12 | Repair blocked (knockout active) | `"You can't repair right now."` |
| 13 | Miscellaneous blocked (knockout active) | `"You can't use this right now."` |

NOTE: Messages 1-5 are ONLY displayed when the player is NOT in Knockout_State (matching the original `r_active == 0` guard). Messages 4-5 are displayed once on the frame the limit is first detected (transition from no-limit to limit).
