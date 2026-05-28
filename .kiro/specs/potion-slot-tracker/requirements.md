# Requirements Document

## Introduction

Replace the current single-counter potion tracking system with individual potion slots. Each slot independently tracks one active potion drink, displays its own countdown based on the longest-duration effect of that potion, and frees itself when the potion expires. The HUD shows individual countdown elements instead of the current single counter. The potion limit is enforced per occupied slots rather than a global cooldown timer.

## Glossary

- **Slot_Tracker** — The player-script subsystem that manages the array of potion slots, assigns incoming drinks to free slots, and ticks down each slot's remaining duration.
- **Potion_Slot** — One entry in the slot array representing a single active potion drink. Contains the potion's activeSpellId and remaining countdown duration.
- **Slot_HUD** — The MENU-script subsystem that renders individual countdown text elements on the HUD, one per potion slot.
- **Active_Spell_Id** — The unique identifier assigned by OpenMW to each individual potion drink instance in `types.Actor.activeSpells`.
- **Longest_Duration** — The maximum `duration` value among all effects of a single potion drink's active spell entry.
- **Excluded_Potion** — A potion that bypasses the slot limit entirely (Sun's Dusk consumables, config-listed patterns). Excluded potions do not occupy slots.
- **Overdose** — The penalty state triggered when the player drinks a potion via hotkey while all slots are occupied, bypassing the ItemUsage block.

## Requirements

### Requirement 1: Slot Array Initialization

**User Story:** As a player, I want the potion tracking system to start with empty slots on each session load, so that I have a fresh set of slots available.

#### Acceptance Criteria

1. WHEN a new game is started, THE Slot_Tracker SHALL create an array of `potionSlotCount` Potion_Slots, each with activeSpellId set to nil and countdown set to 0.
2. WHEN a saved game is loaded, THE Slot_Tracker SHALL restore each Potion_Slot's state (activeSpellId and remaining countdown) from the persisted save data.
3. WHEN a saved game is loaded with fewer than `potionSlotCount` persisted slots, THE Slot_Tracker SHALL pad the array with empty Potion_Slots (activeSpellId nil, countdown 0) to reach a total of `potionSlotCount`.
4. WHEN a saved game is loaded with more than `potionSlotCount` persisted slots, THE Slot_Tracker SHALL truncate the array to the first `potionSlotCount` slots and discard the rest.

### Requirement 2: Drink Detection and Slot Assignment

**User Story:** As a player, I want each potion I drink to be assigned to the next available slot, so that I can track up to `potionSlotCount` active potions independently.

#### Acceptance Criteria

1. WHEN a new activeSpellId from a non-excluded potion appears in the active spells list, THE Slot_Tracker SHALL assign that drink to the first empty Potion_Slot (lowest index), storing the activeSpellId and setting the slot's countdown to the Longest_Duration among all effects of that active spell entry.
2. IF all Potion_Slots are occupied WHEN a new non-excluded drink is detected, THEN THE Slot_Tracker SHALL trigger the overdose penalty (collapse the player by setting fatigue to a negative value).
3. WHEN a drink is detected for an excluded potion, THE Slot_Tracker SHALL not assign the drink to any Potion_Slot and SHALL track its activeSpellId in the known set to prevent repeated detection on subsequent frames.

### Requirement 3: Per-Slot Countdown

**User Story:** As a player, I want each potion slot to count down independently based on its potion's longest effect duration, so that I know exactly when each slot frees up.

#### Acceptance Criteria

1. WHILE a Potion_Slot has a countdown greater than 0, THE Slot_Tracker SHALL decrement that slot's countdown by the frame delta time each frame, clamping the result to a minimum of 0.
2. WHEN a Potion_Slot's countdown is decremented to 0 or below (before clamping), THE Slot_Tracker SHALL mark that slot as empty (clear its activeSpellId and set countdown to 0).
3. WHEN a Potion_Slot's corresponding activeSpellId disappears from the active spells list before the countdown reaches 0, THE Slot_Tracker SHALL mark that slot as empty on the same frame the disappearance is detected.
4. THE Slot_Tracker SHALL tick each Potion_Slot's countdown independently of all other slots.

### Requirement 4: Slot Stability (Fixed Assignment)

**User Story:** As a player, I want potions to stay in their assigned slot position until they expire, so that the HUD display remains stable and predictable.

#### Acceptance Criteria

1. WHILE a Potion_Slot is occupied, THE Slot_Tracker SHALL keep that drink in the same slot index until the slot becomes empty.
2. WHEN one or more Potion_Slots become empty on the same frame, THE Slot_Tracker SHALL not shift or reorder any remaining occupied slots to fill the gaps.
3. WHEN a new drink is assigned, THE Slot_Tracker SHALL place the drink in the lowest-index empty slot without moving existing occupied slots.
4. WHEN a saved game is loaded, THE Slot_Tracker SHALL restore each occupied Potion_Slot to the same array index it held at save time.

### Requirement 5: Potion Limit Enforcement

**User Story:** As a player, I want the mod to prevent me from drinking more than `potionSlotCount` active potions at once through the normal UI, so that the slot-based limit is enforced.

#### Acceptance Criteria

1. WHILE all Potion_Slots are occupied AND `knockedOut` is false, THE Global_Script SHALL return `false` from the ItemUsage handler for non-excluded potions and send the `cantDrinkMore` localized message to the player via the `sptLimitsShowMessage` event.
2. WHILE at least one Potion_Slot is empty, THE Global_Script SHALL return `nil` from the ItemUsage handler for potion items, allowing normal consumption.
3. THE Slot_Tracker SHALL send the `sptLimitsStateUpdate` event to the Global_Script containing the boolean fields `knockedOut` and `drinkOverdose` whenever either value changes from the last sent value.
4. WHEN the Slot_Tracker detects a new non-excluded potion activeSpellId via frame-over-frame comparison WHILE all Potion_Slots are occupied, THE Slot_Tracker SHALL set `overdoseCollapse` to true, set `knockedOut` to true, set fatigue to -1, and display the `overdose` localized message.

### Requirement 6: Instant-Effect Potions

**User Story:** As a player, I want instant-effect potions (duration 0) to occupy a slot briefly so that they still count toward the limit during the frame they are active.

#### Acceptance Criteria

1. WHEN a potion's Longest_Duration is 0 (all effects are instant), THE Slot_Tracker SHALL assign the drink to a slot with a countdown of 0.
2. WHEN the assigned activeSpellId for an instant-effect potion disappears from the active spells list, THE Slot_Tracker SHALL mark that slot as empty on the same frame the disappearance is detected.
3. THE Slot_Tracker SHALL count instant-effect potions toward the occupied slot total on the frame they are detected.
4. WHILE an instant-effect potion's activeSpellId remains in the active spells list, THE Slot_Tracker SHALL keep that slot occupied regardless of the countdown being 0.

### Requirement 7: HUD Display — Individual Countdowns

**User Story:** As a player, I want to see individual countdown timers on my HUD, so that I can monitor each active potion's remaining time at a glance.

#### Acceptance Criteria

1. THE Slot_HUD SHALL render `potionSlotCount` text elements on the HUD layer, one for each Potion_Slot, arranged vertically with each element positioned at a fixed offset below the previous one.
2. WHILE a Potion_Slot is occupied, THE Slot_HUD SHALL display the remaining countdown in seconds formatted to one decimal place with an "s" suffix (e.g. "12.3s") for that slot's element.
3. WHILE a Potion_Slot is empty, THE Slot_HUD SHALL hide that slot's text element.
4. THE Slot_HUD SHALL read slot state from `storage.playerSection("sptLimitsState")` written by the Slot_Tracker.
5. THE Slot_HUD SHALL update each element every frame to reflect current countdown values.
6. IF `hudCounterEnabled` is false in config, THEN THE Slot_HUD SHALL not create any HUD elements and shall remain inactive for the session.
7. IF the storage read for a slot's countdown value returns nil, THEN THE Slot_HUD SHALL treat that slot as empty and hide its text element.

### Requirement 8: Removal of Global Cooldown Timer

**User Story:** As a player, I want the old single global cooldown timer removed, so that potion availability is determined solely by individual slot expiry.

#### Acceptance Criteria

1. THE Slot_Tracker SHALL not use a global `potionCooldown` timer or a game-time-based elapsed-hour check to reset all drink tracking at once.
2. THE Slot_Tracker SHALL not maintain a single `drinkCount` integer for potion limit enforcement.
3. THE Slot_Tracker SHALL determine whether the player may drink another potion solely by checking whether at least one Potion_Slot is empty.

### Requirement 9: Configurable Slot Count

**User Story:** As a mod author, I want the number of potion slots to be configurable in `config.lua`, so that the limit can be adjusted without code changes.

#### Acceptance Criteria

1. THE Config SHALL expose a `potionSlotCount` value that determines the number of Potion_Slots (default: 4, minimum: 1, maximum: 10).
2. WHEN the Slot_Tracker initializes, THE Slot_Tracker SHALL create exactly `potionSlotCount` Potion_Slots.
3. WHEN the Slot_HUD initializes, THE Slot_HUD SHALL create exactly `potionSlotCount` text elements.
4. THE Config value SHALL be read once at load time and remain constant for the session.

### Requirement 10: Save/Load Persistence

**User Story:** As a player, I want my active potion slot states to persist across save and load, so that I don't lose tracking data when reloading a game.

#### Acceptance Criteria

1. WHEN the game is saved, THE Slot_Tracker SHALL return each Potion_Slot's activeSpellId and remaining countdown from the `onSave` handler.
2. WHEN a saved game is loaded, THE Slot_Tracker SHALL restore each Potion_Slot's activeSpellId and countdown from the persisted data, then check whether each activeSpellId is still present in `types.Actor.activeSpells`.
3. IF a persisted activeSpellId is no longer present in the active spells list after load, THEN THE Slot_Tracker SHALL mark that slot as empty (clear its activeSpellId and set countdown to 0).
4. IF the persisted slot array contains more entries than the current `potionSlotCount`, THEN THE Slot_Tracker SHALL truncate the array to `potionSlotCount`, discarding excess slots from the highest indices.
5. WHILE a Potion_Slot's activeSpellId is still present in the active spells list after load, THE Slot_Tracker SHALL use the persisted countdown value as the slot's remaining duration without recalculating from spell data.

### Requirement 11: Overdose State Communication

**User Story:** As a mod system, I want the player script to communicate overdose state to the global script, so that the ItemUsage handler can block further potion usage.

#### Acceptance Criteria

1. WHEN the value of `state.knockedOut` or `state.drinkOverdose` differs from the last value sent to the global script, THE Slot_Tracker SHALL send an `sptLimitsStateUpdate` event to the global script with a payload containing both the current `knockedOut` (boolean) and `drinkOverdose` (boolean, true when all slots are occupied) fields.
2. THE Global_Script SHALL cache the received `knockedOut` and `drinkOverdose` values, defaulting both to `false` before any event is received, and SHALL use the cached `drinkOverdose` value in the ItemUsage handler to return `false` (block usage) when a non-excluded potion is used while `drinkOverdose` is `true`.
3. WHEN the player script initializes or loads, THE Slot_Tracker SHALL send the `sptLimitsStateUpdate` event with the current `knockedOut` and `drinkOverdose` values on the first frame after `onUpdate` begins executing.

### Requirement 12: Storage Schema for HUD Communication

**User Story:** As a HUD subsystem, I want a well-defined storage schema so that the MENU script can read per-slot countdown data reliably.

#### Acceptance Criteria

1. THE Slot_Tracker SHALL write per-slot countdown values to `storage.playerSection("sptLimitsState")` using indexed keys (`"slot1Countdown"`, `"slot2Countdown"`, ... up to `potionSlotCount`), where each value is a float representing remaining seconds, or 0 when the slot is empty.
2. THE Slot_Tracker SHALL write the total number of occupied slots to `storage.playerSection("sptLimitsState")` under the key `"occupiedSlots"` as an integer from 0 to `potionSlotCount`.
3. THE Slot_HUD SHALL read the per-slot countdown values and occupied slot count from `storage.playerSection("sptLimitsState")`.
4. WHEN a Potion_Slot's countdown value or the occupied slot count changes, THE Slot_Tracker SHALL update the corresponding storage key within the same frame.
5. THE Slot_Tracker SHALL write the configured `potionSlotCount` value to `storage.playerSection("sptLimitsState")` under the key `"slotCount"` so that the Slot_HUD can determine how many slot keys to read.
