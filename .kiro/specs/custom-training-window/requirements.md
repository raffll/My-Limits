# Requirements Document

## Introduction

Provide an opt-in custom Training window that replaces the built-in OpenMW Training window with a Lua implementation using `interfaces.UI.registerWindow`. The replacement must be visually identical to the original C++ window and replicate all vanilla training behavior, while natively integrating the mod's per-level training limit system. When enabled, this eliminates the current `removeMode` hack and its one-frame flash artifact. When disabled (the default), the existing `removeMode` approach in `training.lua` remains active and unchanged.

## Glossary

- **Training_Window** — The custom Lua UI window that replaces the built-in Training mode window (only active when the Custom_Training_Window_Toggle is enabled)
- **Custom_Training_Window_Toggle** — A boolean setting (`customTrainingWindow`) that controls whether the custom Lua Training window is used (true) or the existing removeMode approach handles training limits (false, the default)
- **RemoveMode_Approach** — The existing training limit enforcement in `training.lua` that uses `UiModeChanged` + `removeMode("Training")` + `removeMode("Dialogue")` to block training when the limit is reached
- **Trainer** — The NPC actor passed as the `actor` argument to the `showFn` callback
- **Player** — The player character controlled by the user
- **Skill_Option** — A clickable row in the Training_Window representing one trainable skill
- **Training_Limit** — The maximum number of training sessions allowed per player level, configurable via mod settings
- **Base_Skill** — The player's unmodified skill value (without temporary buffs/debuffs)
- **Governing_Attribute** — The attribute that governs a given skill, capping the maximum trainable level
- **Barter_Offer** — The engine's price calculation function that adjusts raw cost based on disposition, mercantile, fatigue, and luck
- **Time_Advancer** — The mechanism that advances game time by 2 hours after training, with progress bar and fade effects
- **Gold_Pool** — The NPC's internal gold reserve that accumulates training payments (separate from inventory gold)

## Requirements

### Requirement 1: Window Registration

**User Story:** As a mod author, I want to register a custom Training window via the OpenMW UI interface, so that the built-in C++ Training window is fully replaced when the toggle is enabled.

#### Acceptance Criteria

1. WHEN the player script initializes and the Custom_Training_Window_Toggle is enabled, THE Training_Window SHALL register itself using `interfaces.UI.registerWindow("Training", showFn, hideFn)`
2. WHEN the player script initializes and the Custom_Training_Window_Toggle is disabled, THE Training_Window SHALL not call `interfaces.UI.registerWindow` and SHALL leave the built-in Training window intact
3. WHEN the engine triggers Training mode and the Custom_Training_Window_Toggle is enabled, THE Training_Window SHALL receive the Trainer actor as the argument to `showFn`
4. WHEN `hideFn` is called by the engine, THE Training_Window SHALL destroy its UI element if one exists, and take no action if the element has already been destroyed
5. WHILE the Time_Advancer is running and the engine calls `showFn` again, THE Training_Window SHALL not create a new dialog and SHALL show only the progress bar
6. IF `showFn` is called with a nil or invalid actor argument, THEN THE Training_Window SHALL not create a UI element and SHALL remove the Training mode

### Requirement 2: Window Layout

**User Story:** As a player, I want the custom Training window to look identical to the original, so that the replacement is seamless.

#### Acceptance Criteria

1. THE Training_Window SHALL use the MW_Dialog skin with dimensions 320x200 pixels
2. THE Training_Window SHALL display the title "#{sServiceTrainingTitle}" centered at position (6, 3) with size 300x24 using NormalText skin with center text alignment
3. THE Training_Window SHALL display the subtitle "#{sTrainingServiceTitle}" left-aligned at position (6, 22) with size 300x24 using SandText skin
4. THE Training_Window SHALL display a skill options container using MW_Box skin at position (6, 42) with size 300x115
5. THE Training_Window SHALL display the player's current gold formatted as "#{sGold}: <amount>" using SandText skin at position (6, 161) with size 200x24 and left text alignment
6. THE Training_Window SHALL display an auto-sized button using MW_Button skin at position (246, 161) with caption "#{Interface:OK}" that expands leftward, anchored to the right edge of the window
7. WHEN the Training_Window is created, THE Training_Window SHALL center itself on the screen

