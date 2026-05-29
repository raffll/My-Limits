# Implementation Plan: Custom Training Window

## Overview

Implement a toggleable custom Training window that coexists with the existing `training.lua` module. When the `customTrainingWindow` setting is enabled, a new `trainingWindow.lua` module registers a custom Lua Training window via `interfaces.UI.registerWindow`. When disabled (default), the existing `training.lua` removeMode approach remains active and unchanged. The toggle is evaluated once at player script initialization.

## Tasks

- [x] 1. Add toggle setting and l10n strings
  - [x] 1.1 Add `customTrainingWindow` default to `config.lua`
    - Add `customTrainingWindow = false` to the config defaults table
    - _Requirements: 13.1_

  - [x] 1.2 Add `customTrainingWindow` setting definition to `settings.lua`
    - Add a boolean setting definition with key `customTrainingWindow`, default from `config.customTrainingWindow`, renderer `checkbox`, group `sptLimitsTraining`, order 2
    - Shift existing `trainingLimit` order to 3 to make room
    - _Requirements: 13.1, 13.4_

  - [x] 1.3 Add l10n strings for the new setting to `l10n/sptLimits/en.yaml`
    - Add `settingCustomTrainingWindowName` and `settingCustomTrainingWindowDesc` entries
    - The description must indicate that enabling requires a game restart
    - _Requirements: 13.4_

