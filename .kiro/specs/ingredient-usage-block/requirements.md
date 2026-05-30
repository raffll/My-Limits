# Requirements Document

## Introduction

Block the player from eating raw ingredients that are inconsumable by real-life standards — minerals, gems, ores, and metal scraps. The feature integrates into the existing ItemUsage handler system in the global script and reuses the pattern-matching approach from the potion exclusion system.

## Glossary

- **Ingredient_Block_System** — The subsystem that intercepts ingredient usage attempts and prevents consumption of blocked ingredients.
- **Blocked_Ingredient** — An ingredient whose record ID matches an entry in the block list (exact ID or wildcard pattern), and does not match any entry in the allow list.
- **Block_List** — A configurable list of exact ingredient record IDs and Lua patterns that identify ingredients the player cannot eat.
- **Allow_List** — A configurable list of exact ingredient record IDs and Lua patterns that override the block list, permitting consumption of specific ingredients that would otherwise be blocked.
- **Wildcard_Pattern** — A Lua string pattern (using `%`, `[]`, `+`, `*`, etc.) used to match multiple ingredient record IDs with a single entry.

## Requirements

### Requirement 1: Block Ingredient Consumption

**User Story:** As a player, I want to be prevented from eating minerals, gems, ores, and metal scraps, so that ingredient usage feels grounded in reality.

#### Acceptance Criteria

1. WHEN the player attempts to eat a Blocked_Ingredient via the inventory UI, THE Ingredient_Block_System SHALL prevent the consumption and display a HUD message indicating the ingredient cannot be consumed.
2. THE Ingredient_Block_System SHALL identify a Blocked_Ingredient by checking the ingredient record ID against the Block_List, which is defined as a static array of string entries in the mod configuration loaded at script initialization.
3. WHEN an ingredient record ID matches any entry in the Block_List by exact string equality or by Lua pattern match (using `string.match` syntax), THE Ingredient_Block_System SHALL treat the ingredient as blocked.
4. WHEN an ingredient record ID matches any entry in the Allow_List by exact string equality or by Lua pattern match, THE Ingredient_Block_System SHALL permit consumption regardless of Block_List matches.
5. THE Ingredient_Block_System SHALL evaluate the Allow_List before the Block_List, so that allow entries take precedence.
6. IF the player consumes a Blocked_Ingredient via a quick-key hotkey (bypassing the inventory UI handler), THEN THE Ingredient_Block_System SHALL still detect the consumption and apply the same blocking feedback on the next frame.
7. THE Ingredient_Block_System SHALL only block eating (direct consumption for effects); using a Blocked_Ingredient as an alchemy component SHALL remain permitted.

### Requirement 2: Default Block List

**User Story:** As a player, I want a sensible default set of blocked ingredients out of the box, so that the feature works without manual configuration.

#### Acceptance Criteria

1. THE Block_List SHALL include the following vanilla Morrowind ingredient record IDs by default: `ingred_diamond_01`, `ingred_emerald_01`, `ingred_ruby_01`, `ingred_raw_ebony_01`, `ingred_raw_glass_01`, `ingred_scrap_metal_01`.
2. THE Block_List SHALL include the following Tribunal ingredient record IDs by default: `ingred_adamantium_ore_01`.
3. THE Block_List SHALL include the following Bloodmoon ingredient record IDs by default: `ingred_raw_stalhrim_01`.
4. THE Block_List SHALL include the following Daedric cursed variant record IDs by default: `ingred_dae_cursed_diamond_01`, `ingred_dae_cursed_raw_ebony_01`, `ingred_dae_cursed_emerald_01`, `ingred_dae_cursed_ruby_01`, `ingred_dae_cursed_pearl_01`.
5. THE Block_List SHALL include the following miscellaneous variant record IDs by default: `ingred_raw_glass_tinos`.
6. THE Block_List SHALL include the Wildcard_Pattern `^t_ingmine_` by default to block all Tamriel Data mineral ingredients.
7. THE Allow_List SHALL include `t_ingmine_salt_01` by default to permit consumption of salt despite the Tamriel Data mineral pattern.
8. WHEN the System evaluates whether an ingredient is blocked, IF the ingredient record ID matches an entry in the Allow_List by case-insensitive exact comparison, THEN THE System SHALL treat the ingredient as not blocked regardless of any matching Wildcard_Pattern in the Block_List.
9. THE System SHALL match Block_List record IDs by case-insensitive exact string comparison and SHALL match Wildcard_Pattern entries using Lua pattern syntax against the full ingredient record ID.