### Requirement 3: Skill Selection Display

**User Story:** As a player, I want to see the trainer's best skills offered for training, so that I can choose which skill to improve.

#### Acceptance Criteria

1. WHEN the Training_Window opens, THE Training_Window SHALL display up to 3 Skill_Options representing the Trainer's highest-valued skills selected from all 27 skills, sorted by value in descending order
2. WHEN multiple skills have equal value, THE Training_Window SHALL preserve content file order using a stable sort
3. WHEN the `game.mTrainersTrainingSkillsBasedOnBaseSkill` setting is enabled, THE Training_Window SHALL use the Trainer's base skill values for sorting and comparison
4. WHEN the `game.mTrainersTrainingSkillsBasedOnBaseSkill` setting is disabled, THE Training_Window SHALL use the Trainer's modified skill values for sorting and comparison
5. THE Training_Window SHALL display each Skill_Option as a button with the skill name followed by " - " and the training price followed by the gold piece suffix "#{sgp}"
6. THE Training_Window SHALL position each Skill_Option at x=4 within the options container, with a 0-based index y offset of (3 + index * lineHeight) where lineHeight is the current font size plus 2 pixels
7. THE Training_Window SHALL size each Skill_Option button width to its text width plus 12 pixels
8. IF the Trainer has fewer than 3 skills with a value greater than 0, THEN THE Training_Window SHALL display only the skills with value greater than 0

### Requirement 4: Price Calculation

**User Story:** As a player, I want training prices to match vanilla Morrowind pricing, so that the economy is unchanged.

#### Acceptance Criteria

1. THE Training_Window SHALL calculate the raw training price as the Player's Base_Skill level for that skill multiplied by the `iTrainingMod` game setting integer value
2. IF the raw price calculation results in a value less than 1, THEN THE Training_Window SHALL use a minimum raw price of 1
3. THE Training_Window SHALL apply the Barter_Offer adjustment to the raw price using the Trainer as the merchant and `buying=true`, rounding down to the nearest integer, to produce the final displayed price
4. IF the Barter_Offer adjustment produces a final price less than 1, THEN THE Training_Window SHALL use a minimum final price of 1

### Requirement 5: Skill Affordability Display

**User Story:** As a player, I want to clearly see which skills I cannot afford, so that I can make informed training choices.

#### Acceptance Criteria

1. WHEN the Player's gold is less than the final training price for a Skill_Option, THE Training_Window SHALL display that Skill_Option using the "SandTextButtonDisabled" skin
2. WHEN the Player's gold is greater than or equal to the final training price for a Skill_Option, THE Training_Window SHALL display that Skill_Option using the "SandTextButton" skin
3. WHEN the Player's gold is less than the final training price for a Skill_Option, THE Training_Window SHALL still allow tooltip display on hover for that Skill_Option

### Requirement 6: Training Validation

**User Story:** As a player, I want training to enforce the same rules as vanilla Morrowind, so that exploits are prevented.

#### Acceptance Criteria

1. WHEN the Player clicks a Skill_Option and the Player's gold is less than the training price, THE Training_Window SHALL ignore the click and the Training_Window SHALL remain open
2. WHEN the Player clicks a Skill_Option and the Player's gold is sufficient but the Trainer's skill value (base or modified per the `game.mTrainersTrainingSkillsBasedOnBaseSkill` setting) is less than or equal to the Player's Base_Skill, THE Training_Window SHALL display the message "#{sServiceTrainingWords}" and remain open without initiating training
3. WHEN the Player clicks a Skill_Option and the Player's gold is sufficient and the Trainer's skill exceeds the Player's Base_Skill but the Player's Base_Skill is greater than or equal to the Governing_Attribute's modified value, THE Training_Window SHALL display the message "#{sNotifyMessage17}" and remain open without initiating training
4. THE Training_Window SHALL evaluate validation checks in this order: gold check first, then Trainer skill versus Player Base_Skill, then Governing_Attribute cap

### Requirement 7: Training Execution

