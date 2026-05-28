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
- `Potion Limit` — enable the potion drinking limit (default: on)
- `Tracking Mode` — choose between Counter (shared cooldown) and Slots (individual per-potion tracking) (default: `counter`)
- `HUD Counter` — show the potion HUD element (default: on)
- `Exclude Sun's Dusk Potions` — potions from the Sun's Dusk mod do not count toward the limit (default: on)

**Potions — Counter Mode:**
- `Max Potions` — maximum number of potions allowed before the cooldown resets (default: `3`)
- `Potion Cooldown` — game-time seconds before the potion counter resets (default: `20`)

**Potions — Slots Mode:**
- `Potion Slots` — number of potion slots available (default: `4`, max: `10`)

**Stats group:**
- `Stat Limit` — enable attribute and skill caps (default: on)
- `Attribute Cap` — maximum value for any attribute (default: `300`)
- `Skill Cap` — maximum value for any skill (default: `150`)

**Training group:**
- `Training Limit` — enable the per-level training session limit (default: on)
- `Max Training Sessions` — maximum training sessions allowed per level (default: `5`)

**Config-file only (edit `scripts/sptLimits/config.lua` directly):**
- `potions` — potion record IDs that bypass the limit. Supports Lua patterns (e.g. `"^sd_.*"`)
- `attributes` — per-attribute spell IDs that bypass the cap while active
- `skills` — per-skill spell IDs that bypass the cap while active (e.g. Scroll of Icarian Flight for Acrobatics)

## Stat Cap

If any attribute exceeds the Attribute Cap or any skill exceeds the Skill Cap, your character collapses (fatigue drops to 0). To recover, wait for the fortify effect to expire or dispel it.

- While collapsed, you can't create potions, enchant, or repair.
- For most vanilla items, waiting 1 game-hour is enough.
- Keep in mind that you cannot wait while levitating.
- After recovery, your fatigue bar starts at 0.

## Potion Limit — Counter Mode

- Each potion drunk starts a cooldown timer (default: 20 game-seconds).
- Drinking another potion during cooldown increments the counter and resets the timer.
- At the limit (default: 3), the inventory UI blocks further drinks.
- Waiting or sleeping at least 1 game-hour clears the cooldown immediately.
- HUD counter in the bottom-right shows countdown, drinks, and limit — e.g. `14.2s 2/3`.
- **Exception:** Hotkeys bypass the inventory block. Drinking via hotkey past the limit causes overdose collapse.

## Potion Limit — Slots Mode

- Each potion drink occupies one slot. Slots track individual potion durations independently.
- When all normal slots are full, the inventory UI blocks further drinks.
- Drinking via hotkey when all slots are full fills the overflow slot and causes overdose collapse.
- Slots free up when their potion effect expires or is dispelled.
- HUD shows each occupied slot with its remaining duration and effect icon.
- The overflow slot is displayed in red.

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
- Should be compatible with Potion Thrower as long as Potion Thrower is loaded after this mod.
- Other mods can use the Lua interface to exclude their potions/food items.

## Permissions

Do whatever you want. Just credit me.

## Changelog

```
2.0alpha3
- Added in-game settings page (Potions, Stats, Training groups).
- Added Slots tracking mode as an alternative to the Counter mode.
- Bug fixes.

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
