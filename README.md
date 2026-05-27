# Stats, Potions, and Training Limits (OpenMW)

------------------------------------------------------------

This mod introduces attributes, skills, training, and potion consumption limits for players that like to constrain themselves. This will make a game more challenging, tactical, creative, and fun. Forces you to more often create multi-effect potions and plan your training carefully.

OpenMW only, pure Lua edition, rewritten from scratch.

------------------------------------------------------------

### Configuration

All settings are in `scripts/sptLimits/config.lua`. Edit the file directly to change values.

**Toggles:**
- `potionLimitEnabled` — Enable/disable the potion consumption limit (default: `true`).
- `statLimitEnabled` — Enable/disable attribute and skill cap enforcement (default: `true`).
- `trainingLimitEnabled` — Enable/disable the training session limit (default: `true`).

**Limits:**
- `attributeCap` — Maximum allowed attribute value (default: `300`).
- `skillCap` — Maximum allowed skill value (default: `150`).
- `potionLimit` — Number of potions allowed per cooldown window (default: `3`).
- `trainingLimit` — Training sessions allowed per level (default: `5`).
- `potionCooldown` — Cooldown window in seconds (default: `20`).

**Exclusions:**
- `potions` — List of potion record IDs that don't count toward the limit. Supports Lua patterns (e.g. `"^sd_.*"`).
- `attributes` — Per-attribute lists of spell IDs that bypass the attribute cap while active.
- `skills` — Per-skill lists of spell IDs that bypass the skill cap while active (e.g. Scroll of Icarian Flight for Acrobatics).

------------------------------------------------------------

### Negative Effect

Once the player exceeds the attribute or skill cap, fatigue is set to 0, leaving the player collapsed on the ground. The only way to recover is to wait until your stats go back below the cap.

- While collapsed, you can't create potions, enchant, or repair.
- To recover, get rid of the fortify effect (wait it out, dispel, etc.).
- For most vanilla items, waiting 1 hour is enough.
- Keep in mind that when you levitate, you cannot wait.
- After recovery, your fatigue bar starts at 0.

------------------------------------------------------------

### Potion Limit

- After every potion drunk, a 20-second cooldown timer starts.
- Every time you drink another potion while the timer is running, your drink counter increases and the timer resets.
- If you reach the limit (default: 3), you can't drink another one via the normal inventory UI.
- If you use a hotkey to drink past the limit, your character collapses from overdose.
- The HUD counter in the bottom-right shows: `countdown drinks/limit`.
- Waiting or sleeping for more than 1 hour clears the cooldown immediately.

------------------------------------------------------------

### Attribute Cap

Fixed at the configured value (default: `300`). Any attribute exceeding this value triggers the collapse.

------------------------------------------------------------

### Skill Cap

Fixed at the configured value (default: `150`). Any skill exceeding this value triggers the collapse.

**Exception:** The Scroll of Icarian Flight (`sc_icarianflight_en`) bypasses the Acrobatics skill cap while active.

------------------------------------------------------------

### Training Limit

You can train only 5 times per level (configurable). The counter resets when you level up. If you've used all sessions, the Training window is suppressed and the dialogue closes with a message.

------------------------------------------------------------

### Lua Interface for Other Mods

This mod exposes a `sptLimits` interface (version 1) that other mods can use:

```lua
local I = require('openmw.interfaces').sptLimits

-- Check if the player is currently knocked out
I.isKnockedOut()  -- returns boolean

-- Exclude a potion from counting toward the limit
I.excludePotion("my_food_item_01")

-- Re-include a previously excluded potion
I.includePotion("my_food_item_01")

-- Temporarily skip an attribute from limit checks
I.skipAttribute("luck")

-- Re-enable an attribute for limit checks
I.unskipAttribute("luck")

-- Temporarily skip a skill from limit checks
I.skipSkill("alchemy")

-- Re-enable a skill for limit checks
I.unskipSkill("alchemy")
```

**Valid attribute names:** strength, intelligence, willpower, agility, speed, endurance, personality, luck

**Valid skill names:** alchemy, longblade, acrobatics, bluntweapon, enchant, security, axe, conjuration, sneak, armorer, alteration, lightarmor, mediumarmor, destruction, marksman, heavyarmor, mysticism, shortblade, spear, restoration, handtohand, block, illusion, mercantile, athletics, unarmored, speechcraft

------------------------------------------------------------

### Changelog

```
2.0
- Complete rewrite to pure OpenMW Lua. ESP file is no longer needed.
- Configuration moved to config.lua.
- Lua interface exposed for other mods.
- Progressive limits for stats and potions removed.
- Training limit window flicker fixed.
- Counter now works while in real time menu.
- Option to exclude Sun's Dusk potions.
- Option to exclude any potions.
- Option to disable stat limit while spell active.
```

------------------------------------------------------------

### Compatibility

- Incompatible with mods that override fatigue calculation (this mod uses the standard formula: Str + Wil + Agi + End).
- Other mods can use the Lua interface to exclude their potions/food items from counting.

------------------------------------------------------------

### Permissions

Do whatever you want. Just credit me.