**User Story:** As a player, I want successful training to produce all vanilla side effects, so that training behaves identically to the original.

#### Acceptance Criteria

1. WHEN all validation passes, THE Training_Window SHALL call `interfaces.SkillProgression.skillLevelUp` with source `interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer` for the selected skill
2. IF `skillLevelUp` is cancelled by an external handler returning false, THEN THE Training_Window SHALL abort the training session without removing gold or triggering any side effects
3. WHEN training succeeds, THE Training_Window SHALL remove the training price in gold from the Player's inventory and add the training price in gold to the Trainer's Gold_Pool
4. WHEN training succeeds, THE Training_Window SHALL hide the window and show a progress bar
5. WHEN training succeeds, THE Training_Window SHALL trigger a screen fade-out over 0.2 seconds followed by a fade-in over 0.2 seconds with a 0.2 second delay between them
6. WHEN the progress bar completes, THE Training_Window SHALL call rest for 2 hours with sleeping set to false and advance game time by 2 hours
7. WHEN the time advancement finishes, THE Training_Window SHALL remove the Training mode and close the window

### Requirement 8: Progress Bar

**User Story:** As a player, I want to see a progress bar during training time advancement, so that I know training is in progress.

#### Acceptance Criteria

1. WHEN training begins, THE Training_Window SHALL display a progress bar that advances from 0 to completion over a real-time duration matching the screen fade timing (approximately 0.4 seconds total)
2. WHILE the progress bar is active, THE Training_Window SHALL hide the main training dialog
3. WHEN the progress bar completes, THE Training_Window SHALL hide the progress bar

### Requirement 9: Training Limit Integration

**User Story:** As a player, I want the training limit to be enforced natively in the custom window when the toggle is enabled, so that there is no one-frame flash or removeMode hack.

#### Acceptance Criteria

1. WHILE the Custom_Training_Window_Toggle is enabled and the training limit is enabled and the Player opens the Training_Window with a training count equal to or greater than the Training_Limit for the current level, THE Training_Window SHALL not display the training UI, SHALL display a message indicating the limit is reached, and SHALL remove only the Training mode while keeping the Dialogue mode open
2. WHILE the Custom_Training_Window_Toggle is enabled and the training limit is enabled and a successful training session causes the training count to equal the Training_Limit, THE Training_Window SHALL remove the Training mode while keeping the Dialogue mode open and SHALL display a message indicating the limit is reached
3. WHEN the Player gains a level, THE Training_Window SHALL reset the training count to zero and remove the blocked state so training is available again
4. WHEN the `trainingLimitEnabled` setting is changed to disabled mid-session, THE Training_Window SHALL remove the blocked state and hide the training count display
5. WHEN the `trainingLimitEnabled` setting is changed to enabled mid-session, THE Training_Window SHALL re-evaluate the training count against the current Training_Limit and block if the count is equal to or greater than the limit
6. WHEN the `trainingLimit` numeric value is changed mid-session, THE Training_Window SHALL re-evaluate the training count against the new value and update the blocked state and counter display accordingly
7. THE Training_Window SHALL track training count per level by incrementing the count each time a training session with source "Trainer" succeeds via the `SkillLevelUpHandler` mechanism
8. WHEN the training limit is disabled, THE Training_Window SHALL allow training without restriction and SHALL not display the training count
9. WHEN the training limit is enabled, THE Training_Window SHALL display the current training count and maximum limit formatted as "{count}/{limit}" using SandText skin, positioned below the gold display within the Training_Window layout

### Requirement 10: Window Closure

**User Story:** As a player, I want to close the Training window normally, so that I can return to gameplay.

#### Acceptance Criteria

1. WHEN the Player clicks the OK button, THE Training_Window SHALL call `interfaces.UI.removeMode("Training")` to close only the Training mode while preserving any underlying Dialogue mode
2. WHEN the engine calls `hideFn`, THE Training_Window SHALL destroy its UI element
3. WHILE the Time_Advancer is running, THE Training_Window SHALL disable the OK button so that it does not respond to clicks
4. IF the engine calls `hideFn` while the Time_Advancer is running, THEN THE Training_Window SHALL cancel the time advancement, destroy its UI element, and remove the Training mode

