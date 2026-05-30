# Requirements Document

## Introduction

Stat capping prevents the player from exceeding configurable attribute and skill caps by blocking the source action (drinking a potion, casting a spell, using an enchantment, or equipping a constant-effect item) before the Fortify effect applies. Only base value and active Fortify effects are considered; Drain and Damage effects are ignored entirely.

## Glossary

- **Stat_Capper**: The player-script module responsible for evaluating whether an incoming Fortify effect would push a stat over the cap, and blocking the source action if so.
- **Fortify_Sum**: The sum of all currently active Fortify Attribute or Fortify Skill magnitudes on a given stat, excluding effects from excluded spells.
- **Effective_Value**: The base value of a stat plus its Fortify_Sum.
- **Incoming_Magnitude**: The magnitude of a Fortify Attribute or Fortify Skill effect that would be applied by the action being evaluated.
- **Cap**: The configurable maximum allowed Effective_Value for attributes (attributeCap) or skills (skillCap).
- **Excluded_Stat**: An attribute or skill that is either listed in the config exclusion tables or marked as skipped at runtime via the Lua interface.
- **Source_Action**: The player action that would apply a Fortify effect — drinking a potion, casting a spell, using a Cast When Used enchantment, or equipping a Constant Effect or Cast When Strikes item.
- **Global_Script**: The global Lua script that handles ItemUsage interception for potions.
- **Player_Script**: The player Lua script that handles spell casting interception, Cast When Used enchantment blocking, equipment change detection for Constant Effect and Cast When Strikes items, and hotkey potion removal.

## Requirements

### Requirement 1: Block Potion Drinking When Fortify Exceeds Cap

**User Story:** As a player, I want to be prevented from drinking a potion whose Fortify effects would push any non-excluded stat over the cap, so that I cannot exceed the stat limit through potions.

#### Acceptance Criteria

1. WHEN the player attempts to drink a potion via the inventory UI, THE Global_Script SHALL evaluate each Fortify Attribute and Fortify Skill effect on the potion against the corresponding Cap, where the potion is blocked IF Effective_Value plus Incoming_Magnitude is strictly greater than the Cap for any non-excluded stat.
2. IF any single Fortify effect on the potion would cause the Effective_Value plus the Incoming_Magnitude to be strictly greater than the Cap, THEN THE Global_Script SHALL block the potion from being consumed.
3. WHEN the potion is blocked due to the stat cap, THE Global_Script SHALL display a message informing the player that the stat limit would be exceeded.
4. IF the potion contains no Fortify Attribute or Fortify Skill effects, THEN THE Global_Script SHALL skip the cap evaluation and allow the potion to be consumed (subject to other rules).
5. IF all Fortify effects on the potion target Excluded_Stats, THEN THE Stat_Capper SHALL allow the potion to be consumed regardless of magnitude.
6. IF the potion contains a mix of Fortify effects targeting both excluded and non-excluded stats, THEN THE Stat_Capper SHALL evaluate only the non-excluded stats against the Cap.
7. IF the potion contains multiple Fortify effects targeting the same non-excluded stat, THEN THE Stat_Capper SHALL evaluate each effect independently against the current Effective_Value — the potion is blocked if any single effect alone would push the stat over the Cap.

### Requirement 2: Block Spell Casting When Fortify Exceeds Cap

**User Story:** As a player, I want to be prevented from casting a spell whose Fortify effects would push any non-excluded stat over the cap, so that I cannot exceed the stat limit through spellcasting.

#### Acceptance Criteria

1. WHEN the player attempts to cast a spell containing Fortify Attribute or Fortify Skill effects, THE Player_Script SHALL evaluate each such effect against the corresponding Cap.
2. WHEN any single Fortify effect on the spell would cause the Effective_Value plus the Incoming_Magnitude to exceed the Cap for a non-excluded stat, THE Player_Script SHALL block the spell from being cast.
3. WHEN the spell is blocked, THE Player_Script SHALL display a message informing the player that the stat limit would be exceeded.
4. WHEN the spell contains non-Fortify effects alongside Fortify effects, THE Player_Script SHALL still block the entire spell if any Fortify effect on a non-excluded stat would exceed the Cap.
5. WHEN all Fortify effects on the spell target Excluded_Stats, THE Stat_Capper SHALL allow the spell to be cast regardless of magnitude.
6. WHEN the spell contains a mix of Fortify effects targeting both excluded and non-excluded stats, THE Stat_Capper SHALL evaluate only the non-excluded stats against the Cap.

