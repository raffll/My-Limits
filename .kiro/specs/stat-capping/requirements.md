# Requirements Document

## Introduction

Replace the current stat-limit knockout behavior with actual stat capping. Instead of collapsing the player when attributes or skills exceed the configured cap, the mod directly clamps the stat modifier so the effective (modified) value never exceeds the cap. The potion overdose collapse feature remains unchanged.

## Glossary

- **Stat_Capper**: The module responsible for clamping attribute and skill modifiers each frame
- **Attribute_Stat**: An OpenMW `AttributeStat` object accessed via `types.Actor.stats.attributes[name](self)`
- **Skill_Stat**: An OpenMW `SkillStat` object accessed via `types.NPC.stats.skills[name](self)`
- **Modified_Value**: The effective stat value computed as `max(0, base - damage + modifier)`, visible to the player and game systems
- **Base_Value**: The permanent stat value without any active modifiers
- **Damage**: The `.damage` field representing how much the stat has been damaged (Damage Attribute/Skill effects). Reduces the effective value without changing base.
- **Modifier**: The writable `.modifier` field on an attribute or skill stat, representing the sum of all Fortify/Drain effects. Recalculated by the engine each frame from active spells, but Lua writes applied after recalculation override it until the next frame.
- **Cap**: The user-configured maximum allowed modified value (`attributeCap` for attributes, `skillCap` for skills)
- **Excluded_Stat**: An attribute or skill that is skipped during capping (via config exclusion lists or the Lua interface)

## Requirements

### Requirement 1: Clamp Attribute Modified Values

**User Story:** As a player, I want my attributes to be hard-capped at the configured limit, so that Fortify effects cannot push my stats beyond the cap.

#### Acceptance Criteria

1. WHILE the stat limit feature is enabled, WHEN any non-excluded attribute's base value plus its current modifier exceeds the configured attributeCap (integer, range 1–999, default 300), THE Stat_Capper SHALL set the modifier of that attribute to (attributeCap minus base value) so that the Modified_Value equals exactly the attributeCap
2. WHILE the stat limit feature is enabled, WHEN an attribute's base value already exceeds the attributeCap, THE Stat_Capper SHALL set the modifier to zero for that attribute
3. WHILE the stat limit feature is enabled, WHEN an attribute's base value plus its current modifier is less than or equal to the attributeCap, THE Stat_Capper SHALL leave the modifier unchanged
4. THE Stat_Capper SHALL NOT modify attributes that are marked as excluded via the exclusion list in config or via the runtime skipAttribute interface
5. THE Stat_Capper SHALL recalculate attribute modifiers every frame during the onUpdate cycle, applying changes within a single frame of the modifier exceeding the cap

### Requirement 2: Clamp Skill Modified Values

**User Story:** As a player, I want my skills to be hard-capped at the configured limit, so that Fortify effects cannot push my skills beyond the cap.

#### Acceptance Criteria

1. WHILE the stat limit feature is enabled, WHEN any non-excluded skill's base value plus its current modifier exceeds the configured skillCap (integer, range 1–999, default 150), THE Stat_Capper SHALL set the modifier of that skill to (skillCap minus base value) so that the Modified_Value equals exactly the skillCap
2. WHILE the stat limit feature is enabled, WHEN a skill's base value already exceeds the skillCap, THE Stat_Capper SHALL set the modifier to zero for that skill
3. WHILE the stat limit feature is enabled, WHEN a skill's base value plus its current modifier is less than or equal to the skillCap, THE Stat_Capper SHALL leave the modifier unchanged
4. THE Stat_Capper SHALL NOT modify skills that are marked as excluded via the exclusion list in config or via the runtime skipSkill interface
5. THE Stat_Capper SHALL recalculate skill modifiers every frame during the onUpdate cycle, applying changes within a single frame of the modifier exceeding the cap

### Requirement 3: Respect Stat Exclusions

**User Story:** As a player, I want certain stats to remain uncapped when excluded via config or the Lua interface, so that specific gameplay effects are preserved.

#### Acceptance Criteria

