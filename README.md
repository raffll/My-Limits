# Stats, Potions, and Training Limits (OpenMW)

Introduces configurable limits on attributes, skills, potion consumption, and training sessions. OpenMW only, pure Lua, rewritten from scratch.

## Installation

Requires OpenMW 0.49+. Copy `Stats & Potions Limit.omwscripts` and the `scripts/` folder into your data path. Add to `openmw.cfg`:

```
content=Stats & Potions Limit.omwscripts
```

## Configuration

All settings are in `scripts/sptLimits/config.lua`. Edit the file directly.

**Toggles:**
- `potionLimitEnabled` — Enable potion consumption limit (default: `true`).
- `statLimitEnabled` — Enable attribute/skill cap enforcement (default: `true`).
- `trainingLimitEnabled` — Enable training session limit (default: `true`).

**Limits:**
- `attributeCap` — Maximum allowed attribute value (default: `300`).
- `skillCap` — Maximum allowed skill value (default: `150`).
- `potionLimit` — Potions allowed per cooldown window (default: `3`).
- `trainingLimit` — Training sessions allowed per level (default: `5`).
- `potionCooldown` — Cooldown window in seconds (default: `20`).

**Exclusions:**
- `excludeSunsDusk` — Automatically exclude Sun's Dusk survival mod potions from the limit (default: `true`).
- `potions` — Potion record IDs that bypass the limit. Supports Lua patterns (e.g. `"^sd_.*"`).
- `attributes` — Per-attribute spell IDs that bypass the cap while active.
- `skills` — Per-skill spell IDs that bypass the cap while active (e.g. Scroll of Icarian Flight for Acrobatics).

## Stat Cap

If any attribute exceeds `attributeCap` or any skill exceeds `skillCap`, your character collapses (fatigue drops to 0). To recover, wait for the fortify effect to expire or dispel it.

- While collapsed, you can't create potions, enchant, or repair.
- For most vanilla items, waiting 1 hour is enough.
- Keep in mind that you cannot wait while levitating.
- After recovery, your fatigue bar starts at 0.

## Potion Limit

- Each potion drunk starts a 20-second cooldown timer.
- Drinking another potion during cooldown increments the counter and resets the timer.
- At the limit (default: 3), the inventory UI blocks further drinks.
- Waiting or sleeping 1+ hour clears the cooldown immediately.
- HUD counter in the bottom-right shows: `countdown drinks/limit`.
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