### Requirement 3: Block Cast When Used Enchantment When Fortify Exceeds Cap

**User Story:** As a player, I want to be prevented from using a Cast When Used enchanted item whose Fortify effects would push any non-excluded stat over the cap, so that I cannot exceed the stat limit through enchantments.

#### Acceptance Criteria

1. WHEN the player attempts to use an enchanted item (Cast When Used) containing Fortify Attribute or Fortify Skill effects, THE Player_Script SHALL evaluate each such effect against the corresponding Cap.
2. WHEN any single Fortify effect on the enchantment would cause the Effective_Value plus the Incoming_Magnitude to exceed the Cap, THE Player_Script SHALL block the enchantment from firing.
3. WHEN the enchantment is blocked, THE Player_Script SHALL display a message informing the player that the stat limit would be exceeded.
4. WHEN the enchantment contains non-Fortify effects alongside Fortify effects, THE Player_Script SHALL still block the entire enchantment from firing if any non-excluded Fortify effect would exceed the Cap.
5. WHEN all Fortify effects on the enchantment target Excluded_Stats, THE Stat_Capper SHALL allow the enchantment to fire regardless of magnitude.
6. WHEN the enchantment is blocked, THE Player_Script SHALL NOT consume the item's enchantment charge.

### Requirement 4: Block Equipping Items With Fortify Enchantments That Exceed Cap

**User Story:** As a player, I want to be prevented from equipping an item with a Constant Effect or Cast When Strikes Fortify enchantment that would push any non-excluded stat over the cap, so that I cannot exceed the stat limit through equipment.

#### Acceptance Criteria

1. WHEN the player attempts to equip an item with a Constant Effect enchantment containing Fortify Attribute or Fortify Skill effects, THE Player_Script SHALL evaluate each such effect against the corresponding Cap.
2. WHEN the player attempts to equip a weapon with a Cast When Strikes enchantment containing Fortify Attribute or Fortify Skill effects, THE Player_Script SHALL evaluate each such effect against the corresponding Cap.
3. WHEN any single Fortify effect on the enchantment would cause the Effective_Value plus the Incoming_Magnitude to exceed the Cap, THE Player_Script SHALL unequip the item on the same or next frame, returning it to the player's inventory.
4. WHEN the equip is blocked, THE Player_Script SHALL display a message informing the player that the stat limit would be exceeded.
5. WHEN all Fortify effects on the enchantment target Excluded_Stats, THE Stat_Capper SHALL allow the item to be equipped regardless of magnitude.
6. WHEN the enchantment contains a mix of Fortify effects targeting both excluded and non-excluded stats, THE Stat_Capper SHALL evaluate only the non-excluded stats against the Cap.

### Requirement 5: Cap Evaluation Formula

**User Story:** As a player, I want the cap check to consider only base value and active Fortify effects, ignoring Drain and Damage, so that the limit reflects my actual buffed power level.

#### Acceptance Criteria

1. THE Stat_Capper SHALL compute Effective_Value as the stat's base value plus the Fortify_Sum of all active Fortify effects on that stat, excluding Fortify effects that originate from spells listed in the exclusion tables for that stat.
2. THE Stat_Capper SHALL ignore Drain Attribute, Drain Skill, Damage Attribute, and Damage Skill effects when computing Effective_Value.
3. WHEN evaluating an incoming action, IF Effective_Value plus Incoming_Magnitude is strictly greater than the Cap for any non-excluded stat affected by the action, THEN THE Stat_Capper SHALL block the action.
4. WHEN evaluating an incoming action, IF Effective_Value plus Incoming_Magnitude is equal to or less than the Cap for all non-excluded stats affected by the action, THEN THE Stat_Capper SHALL allow the action to proceed.

### Requirement 6: Respect Exclusion System

**User Story:** As a player or mod author, I want the stat capping to respect the existing attribute and skill exclusion system, so that specific stats can be exempted from the cap.

#### Acceptance Criteria