- [x] 2. Update `player.lua` to conditionally require training module
  - [x] 2.1 Implement toggle-based module selection in `player.lua`
    - Read `customTrainingWindow` setting once at the top level (after settings module is available)
    - Conditionally require either `scripts.sptLimits.player.trainingWindow` or `scripts.sptLimits.player.training` based on the toggle value
    - Store the result in the existing `training` variable
    - Wire `training.onSettingChanged` in the settings subscriber (already done)
    - Wire `training.onLoad` in the `onLoad` handler (already done)
    - Read `training.state.trainCount` and `training.state.trainLevel` in `onSave` (already done)
    - Make the `UiModeChanged` handler call `training.onUiModeChanged(data)` only if the function exists (it won't exist on `trainingWindow.lua`)
    - _Requirements: 13.2, 13.3, 14.1, 14.4, 15.1, 15.2_

- [x] 3. Checkpoint - Ensure toggle wiring is correct
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Create `trainingWindow.lua` — core structure and window registration
  - [x] 4.1 Create `trainingWindow.lua` with module skeleton and state
    - Create `scripts/sptLimits/player/trainingWindow.lua`
    - Define `state = { trainCount = 0, trainLevel = 0 }` and `windowState` locals
    - Export `{ state, onSettingChanged, onLoad }` matching the interface shape
    - Register `SkillLevelUpHandler` at require-time for training count tracking (same logic as `training.lua`)
    - _Requirements: 9.7, 14.2_

  - [x] 4.2 Implement `registerWindow` call and `showFn`/`hideFn` callbacks
    - Call `interfaces.UI.registerWindow("Training", showFn, hideFn)` at require-time
    - `showFn` receives the trainer actor, stores it in `windowState.trainer`
    - `showFn` checks for nil actor (requirement 1.6), time advancement active (requirement 1.5), and blocked state (requirement 9.1)
    - `hideFn` destroys the UI element if it exists, no-op otherwise (requirement 1.4)
    - _Requirements: 1.1, 1.3, 1.4, 1.5, 1.6, 9.1_

  - [x] 4.3 Implement `onSettingChanged` and `onLoad` handlers
    - `onSettingChanged` updates blocked state for `trainingLimitEnabled` and `trainingLimit` changes (same logic as `training.lua`)
    - `onLoad` restores `state.trainCount` and `state.trainLevel` from save data
    - _Requirements: 9.4, 9.5, 9.6_

- [x] 5. Implement skill selection and price calculation
  - [x] 5.1 Implement trainer skill selection (top 3 skills)
    - Iterate all 27 skills on the trainer NPC
    - Use base or modified values based on `game.mTrainersTrainingSkillsBasedOnBaseSkill` GMST
    - Select up to 3 skills with value > 0, sorted descending by value (stable sort)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.8_

  - [x] 5.2 Implement raw price calculation
    - `rawPrice = max(1, playerBaseSkill * iTrainingMod)`
    - Read `iTrainingMod` from `core.getGMST("iTrainingMod")`, fallback to 10
    - _Requirements: 4.1, 4.2_

  - [x] 5.3 Implement barter offer price adjustment
    - Reimplement the vanilla Morrowind barter formula in Lua
    - Use player and trainer mercantile, personality, luck, disposition, fatigue ratio
    - Compute `pcTerm`, `npcTerm`, `buyTerm`, clamp, and floor to get final price (minimum 1)
    - _Requirements: 4.3, 4.4_

  - [x] 5.4 Write property test for skill selection (Property 1)
    - **Property 1: Skill selection returns top skills in stable descending order**
    - **Validates: Requirements 3.1, 3.2, 3.8**

  - [x] 5.5 Write property test for raw price calculation (Property 2)
    - **Property 2: Raw training price calculation**
    - **Validates: Requirements 4.1, 4.2**

  - [x] 5.6 Write property test for barter offer adjustment (Property 3)
    - **Property 3: Barter offer price adjustment**
    - **Validates: Requirements 4.3, 4.4**

- [x] 6. Implement window UI layout
  - [x] 6.1 Build the Training window layout
    - Use MW_Dialog skin, 320x200 dimensions, centered on screen
    - Title "#{sServiceTrainingTitle}" at (6,3), subtitle "#{sTrainingServiceTitle}" at (6,22)
    - Skill options container with MW_Box skin at (6,42) size 300x115
    - Gold display "#{sGold}: <amount>" at (6,161)
    - OK button with MW_Button skin at (246,161), auto-sized, anchored right
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 6.2 Render skill option buttons with affordability styling
    - Each skill option as a button with "skillName - price#{sgp}" text
    - Position at x=4, y = 3 + index * (fontSize + 2) within the options container
    - Width = text width + 12px
    - Use SandTextButton skin if affordable, SandTextButtonDisabled if not
    - _Requirements: 3.5, 3.6, 3.7, 5.1, 5.2_

  - [x] 6.3 Implement skill tooltips on hover
    - Set tooltip properties on all skill option widgets for engine built-in skill tooltip
    - Tooltips display on both affordable and unaffordable options
    - _Requirements: 11.1, 11.2, 11.3_

  - [x] 6.4 Implement training count display when limit is enabled
    - Show "{count}/{limit}" using SandText skin below the gold display
    - Hide when training limit is disabled
    - _Requirements: 9.8, 9.9_

  - [x] 6.5 Write property test for affordability skin selection (Property 4)
    - **Property 4: Affordability determines button skin**
    - **Validates: Requirements 5.1, 5.2**

- [x] 7. Checkpoint - Ensure window renders correctly
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement training validation and execution
  - [x] 8.1 Implement validation checks on skill option click
    - Check order: gold insufficient → trainer skill <= player base skill → player base skill >= governing attribute
    - Gold insufficient: ignore click silently
    - Trainer skill check fails: show "#{sServiceTrainingWords}", stay open
    - Attribute cap check fails: show "#{sNotifyMessage17}", stay open
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 8.2 Implement training execution on successful validation
    - Call `interfaces.SkillProgression.skillLevelUp` with Trainer source
    - If cancelled (returns false): abort, no side effects
    - If succeeds: remove gold from player, add gold to trainer barter pool
    - Hide dialog, show progress bar, trigger fade sequence
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 8.3 Implement time advancement state machine
    - Fade out (0.2s) → delay (0.2s) → fade in (0.2s) → rest(2h, sleeping=false) → removeMode("Training")
    - Progress bar advances from 0 to completion over ~0.4s real time
    - Disable OK button while time advancement is running
    - Handle `hideFn` during time advancement (cancel, destroy, remove mode)
    - _Requirements: 7.5, 7.6, 7.7, 8.1, 8.2, 8.3, 10.3, 10.4_

  - [x] 8.4 Implement training limit enforcement within the window
    - When training succeeds and count reaches limit: remove Training mode (keep Dialogue), show limit message
    - On window open with blocked state: show message, removeMode("Training") only (keep Dialogue open)
    - Level change resets count to 0 and unblocks
    - _Requirements: 9.1, 9.2, 9.3_

  - [x] 8.5 Write property test for validation check ordering (Property 5)
    - **Property 5: Validation checks follow strict ordering**
    - **Validates: Requirements 6.1, 6.2, 6.3, 6.4**

  - [x] 8.6 Write property test for gold conservation (Property 6)
    - **Property 6: Gold conservation on successful training**
    - **Validates: Requirements 7.3**

- [x] 9. Implement shared training limit properties
  - [x] 9.1 Write property test for blocked state invariant (Property 7)
    - **Property 7: Blocked state invariant**
    - **Validates: Requirements 9.1, 9.5, 9.6, 14.1**

  - [x] 9.2 Write property test for training count increment (Property 8)
    - **Property 8: Training count increments on trainer source**
    - **Validates: Requirements 9.7, 14.2**

  - [x] 9.3 Write property test for level change reset (Property 9)
    - **Property 9: Level change resets training count**
    - **Validates: Requirements 9.3**

  - [x] 9.4 Write property test for disabled limit (Property 10)
    - **Property 10: Disabled limit never blocks**
    - **Validates: Requirements 9.8**

- [x] 10. Implement OK button and window closure
  - [x] 10.1 Wire OK button click to `removeMode("Training")`
    - OK button calls `interfaces.UI.removeMode("Training")` preserving Dialogue mode
    - `hideFn` destroys the UI element (idempotent)
    - _Requirements: 10.1, 10.2_

- [x] 11. Implement window state refresh
  - [x] 11.1 Recalculate prices and affordability on each window open
    - On each `showFn` call, recalculate all skill prices from current player base skill values
    - Read player gold from inventory at time of opening
    - Evaluate affordability styling per skill option
    - After a training session completes within the same Dialogue interaction, the next `showFn` reflects the skill increase
    - _Requirements: 12.1, 12.2, 12.3, 12.4_

- [x] 12. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- `training.lua` is NOT modified or deleted — it remains the default path
- Both modules export the same interface shape: `{ state, onSettingChanged, onLoad }`
- The `SkillLevelUpHandler` is registered inside whichever module is active (at require-time)
- The `UiModeChanged` handler in `player.lua` stays — it calls `training.onUiModeChanged` when toggle is OFF, and is a no-op when toggle is ON (function doesn't exist on `trainingWindow.lua`)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.3"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1", "4.1"] },
    { "id": 3, "tasks": ["4.2", "4.3", "5.1", "5.2", "5.3"] },
    { "id": 4, "tasks": ["5.4", "5.5", "5.6", "6.1"] },
    { "id": 5, "tasks": ["6.2", "6.3", "6.4", "6.5"] },
    { "id": 6, "tasks": ["8.1", "8.2"] },
    { "id": 7, "tasks": ["8.3", "8.4", "8.5", "8.6"] },
    { "id": 8, "tasks": ["9.1", "9.2", "9.3", "9.4", "10.1"] },
    { "id": 9, "tasks": ["11.1"] }
  ]
}
```
