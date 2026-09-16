# Requirements Document

## Introduction

The training limit (capped at a configurable number per level) should automatically disable itself once the player reaches a configurable level threshold. This prevents late-game tedium when all Major/Minor skills are maxed and the player can only level via Misc skills that require expensive trainer visits.

## Glossary

- **Training_Limit_System** — The existing subsystem that restricts how many times a player can train skills per level via NPC trainers.
- **Auto_Disable** — The behavior where the training limit is removed automatically when the player reaches a specified level.
- **Level_Threshold** — The player level at or above which the training limit is automatically disabled.
- **Toggle** — A boolean setting that enables or disables the auto-disable behavior.

## Requirements

### Requirement 1: Auto-Disable Toggle Setting

**User Story:** As a player, I want a toggle setting to enable or disable the training limit auto-disable behavior, so that I can choose whether the limit lifts automatically at high levels.

#### Acceptance Criteria

1. THE Training_Limit_System SHALL register a boolean setting named `trainingAutoDisable` in the settings group with a default value of `false`
2. WHEN the `trainingAutoDisable` setting is changed, THE Training_Limit_System SHALL apply the new value on the same frame without requiring a game restart
3. WHEN `trainingAutoDisable` is changed to `true` and the player's level is at or above `trainingAutoDisableLevel`, THE Training_Limit_System SHALL unblock the training window immediately
4. WHEN `trainingAutoDisable` is changed to `false`, THE Training_Limit_System SHALL re-evaluate the training count and block the training window if the count meets or exceeds `trainingLimit`

### Requirement 2: Level Threshold Setting

**User Story:** As a player, I want to configure the level at which the training limit disables itself, so that I can tailor the threshold to my playstyle.

#### Acceptance Criteria

1. THE Training_Limit_System SHALL expose a numeric setting named `trainingAutoDisableLevel` with a default value of 50
2. THE Training_Limit_System SHALL constrain the `trainingAutoDisableLevel` setting to a minimum of 2 and a maximum of 100
3. WHEN the `trainingAutoDisableLevel` setting is changed, THE Training_Limit_System SHALL re-evaluate the player's current level against the new threshold and unblock or re-block training within the same frame
4. IF `trainingLimitEnabled` is set to false, THEN THE Training_Limit_System SHALL not evaluate `trainingAutoDisableLevel` and shall leave training unblocked regardless of the threshold value

### Requirement 3: Automatic Limit Removal at Threshold

**User Story:** As a late-game player, I want the training limit to be removed automatically when I reach the configured level, so that I can train without restriction when skill leveling is otherwise impractical.

#### Acceptance Criteria

1. WHILE the `trainingAutoDisable` setting is enabled AND the player level is greater than or equal to `trainingAutoDisableLevel`, THE Training_Limit_System SHALL allow unlimited training sessions per level by unblocking the training window and skipping the training count check
2. WHILE the `trainingAutoDisable` setting is enabled AND the player level is below `trainingAutoDisableLevel`, THE Training_Limit_System SHALL enforce the configured `trainingLimit` per level as normal
3. WHEN the player levels up to or past the `trainingAutoDisableLevel` threshold, THE Training_Limit_System SHALL unblock the training window and stop enforcing the training count within 1 frame of the level change being detected
4. WHEN the `trainingAutoDisableLevel` setting is changed via the settings UI, THE Training_Limit_System SHALL re-evaluate the player's current level against the new threshold and block or unblock training accordingly within 1 frame

### Requirement 4: Toggle-Off Preserves Existing Behavior

**User Story:** As a player who prefers the vanilla training cap, I want the limit to always apply when the toggle is off, so that the default experience is unchanged.

#### Acceptance Criteria

1. WHILE the `trainingAutoDisable` setting is disabled, THE Training_Limit_System SHALL block training sessions that would exceed the `trainingLimit` count for the current level, regardless of the player level
2. WHEN the `trainingAutoDisable` setting is changed from enabled to disabled, IF the player level is greater than or equal to `trainingAutoDisableLevel` AND the training count for the current level already equals or exceeds `trainingLimit`, THEN THE Training_Limit_System SHALL block the training window on the same frame as the setting change
3. WHEN the `trainingAutoDisable` setting is changed from enabled to disabled, THE Training_Limit_System SHALL preserve the current level's training count accumulated while the setting was enabled
