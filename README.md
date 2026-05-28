# Stats, Potions, and Training Limits (OpenMW)

Introduces configurable limits on attributes, skills, potion consumption, and training sessions. OpenMW only, pure Lua, rewritten from scratch.

## Installation

Requires OpenMW 0.49+. Copy `SPT Limits.omwscripts`, the `scripts/` folder, and the `l10n/` folder into your data path. Add to `openmw.cfg`:

```
content=SPT Limits.omwscripts
```

## Configuration

All settings are configurable in-game via the OpenMW settings menu under **SPT Limits**. Changes take effect immediately and are saved per-save. Defaults come from `scripts/sptLimits/config.lua`.

**Potions group:**
- `Potion Limit` — Enable the potion drinking limit (default: on).
- `Max Potions` — Maximum number of potions allowed before the cooldown resets (default: `3`).
- `Potion Cooldown` — Seconds before the potion counter resets (default: `20`).
- `HUD Counter` — Show the potion drink counter on the HUD (default: on).
- `Exclude Sun's Dusk Potions` — Potions from the Sun's Dusk mod do not count toward the limit (default: on).

**Stats group:**
- `Stat Limit` — Enable attribute and skill caps (default: on).
- `Attribute Cap` — Maximum value for any attribute (default: `300`).
- `Skill Cap` — Maximum value for any skill (default: `150`).

**Training group:**
- `Training Limit` — Enable the per-level training session limit (default: on).
- `Max Training Sessions` — Maximum training sessions allowed per level (default: `5`).

**Config-file only (edit `scripts/sptLimits/config.lua` directly):**
- `potions` — Potion record IDs that bypass the limit. Supports Lua patterns (e.g. `"^sd_.*"`).
- `attributes` — Per-attribute spell IDs that bypass the cap while active.
- `skills` — Per-skill spell IDs that bypass the cap while active (e.g. Scroll of Icarian Flight for Acrobatics).

## Stat Cap

If any attribute exceeds the Attribute Cap or any skill exceeds the Skill Cap, your character collapses (fatigue drops to 0). To recover, wait for the fortify effect to expire or dispel it.

- While collapsed, you can't create potions, enchant, or repair.
- For most vanilla items, waiting 1 hour is enough.
- Keep in mind that you cannot wait while levitating.
- After recovery, your fatigue bar starts at 0.

## Potion Limit

- Each potion drunk starts a cooldown timer (default: 20 seconds).
- Drinking another potion during cooldown increments the counter and resets the timer.
- At the limit (default: 3), the inventory UI blocks further drinks.
- Waiting or sleeping at least 1 hour clears the cooldown immediately.
- HUD counter in the bottom-right shows countdown, drinks, and limit — e.g. `14.2s 2/3`.
- **Exception:** Hotkeys bypass the inventory block. Drinking via hotkey past the limit causes overdose collapse.

## Training Limit

You can train 5 times per level (configurable). The counter resets on level up. Once reached, the Training window is suppressed with a message.

## Lua Interface

Other mods can use `require('openmw.interfaces').sptLimits`:

- `isKnockedOut()` — returns whether the player is collapsed
- `excludePotion(id)` / `includePotion(id)` — manage potion exclusions at runtime
- `skipAttribute(name)` / `unskipAttribute(name)` — temporarily bypass an attribute cap
- `skipSkill(name)` / `unskipSkill(name)` — temporarily bypass a skill cap

## Compatibility

- Incompatible with mods that override fatigue calculation (uses Str + Wil + Agi + End).
- Should be compatible with Potion Thrower if loaded after this mod.
- Other mods can use the Lua interface to exclude their potions/food items.

## Permissions

Do whatever you want. Just credit me.

## Changelog

```
2.0alpha3
- Added in-game settings page (Potions, Stats, Training groups).
- Fixed HUD counter showing stale values from a previous save when starting a new game.
- Fixed excludeSunsDusk setting toggle not being respected by hotkey drink detection.

2.0alpha2
- HUD counter can be toggled off via hudCounterEnabled.

2.0alpha
- Complete rewrite to pure OpenMW Lua.
- Configuration moved to config.lua.
- Progressive limits for stats and potions removed.
- Training limit window flicker fixed.
- Counter now works while in real time menu.
- Option to exclude Sun's Dusk potions.
- Option to exclude any potion.
- Option to disable stat limit while spell active.
```