1. WHEN an attribute is listed in config.attributes with an active excluded spell (i.e. `activeSpells:isSpellActive(spellId)` returns true for any spell ID in that attribute's list), THE Stat_Capper SHALL skip the cap check for that attribute.
2. WHEN a skill is listed in config.skills with an active excluded spell (i.e. `activeSpells:isSpellActive(spellId)` returns true for any spell ID in that skill's list), THE Stat_Capper SHALL skip the cap check for that skill.
3. WHEN an attribute is marked as skipped via the skipAttribute interface function, THE Stat_Capper SHALL skip the cap check for that attribute.
4. WHEN a skill is marked as skipped via the skipSkill interface function, THE Stat_Capper SHALL skip the cap check for that skill.
5. WHEN an attribute or skill is no longer excluded (excluded spell expires, or unskipAttribute/unskipSkill is called) and no other exclusion source remains active for that stat, THE Stat_Capper SHALL resume cap checks for that stat on the next Source_Action.
6. IF both a config-based exclusion and a runtime skip are active for the same stat, THEN THE Stat_Capper SHALL keep the stat excluded until all exclusion sources are removed (either source independently prevents capping).

### Requirement 7: Settings Control

**User Story:** As a player, I want the stat capping feature to be controlled by the existing statLimitEnabled toggle and attributeCap/skillCap settings, so that I can configure or disable the feature.

#### Acceptance Criteria

1. WHILE statLimitEnabled is false, THE Stat_Capper SHALL allow all Source_Actions regardless of Fortify magnitudes.
2. WHILE statLimitEnabled is true, THE Stat_Capper SHALL enforce the Cap on all Source_Actions.
3. WHEN the player changes attributeCap or skillCap at runtime, THE Stat_Capper SHALL use the new Cap value for all subsequent evaluations without removing or modifying already-active effects.
4. WHEN the player toggles statLimitEnabled from false to true, THE Stat_Capper SHALL begin enforcing the Cap on the next Source_Action without retroactively affecting already-active effects.
5. IF the player lowers attributeCap or skillCap below the current Effective_Value of a stat, THEN THE Stat_Capper SHALL block future Source_Actions that would add Fortify effects to that stat but SHALL NOT remove or modify already-active effects.

### Requirement 8: Independence from Potion Limit System

**User Story:** As a player, I want the stat capping system to operate independently from the potion overdose/knockout system, so that both features can coexist without interference.

#### Acceptance Criteria

1. THE Stat_Capper SHALL NOT trigger knockout, fatigue loss, or any penalty beyond blocking the Source_Action.
2. THE Stat_Capper SHALL NOT modify or clamp stat values of already-active effects.
3. WHILE potionLimitEnabled is true and statLimitEnabled is true, WHEN the player attempts to drink a potion, THE Global_Script SHALL evaluate potion limit rules and stat cap rules independently, blocking the potion if either rule triggers, and displaying only the message corresponding to the first rule that triggered.
4. WHEN a potion is blocked by the stat cap, THE Global_Script SHALL NOT count it toward the potion drink counter or assign it to a potion slot.
5. WHEN a potion is blocked by the potion limit system, THE Stat_Capper SHALL NOT evaluate or override that block.

### Requirement 9: Hotkey Potion Detection

**User Story:** As a player, I want potions consumed via hotkey to also be subject to the stat cap, so that the cap cannot be bypassed through hotkey usage.

#### Acceptance Criteria

1. WHILE statLimitEnabled is true, WHEN a new non-excluded potion activeSpellId appears in the player's active spells that was not present on the previous frame, THE Player_Script SHALL evaluate whether any non-excluded stat's Effective_Value now exceeds the corresponding Cap (attributeCap or skillCap).
2. IF the evaluation determines that any non-excluded stat exceeds the Cap after a hotkey-consumed potion's effects are applied, THEN THE Player_Script SHALL remove the potion's active spell entry via activeSpells:remove(activeSpellId) on the same frame as detection.
3. WHEN a hotkey potion's active spell is removed due to exceeding the Cap, THE Player_Script SHALL display a message informing the player that the stat limit was exceeded.
4. WHEN a potion consumed via hotkey targets only Excluded_Stats or is itself an excluded potion, THE Player_Script SHALL not evaluate or remove the potion's effects regardless of magnitude.