### Requirement 3: Feature Toggle

**User Story:** As a player, I want to enable or disable the ingredient blocking feature, so that I can choose whether to use it.

#### Acceptance Criteria

1. THE Ingredient_Block_System SHALL provide a boolean setting named `ingredientBlockEnabled` in the settings page, using the checkbox renderer.
2. WHILE `ingredientBlockEnabled` is set to false, THE Ingredient_Block_System SHALL permit consumption of all ingredients without preventing the action or displaying a feedback message.
3. THE Ingredient_Block_System SHALL default `ingredientBlockEnabled` to true.
4. WHEN the player changes the `ingredientBlockEnabled` setting mid-session, THE Ingredient_Block_System SHALL apply the new value immediately without requiring a game restart or reload.

### Requirement 4: Feedback Message

**User Story:** As a player, I want to see a clear message when I try to eat a blocked ingredient, so that I understand why the action failed.

#### Acceptance Criteria

1. WHEN the player attempts to eat a Blocked_Ingredient and consumption is prevented, THE Ingredient_Block_System SHALL send a `sptLimitsShowMessage` event to the player containing a localized message that indicates the ingredient cannot be used right now.
2. THE Ingredient_Block_System SHALL use the existing event-based messaging mechanism (`sptLimitsShowMessage`) to display the feedback message, following the same pattern used for blocked potions.
3. THE Ingredient_Block_System SHALL display the feedback message exactly once per blocked consumption attempt.

### Requirement 5: Pattern Matching

**User Story:** As a mod author, I want to use wildcard patterns in the block and allow lists, so that I can target entire categories of ingredients with a single entry.

#### Acceptance Criteria

1. WHEN an entry in the Block_List or Allow_List contains one or more Lua pattern metacharacters (`%`, `[`, `]`, `.`, `+`, `-`, `*`, `?`, `^`, `$`, `(`, `)`), THE Ingredient_Block_System SHALL treat the entry as a Wildcard_Pattern and match it against ingredient record IDs using `string.match`, where any non-nil return value constitutes a match.
2. WHEN an entry in the Block_List or Allow_List contains no Lua pattern metacharacters, THE Ingredient_Block_System SHALL treat the entry as an exact ID and match using direct equality comparison.
3. THE Ingredient_Block_System SHALL convert both the ingredient record ID and the list entry to lowercase before performing either pattern matching or exact comparison.
4. IF a Wildcard_Pattern entry is a malformed Lua pattern that causes `string.match` to error, THEN THE Ingredient_Block_System SHALL skip that entry without blocking or allowing any ingredient and shall not halt list processing for remaining entries.
5. WHEN a Wildcard_Pattern contains no anchor metacharacters (`^` or `$`), THE Ingredient_Block_System SHALL match it against any substring of the ingredient record ID (standard Lua `string.match` semantics).

### Requirement 6: Integration with Existing Systems

**User Story:** As a developer, I want the ingredient blocking to integrate cleanly with the existing mod architecture, so that the codebase remains cohesive.

#### Acceptance Criteria

1. THE Ingredient_Block_System SHALL register an ItemUsage handler for the Ingredient type (`types.Ingredient`) in the global script, following the same guard-and-return pattern used by the existing Potion handler.
2. IF the actor attempting to use the ingredient is not the player (fails `types.Player.objectIsInstance` check), THEN THE Ingredient_Block_System SHALL return nil to permit the action without blocking.
3. THE Ingredient_Block_System SHALL read the Block_List and Allow_List from the shared config module (`config.lua`) at load time.
4. THE Ingredient_Block_System SHALL receive the enabled/disabled toggle state via the existing settings-update event (`sptLimitsSettingsUpdate`) and skip all blocking logic when the toggle is disabled.