1. WHILE a spell listed in an attribute's config exclusion list is active on the player, THE Stat_Capper SHALL skip capping that attribute and leave its modifier unchanged
2. WHILE a spell listed in a skill's config exclusion list is active on the player, THE Stat_Capper SHALL skip capping that skill and leave its modifier unchanged
3. WHILE an attribute is marked as skipped via the Lua interface (skipAttribute), THE Stat_Capper SHALL skip capping that attribute and leave its modifier unchanged
4. WHILE a skill is marked as skipped via the Lua interface (skipSkill), THE Stat_Capper SHALL skip capping that skill and leave its modifier unchanged
5. WHEN a previously skipped attribute is unmarked via the Lua interface (unskipAttribute), THE Stat_Capper SHALL resume capping that attribute on the next frame
6. WHEN a previously skipped skill is unmarked via the Lua interface (unskipSkill), THE Stat_Capper SHALL resume capping that skill on the next frame
7. IF no excluded spell from the config list is active AND the stat is not skipped via the Lua interface, THEN THE Stat_Capper SHALL enforce the configured cap for that stat

### Requirement 4: Remove Stat-Limit Knockout Behavior

**User Story:** As a player, I want the mod to cap my stats directly instead of knocking me out, so that gameplay is not interrupted by collapse when stats exceed the limit.

#### Acceptance Criteria

1. WHILE the stat limit feature is enabled, IF an attribute's modified value exceeds the configured attributeCap, THEN THE Player_Script SHALL clamp that attribute via the Stat_Capper instead of triggering knockout
2. WHILE the stat limit feature is enabled, IF a skill's modified value exceeds the configured skillCap, THEN THE Player_Script SHALL clamp that skill via the Stat_Capper instead of triggering knockout
3. WHILE the stat limit feature is enabled, THE Player_Script SHALL not set fatigue to a negative value and SHALL not set fatigue base to zero as a result of attributes or skills exceeding the cap
4. WHILE the stat limit feature is enabled, THE Player_Script SHALL not display the attributeLimit or skillLimit localized warning messages when attributes or skills exceed the cap
5. WHILE the potion limit feature is enabled, THE Player_Script SHALL continue to trigger knockout by setting fatigue to -1 when potion overdose is detected, independent of the stat limit capping behavior

### Requirement 5: Restore Original Modifier When Feature Is Disabled

**User Story:** As a player, I want my stat modifiers to return to their natural values when I disable the stat limit feature mid-session, so that I regain the full benefit of my active effects.

#### Acceptance Criteria

1. WHEN the statLimitEnabled setting is changed from enabled to disabled, THE Stat_Capper SHALL stop evaluating attribute modifiers against the attribute cap on subsequent frames
2. WHEN the statLimitEnabled setting is changed from enabled to disabled, THE Stat_Capper SHALL stop evaluating skill modifiers against the skill cap on subsequent frames
3. WHEN the statLimitEnabled setting is changed from enabled to disabled, THE engine SHALL naturally restore each modifier to its unclamped value on the next frame because the Stat_Capper is no longer overriding it

### Requirement 6: Cap Value Changes Apply Immediately

**User Story:** As a player, I want changes to the attributeCap or skillCap settings to take effect immediately, so that I can tune the limits without reloading.

#### Acceptance Criteria

1. WHEN the attributeCap setting value changes, THE Stat_Capper SHALL compare each attribute's modified value against the new attributeCap value starting on the next frame
2. WHEN the skillCap setting value changes, THE Stat_Capper SHALL compare each skill's modified value against the new skillCap value starting on the next frame

### Requirement 7: Capping Formula

**User Story:** As a developer, I want a clear capping formula, so that the modifier adjustment is deterministic and correct.

#### Acceptance Criteria

1. THE engine computes modified as `max(0, base - damage + modifier)`. WHEN this modified value is strictly greater than the cap AND the modifier is positive, THE Stat_Capper SHALL set the modifier to `max(0, cap - base + damage)`, resulting in a modified value equal to the cap (or equal to base - damage if cap - base + damage is negative)
2. WHEN a stat's base minus damage already exceeds the cap (i.e. base - damage > cap) and the modifier is positive, THE Stat_Capper SHALL set the modifier to zero
3. WHEN a stat's modifier is zero or negative (Drain effects or no buffs), THE Stat_Capper SHALL leave the modifier unchanged regardless of whether the modified value exceeds the cap
4. IF a stat is marked as excluded via the exclusion list or the skipAttribute/skipSkill interface, THEN THE Stat_Capper SHALL skip that stat and leave its modifier unchanged
5. THE Stat_Capper SHALL account for the damage field in its calculations so that Damage Attribute/Skill effects interact correctly with the cap
