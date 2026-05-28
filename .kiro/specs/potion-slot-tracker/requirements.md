# Requirements Document

## Introduction

Add an alternative potion tracking mode that uses individual per-slot tracking instead of the current single-counter with global cooldown. The two modes are mutually exclusive and selectable via a settings toggle (`potionTrackingMode`). The current single-counter mode ("counter") remains the default and is unchanged. The new slot mode ("slots") uses `potionSlotCount` normal slots (default 4) plus one dedicated overflow slot (index `potionSlotCount + 1`). Each slot independently tracks one active potion drink, displays its own countdown based on the longest-duration effect of that potion, and frees itself when the potion expires. Normal UI drinks fill slots 1 through `potionSlotCount`; when all normal slots are occupied, ItemUsage blocks further drinks. The overflow slot is exclusively used when a hotkey drink bypasses ItemUsage while all normal slots are full — the drink occupies the overflow slot and triggers overdose collapse. The player remains in overdose state for the duration of the overflow slot's cooldown. The HUD shows individual countdown elements for all slots arranged vertically, with slot 1 at the same position as the current single counter element and remaining slots stacked above it.

## Glossary

- **Slot_Tracker** — The player-script subsystem that manages the array of potion slots (normal + overflow), assigns incoming drinks to free slots, and ticks down each slot's remaining duration. Active only when `potionTrackingMode` is "slots".
- **Potion_Slot** — One entry in the slot array representing a single active potion drink. Contains the potion's activeSpellId and remaining countdown duration.
- **Normal_Slot** — A Potion_Slot at index 1 through `potionSlotCount`. Used for regular potion consumption via the inventory UI.
- **Overflow_Slot** — The single Potion_Slot at index `potionSlotCount + 1`. Reserved exclusively for hotkey drinks that bypass ItemUsage while all Normal_Slots are occupied. Its occupation defines the overdose state.
- **Slot_HUD** — The MENU-script subsystem that renders individual countdown text elements on the HUD, one per potion slot (including the Overflow_Slot), arranged vertically. Active only when `potionTrackingMode` is "slots".
- **Counter_HUD** — The existing MENU-script HUD element (`counter.lua`) that displays the single-counter potion state. Active only when `potionTrackingMode` is "counter".
- **Active_Spell_Id** — The unique identifier assigned by OpenMW to each individual potion drink instance in `types.Actor.activeSpells`.
- **Longest_Duration** — The maximum `duration` value among all effects of a single potion drink's active spell entry.
- **Excluded_Potion** — A potion that bypasses the slot limit entirely (Sun's Dusk consumables, config-listed patterns). Excluded potions do not occupy slots.
- **Overdose** — The penalty state that exists while the Overflow_Slot is occupied. The player is collapsed (knocked out) for the duration of the overflow slot's cooldown.
- **Potion_Tracking_Mode** — The settings value (`potionTrackingMode`) that determines which potion tracking subsystem is active: "counter" (default, existing single-counter behavior) or "slots" (new per-slot tracking).

## Requirements

### Requirement 1: Mode Toggle Setting

**User Story:** As a player, I want to choose between the existing single-counter potion tracking and the new slot-based tracking via a settings toggle, so that I can use whichever system I prefer without breaking the default behavior.

#### Acceptance Criteria

1. THE Config SHALL expose a `potionTrackingMode` value with allowed values "counter" and "slots", defaulting to "counter".
2. THE Settings_System SHALL register `potionTrackingMode` as a setting in the `sptLimitsPotions` group, changeable via the OpenMW settings UI.
3. WHILE `potionTrackingMode` is "counter", THE Player_Script SHALL run the existing single-counter potion logic (drinkCount, global cooldown, single overdose threshold) unchanged, and THE Slot_Tracker SHALL be completely inactive (no slot assignment, no per-slot countdown, no slot-related state updates).
4. WHILE `potionTrackingMode` is "slots", THE Slot_Tracker SHALL run the per-slot potion logic, and THE Player_Script SHALL not run the single-counter potion logic (no drinkCount increment, no global cooldown timer, no single-counter overdose check).
5. WHILE `potionTrackingMode` is "counter", THE Counter_HUD SHALL display the existing single-counter element, and THE Slot_HUD SHALL not create or display any slot elements.
6. WHILE `potionTrackingMode` is "slots", THE Slot_HUD SHALL display the per-slot countdown elements, and THE Counter_HUD SHALL hide its element.
7. WHEN `potionTrackingMode` changes from "counter" to "slots" mid-session, THE Slot_Tracker SHALL initialize all slots to empty (activeSpellId nil, countdown 0) and THE Player_Script SHALL stop the single-counter logic immediately.
8. WHEN `potionTrackingMode` changes from "slots" to "counter" mid-session, THE Player_Script SHALL reset the single-counter state (drinkCount to 0, cooldown to 0) and THE Slot_Tracker SHALL discard all slot state immediately.
9. WHEN `potionTrackingMode` changes mid-session, THE Player_Script SHALL send an `sptLimitsStateUpdate` event to the Global_Script reflecting the new mode's initial state (all limits cleared).

### Requirement 2: Slot Array Initialization

**User Story:** As a player, I want the potion tracking system to start with empty slots on each session load, so that I have a fresh set of slots available.

#### Acceptance Criteria

1. WHEN a new game is started AND `potionTrackingMode` is "slots", THE Slot_Tracker SHALL create an array of `potionSlotCount + 1` Potion_Slots, each with activeSpellId set to nil and countdown set to 0.
2. WHEN a saved game is loaded AND `potionTrackingMode` is "slots", THE Slot_Tracker SHALL restore each Potion_Slot's state (activeSpellId and remaining countdown) from the persisted save data for all `potionSlotCount + 1` slots.
3. WHEN a saved game is loaded with fewer than `potionSlotCount + 1` persisted slots, THE Slot_Tracker SHALL pad the array with empty Potion_Slots (activeSpellId nil, countdown 0) to reach a total of `potionSlotCount + 1`.
4. WHEN a saved game is loaded with more than `potionSlotCount + 1` persisted slots, THE Slot_Tracker SHALL truncate the array to the first `potionSlotCount + 1` slots and discard the rest.

### Requirement 3: Drink Detection and Normal Slot Assignment

**User Story:** As a player, I want each potion I drink to be assigned to the next available normal slot, so that I can track up to `potionSlotCount` active potions independently.

#### Acceptance Criteria

1. WHEN a new activeSpellId from a non-excluded potion appears in the active spells list AND at least one Normal_Slot is empty AND `potionTrackingMode` is "slots", THE Slot_Tracker SHALL assign that drink to the first empty Normal_Slot (lowest index from 1 to `potionSlotCount`), storing the activeSpellId and setting the slot's countdown to the Longest_Duration among all effects of that active spell entry.
2. WHEN a drink is detected for an excluded potion, THE Slot_Tracker SHALL not assign the drink to any Potion_Slot and SHALL track its activeSpellId in the known set to prevent repeated detection on subsequent frames.

### Requirement 4: Overflow Slot and Overdose Trigger

**User Story:** As a player, I want a hotkey drink that bypasses the normal limit to go into a dedicated overflow slot and trigger overdose collapse, so that the penalty is tied to a concrete slot lifecycle.

#### Acceptance Criteria

1. WHEN a new activeSpellId from a non-excluded potion appears in the active spells list AND all Normal_Slots are occupied AND the Overflow_Slot is empty, THE Slot_Tracker SHALL assign that drink to the Overflow_Slot, storing the activeSpellId and setting the slot's countdown to the Longest_Duration among all effects of that active spell entry.
2. WHEN a drink is assigned to the Overflow_Slot, THE Slot_Tracker SHALL set `knockedOut` to true, set fatigue to -1, and display the `overdose` localized message.
3. WHILE the Overflow_Slot is occupied, THE Slot_Tracker SHALL maintain the player in the knocked-out state (fatigue base 0, fatigue current 0) each frame.
4. IF all Normal_Slots are occupied AND the Overflow_Slot is also occupied WHEN a new non-excluded drink is detected, THEN THE Slot_Tracker SHALL ignore the drink (no slot assignment, no additional penalty beyond the existing overdose state).

### Requirement 5: Overdose Recovery via Overflow Slot Expiry

**User Story:** As a player, I want to recover from overdose when the overflow slot's potion expires, so that the penalty duration is determined by the potion's effect length.

#### Acceptance Criteria

1. WHEN the Overflow_Slot's countdown reaches 0 or below, THE Slot_Tracker SHALL mark the Overflow_Slot as empty (clear its activeSpellId and set countdown to 0).
2. WHEN the Overflow_Slot's activeSpellId disappears from the active spells list before the countdown reaches 0, THE Slot_Tracker SHALL mark the Overflow_Slot as empty on the same frame the disappearance is detected.
3. WHEN the Overflow_Slot becomes empty, THE Slot_Tracker SHALL set `knockedOut` to false, restore fatigue base to the sum of the player's modified Strength, Willpower, Agility, and Endurance, and set fatigue current to 0.
4. WHEN the Overflow_Slot becomes empty, THE Slot_Tracker SHALL set `overdoseActive` to false and send the updated state to the Global_Script.

### Requirement 6: Per-Slot Countdown

**User Story:** As a player, I want each potion slot to count down independently based on its potion's longest effect duration, so that I know exactly when each slot frees up.

#### Acceptance Criteria

1. WHILE a Potion_Slot has a countdown greater than 0, THE Slot_Tracker SHALL decrement that slot's countdown by the frame delta time each frame, clamping the result to a minimum of 0.
2. WHEN a Potion_Slot's countdown is decremented to 0 or below (before clamping), THE Slot_Tracker SHALL mark that slot as empty (clear its activeSpellId and set countdown to 0).
3. WHEN a Potion_Slot's corresponding activeSpellId disappears from the active spells list before the countdown reaches 0, THE Slot_Tracker SHALL mark that slot as empty on the same frame the disappearance is detected.
4. THE Slot_Tracker SHALL tick each Potion_Slot's countdown independently of all other slots (including the Overflow_Slot).

### Requirement 7: Slot Stability (Fixed Assignment)

**User Story:** As a player, I want potions to stay in their assigned slot position until they expire, so that the HUD display remains stable and predictable.

#### Acceptance Criteria

1. WHILE a Potion_Slot is occupied, THE Slot_Tracker SHALL keep that drink in the same slot index until the slot becomes empty.
2. WHEN one or more Potion_Slots become empty on the same frame, THE Slot_Tracker SHALL not shift or reorder any remaining occupied slots to fill the gaps.
3. WHEN a new drink is assigned to a Normal_Slot, THE Slot_Tracker SHALL place the drink in the lowest-index empty Normal_Slot without moving existing occupied slots.
4. WHEN a saved game is loaded, THE Slot_Tracker SHALL restore each occupied Potion_Slot to the same array index it held at save time.

### Requirement 8: Potion Limit Enforcement

**User Story:** As a player, I want the mod to prevent me from drinking more than `potionSlotCount` active potions at once through the normal UI, so that the slot-based limit is enforced.

#### Acceptance Criteria

1. WHILE all Normal_Slots are occupied AND `potionTrackingMode` is "slots", THE Global_Script SHALL return `false` from the ItemUsage handler for non-excluded potions and send the `cantDrinkMore` localized message to the player via the `sptLimitsShowMessage` event.
2. WHILE at least one Normal_Slot is empty AND `potionTrackingMode` is "slots", THE Global_Script SHALL return `nil` from the ItemUsage handler for potion items, allowing normal consumption.
3. THE Slot_Tracker SHALL send the `sptLimitsStateUpdate` event to the Global_Script containing the boolean fields `knockedOut` and `allNormalSlotsFull` whenever either value changes from the last sent value.
4. THE Global_Script SHALL cache the received `knockedOut` and `allNormalSlotsFull` values, defaulting both to `false` before any event is received, and SHALL use the cached `allNormalSlotsFull` value in the ItemUsage handler to return `false` (block usage) when a non-excluded potion is used while `allNormalSlotsFull` is `true`.

### Requirement 9: Instant-Effect Potions

**User Story:** As a player, I want instant-effect potions (duration 0) to occupy a slot briefly so that they still count toward the limit during the frame they are active.

#### Acceptance Criteria

1. WHEN a potion's Longest_Duration is 0 (all effects are instant), THE Slot_Tracker SHALL assign the drink to a slot with a countdown of 0.
2. WHEN the assigned activeSpellId for an instant-effect potion disappears from the active spells list, THE Slot_Tracker SHALL mark that slot as empty on the same frame the disappearance is detected.
3. THE Slot_Tracker SHALL count instant-effect potions toward the occupied slot total on the frame they are detected.
4. WHILE an instant-effect potion's activeSpellId remains in the active spells list, THE Slot_Tracker SHALL keep that slot occupied regardless of the countdown being 0.

### Requirement 10: HUD Display — Slot Mode Layout

**User Story:** As a player, I want to see individual countdown timers on my HUD arranged vertically with slot 1 at the same position as the current counter, so that the display is familiar and readable.

#### Acceptance Criteria

1. WHILE `potionTrackingMode` is "slots", THE Slot_HUD SHALL render `potionSlotCount + 1` text elements on the HUD layer, one for each Potion_Slot (Normal_Slots plus the Overflow_Slot), arranged vertically.
2. THE Slot_HUD SHALL position the slot 1 element at the same screen coordinates as the existing Counter_HUD element (bottom-right corner, same relativePosition, anchor, and position offset).
3. THE Slot_HUD SHALL position slot 2 directly above slot 1, slot 3 directly above slot 2, slot 4 directly above slot 3, and the Overflow_Slot element directly above slot 4, each separated by a fixed vertical offset (negative Y direction, stacking upward).
4. WHILE a Potion_Slot is occupied, THE Slot_HUD SHALL display the remaining countdown in seconds formatted to one decimal place with an "s" suffix (e.g. "12.3s") for that slot's element.
5. WHILE a Potion_Slot is empty, THE Slot_HUD SHALL hide that slot's text element.
6. WHILE the Overflow_Slot is occupied, THE Slot_HUD SHALL visually distinguish the overflow slot's element from Normal_Slot elements (e.g. different color or prefix) to indicate overdose state.
7. THE Slot_HUD SHALL read slot state from `storage.playerSection("sptLimitsState")` written by the Slot_Tracker.
8. THE Slot_HUD SHALL update each element every frame to reflect current countdown values.
9. IF `hudCounterEnabled` is false in settings, THEN THE Slot_HUD SHALL not create any HUD elements and SHALL remain inactive for the session.
10. IF the storage read for a slot's countdown value returns nil, THEN THE Slot_HUD SHALL treat that slot as empty and hide its text element.

### Requirement 11: Removal of Global Cooldown Timer (Slot Mode Only)

**User Story:** As a player using slot mode, I want potion availability determined solely by individual slot expiry, so that there is no global cooldown interfering with the per-slot system.

#### Acceptance Criteria

1. WHILE `potionTrackingMode` is "slots", THE Slot_Tracker SHALL not use a global `potionCooldown` timer or a game-time-based elapsed-hour check to reset all drink tracking at once.
2. WHILE `potionTrackingMode` is "slots", THE Slot_Tracker SHALL not maintain a single `drinkCount` integer for potion limit enforcement.
3. WHILE `potionTrackingMode` is "slots", THE Slot_Tracker SHALL determine whether the player may drink another potion solely by checking whether at least one Normal_Slot is empty.

### Requirement 12: Configurable Slot Count

**User Story:** As a mod author, I want the number of normal potion slots to be configurable in `config.lua`, so that the limit can be adjusted without code changes.

#### Acceptance Criteria

1. THE Config SHALL expose a `potionSlotCount` value that determines the number of Normal_Slots (default: 4, minimum: 1, maximum: 10).
2. WHEN the Slot_Tracker initializes, THE Slot_Tracker SHALL create exactly `potionSlotCount` Normal_Slots plus one Overflow_Slot.
3. WHEN the Slot_HUD initializes, THE Slot_HUD SHALL create exactly `potionSlotCount + 1` text elements.
4. THE Config value SHALL be read once at load time and remain constant for the session.
5. THE Overflow_Slot SHALL always exist at index `potionSlotCount + 1` regardless of the configured `potionSlotCount` value.

### Requirement 13: Save/Load Persistence

**User Story:** As a player, I want my active potion slot states (including the overflow slot) to persist across save and load, so that I don't lose tracking data when reloading a game.

#### Acceptance Criteria

1. WHEN the game is saved AND `potionTrackingMode` is "slots", THE Slot_Tracker SHALL return each Potion_Slot's activeSpellId and remaining countdown from the `onSave` handler for all `potionSlotCount + 1` slots.
2. WHEN a saved game is loaded AND `potionTrackingMode` is "slots", THE Slot_Tracker SHALL restore each Potion_Slot's activeSpellId and countdown from the persisted data, then check whether each activeSpellId is still present in `types.Actor.activeSpells`.
3. IF a persisted activeSpellId is no longer present in the active spells list after load, THEN THE Slot_Tracker SHALL mark that slot as empty (clear its activeSpellId and set countdown to 0).
4. IF the persisted Overflow_Slot has a valid activeSpellId still present in active spells after load, THEN THE Slot_Tracker SHALL restore the overdose state (`knockedOut` true, maintain collapse).
5. IF the persisted Overflow_Slot's activeSpellId is no longer present after load, THEN THE Slot_Tracker SHALL mark the Overflow_Slot as empty and set `knockedOut` to false.
6. IF the persisted slot array contains more entries than the current `potionSlotCount + 1`, THEN THE Slot_Tracker SHALL truncate the array to `potionSlotCount + 1`, discarding excess slots from the highest indices.
7. WHILE a Potion_Slot's activeSpellId is still present in the active spells list after load, THE Slot_Tracker SHALL use the persisted countdown value as the slot's remaining duration without recalculating from spell data.
8. WHEN the game is saved AND `potionTrackingMode` is "counter", THE Slot_Tracker SHALL not persist any slot data (the existing counter logic handles its own persistence).

### Requirement 14: Overdose State Communication

**User Story:** As a mod system, I want the player script to communicate overdose state to the global script, so that the ItemUsage handler can block further potion usage during normal play.

#### Acceptance Criteria

1. WHEN the value of `state.knockedOut` or `state.allNormalSlotsFull` differs from the last value sent to the global script, THE Slot_Tracker SHALL send an `sptLimitsStateUpdate` event to the global script with a payload containing both the current `knockedOut` (boolean) and `allNormalSlotsFull` (boolean, true when all Normal_Slots are occupied) fields.
2. THE Global_Script SHALL cache the received `knockedOut` and `allNormalSlotsFull` values, defaulting both to `false` before any event is received, and SHALL use the cached `allNormalSlotsFull` value in the ItemUsage handler to return `false` (block usage) when a non-excluded potion is used while `allNormalSlotsFull` is `true`.
3. WHEN the player script initializes or loads, THE Slot_Tracker SHALL send the `sptLimitsStateUpdate` event with the current `knockedOut` and `allNormalSlotsFull` values on the first frame after `onUpdate` begins executing.

### Requirement 15: Storage Schema for HUD Communication

**User Story:** As a HUD subsystem, I want a well-defined storage schema so that the MENU script can read per-slot countdown data reliably.

#### Acceptance Criteria

1. THE Slot_Tracker SHALL write per-slot countdown values to `storage.playerSection("sptLimitsState")` using indexed keys (`"slot1Countdown"`, `"slot2Countdown"`, ... up to `potionSlotCount + 1`), where each value is a float representing remaining seconds, or 0 when the slot is empty.
2. THE Slot_Tracker SHALL write the total number of occupied Normal_Slots to `storage.playerSection("sptLimitsState")` under the key `"occupiedSlots"` as an integer from 0 to `potionSlotCount`.
3. THE Slot_Tracker SHALL write a boolean `"overflowOccupied"` to `storage.playerSection("sptLimitsState")` indicating whether the Overflow_Slot is currently occupied.
4. THE Slot_HUD SHALL read the per-slot countdown values, occupied slot count, and overflow status from `storage.playerSection("sptLimitsState")`.
5. WHEN a Potion_Slot's countdown value, the occupied slot count, or the overflow status changes, THE Slot_Tracker SHALL update the corresponding storage key within the same frame.
6. THE Slot_Tracker SHALL write the configured `potionSlotCount` value to `storage.playerSection("sptLimitsState")` under the key `"slotCount"` so that the Slot_HUD can determine how many slot keys to read (total elements = `slotCount + 1`).
7. THE Slot_Tracker SHALL write the current `potionTrackingMode` value to `storage.playerSection("sptLimitsState")` under the key `"trackingMode"` so that the Slot_HUD and Counter_HUD can determine which display to activate.

### Requirement 16: Global Script Mode Awareness

**User Story:** As a mod system, I want the global script's ItemUsage handler to behave correctly regardless of which tracking mode is active, so that potion blocking works appropriately for both modes.

#### Acceptance Criteria

1. THE Player_Script SHALL include the current `potionTrackingMode` value in the `sptLimitsStateUpdate` event payload sent to the Global_Script.
2. WHILE the Global_Script's cached `potionTrackingMode` is "counter", THE Global_Script SHALL use the existing single-counter logic (drinkOverdose flag) to determine whether to block potion usage via ItemUsage.
3. WHILE the Global_Script's cached `potionTrackingMode` is "slots", THE Global_Script SHALL use the cached `allNormalSlotsFull` value to determine whether to block potion usage via ItemUsage.
4. WHEN the Global_Script receives an `sptLimitsStateUpdate` event with a different `potionTrackingMode` than previously cached, THE Global_Script SHALL update its cached mode and reset its blocking state to the values provided in the event payload.