### Requirement 11: Skill Tooltips

**User Story:** As a player, I want to see skill tooltips when hovering over training options, so that I get the same information as the vanilla window.

#### Acceptance Criteria

1. WHEN the Player hovers over a Skill_Option, THE Training_Window SHALL display the engine's built-in skill tooltip for that skill, showing the same content as the vanilla Training window (skill name, description, governing attribute, and current skill value)
2. WHEN the Player hovers over a disabled (unaffordable) Skill_Option, THE Training_Window SHALL still display the skill tooltip
3. WHEN the Player moves the cursor away from a Skill_Option, THE Training_Window SHALL hide the skill tooltip

### Requirement 12: Window State Refresh

**User Story:** As a player, I want the Training window to update after each training session, so that prices and affordability reflect my new state.

#### Acceptance Criteria

1. WHEN the Training_Window opens, THE Training_Window SHALL recalculate all skill prices based on the Player's current Base_Skill values at the time of opening
2. WHEN the Training_Window opens, THE Training_Window SHALL display the Player's gold amount as read from inventory at the time of opening
3. WHEN the Training_Window opens, THE Training_Window SHALL evaluate affordability styling of each Skill_Option by comparing the Player's current gold against that Skill_Option's recalculated price
4. WHEN the Training_Window opens after a training session completes within the same Dialogue interaction, THE Training_Window SHALL reflect the skill increase from the prior session in the new price calculation

### Requirement 13: Custom Training Window Toggle

**User Story:** As a player, I want a setting to opt in to the custom Training window, so that I can choose between the proven removeMode approach (default) and the enhanced custom window.

#### Acceptance Criteria

1. THE Settings_System SHALL provide a `customTrainingWindow` boolean setting in the Training settings group with a default value of false
2. WHEN the `customTrainingWindow` setting is false, THE mod SHALL use the RemoveMode_Approach to enforce training limits via `UiModeChanged` and `removeMode("Training")` and `removeMode("Dialogue")`
3. WHEN the `customTrainingWindow` setting is true, THE mod SHALL register the custom Training_Window via `interfaces.UI.registerWindow` and use it for all training limit enforcement
4. THE Settings_System SHALL display the `customTrainingWindow` setting with a description indicating that enabling the custom window requires a game restart to take effect and that it permanently replaces the built-in Training window for the session

### Requirement 14: Default Behavior (Toggle Disabled)

**User Story:** As a player, I want the existing training limit enforcement to work unchanged when the custom window toggle is off, so that the mod behaves as it always has by default.

#### Acceptance Criteria

1. WHILE the Custom_Training_Window_Toggle is disabled, THE mod SHALL use the RemoveMode_Approach where the `UiModeChanged` event handler detects `newMode == "Training"` and calls `removeMode("Training")` and `removeMode("Dialogue")` when the training limit is reached
2. WHILE the Custom_Training_Window_Toggle is disabled, THE mod SHALL track training count per level using the existing `SkillLevelUpHandler` in `training.lua`
3. WHILE the Custom_Training_Window_Toggle is disabled, THE mod SHALL respond to `trainingLimitEnabled` and `trainingLimit` setting changes using the existing `onSettingChanged` handler in `training.lua`
4. WHILE the Custom_Training_Window_Toggle is disabled, THE mod SHALL not call `interfaces.UI.registerWindow` for the Training window

### Requirement 15: Toggle Change Constraint

**User Story:** As a player, I want to understand that the custom window toggle only takes effect on game restart, so that I do not encounter broken state from mid-session toggling.

#### Acceptance Criteria

1. THE mod SHALL evaluate the `customTrainingWindow` setting only once during player script initialization and SHALL not re-evaluate the setting during the same session
2. IF the `customTrainingWindow` setting is changed mid-session, THEN THE mod SHALL not alter the active training window behavior until the next game restart
3. WHEN `interfaces.UI.registerWindow("Training", showFn, hideFn)` has been called, THE mod SHALL not attempt to revert to the RemoveMode_Approach within the same session because `registerWindow` permanently disables the built-in Training window
