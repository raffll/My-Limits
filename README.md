# Stats, Potions, and Training Limits (OpenMW)

------------------------------------------------------------

This mod introduces attributes, skills, training, and potion consumption limits for players that like to constrain themselves. This will make a game more challenging, tactical, creative, and fun. Forces you to more often create multi-effect potions and plan your training carefully.

OpenMW only, pure Lua edition. No ESP file required.

This is my second approach to creating a cap on attributes, but this time it is not that deadly. I also incorporated potion consumption limits, heavily based on the Alchemical Hustle mod. It can be used as a replacement for the "Toxicity" module.

**Now with a new HUD counter for potion tracking.**

------------------------------------------------------------

### Configuration

All settings are in `scripts/spt_limits/config.lua`. Edit the file directly to change values.

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
- `potions` — List of potion record IDs that don't count toward the limit. Supports wildcards (e.g. `"sd_*"`).
- `attributes` — Per-attribute lists of spell IDs that bypass the attribute cap while active.
- `skills` — Per-skill lists of spell IDs that bypass the skill cap while active (e.g. Scroll of Icarian Flight for Acrobatics).

------------------------------------------------------------

### Negative Effect

Once the player exceeds the attribute or skill cap, fatigue is set to 0, leaving the player collapsed on the ground. The only way to recover is to wait until your stats go back below the cap.

- While collapsed, you can't drink or create potions, enchant, or repair.
- To recover, get rid of the fortify effect (wait it out, dispel, etc.).
- For most vanilla items, waiting 1 hour is enough.
- Keep in mind that when you levitate, you cannot wait.
- After recovery, your fatigue bar starts at 0.

------------------------------------------------------------

### Potion Limit

- After every potion drunk, a 20-second cooldown timer starts.
- Every time you drink another potion while the timer is running, your drink counter increases and the timer resets.
- If you reach the limit (default: 3), you can't drink another one via the normal inventory UI.
- **Hotkey bypass punishment:** If you use a hotkey to drink past the limit, your character collapses (overdose). A second hotkey drink while collapsed causes death.
- The HUD counter in the bottom-right shows: `countdown drinks/limit`.
- Waiting or sleeping for more than 1 hour clears the cooldown immediately.

------------------------------------------------------------

### Attribute Cap

Fixed at the configured value (default: `300`). Any attribute exceeding this value triggers the collapse.

**Exception:** The Scroll of Icarian Flight (`sc_icarianflight_en`) bypasses the Acrobatics skill cap while active.

------------------------------------------------------------

### Skill Cap

Fixed at the configured value (default: `150`). Any skill exceeding this value triggers the collapse.

------------------------------------------------------------

### Training Limit

You can train only 5 times per level (configurable). The counter resets when you level up. If you've used all sessions, the trainer will refuse and the dialogue window closes.

------------------------------------------------------------

### Lua Interface for Other Mods

This mod exposes a `StatsAndPotionsLimit` interface (version 1) that other mods can use:

```lua
local I = require('openmw.interfaces').StatsAndPotionsLimit

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

### File Structure

```
Stats & Potions Limit.omwscripts   — Script registration
scripts/spt_limits/
├── config.lua    — All configurable values and exclusion lists
├── player.lua    — Core logic (stat checks, potion detection, knockout, interface)
├── global.lua    — Item usage blocking (potions, apparatus, repair, misc)
└── counter.lua   — HUD potion counter (MENU script)
l10n/spt_limits/
└── en.yaml       — English localization strings
```

------------------------------------------------------------

### Changelog

```
2.0
- Complete rewrite to pure OpenMW Lua. ESP file is no longer needed.
- All MWScript logic replaced with Lua player/global scripts.
- State persistence via Lua storage (proper save/load support).
- Configuration moved to config.lua (no more in-game settings menu).
- Lua interface exposed for other mods (excludePotion, skipAttribute, skipSkill, etc.).
- HUD counter for potion tracking.
- Potion detection via active spell counting (works with hotkeys).
- Overdose/death system for hotkey bypass.
- Hour-skip detection clears cooldown on wait/sleep.
1.14
- Added constant potion limit.
- Removed potion limit by Alchemy.
- Counter bug fixes.
1.13
- Counter added to HUD.
- Speed exception removed.
- Acrobatics exception changed to work only with Scroll of Icarian Flight.
1.12
- Fixed error message when NPCs are drinking potions.
1.11
- Training limit drops all windows for better compatibility with real-time menu mods.
- Lua interfaces added.
1.10
- Training limit money and time loss fix.
1.9
- Training limit bugfix.
1.8
- "You have recovered from the potion toxic effect!" message removed.
- More natural training limit message.
1.7
- Potion limit based on level option added.
- Constant limit for stats option added.
- Training limit module added.
1.6
- "You have reached the limit of potions!" message removed.
- Both options merged into one esp.
- Settings menu created.
1.5
- Cleaning up and rewriting some scripts.
- Now you can't drink potions over the limit.
1.4
- Potion limit only added.
- Fix for invisibility potion issue, but cooldown indicator is disabled in this version.
1.3
- Use Lua to block the alchemy, enchant, and repair windows instead of dropping skills to 0.
1.2
- Negative effect increased from 2000 to 100000 (to prevent using strong restore potions).
1.1
- Strength, Intelligence, and Luck also drop to 0 (to prevent using 800+ fortify spells).
- Negative effect increased from 1000 to 2000.
- Potion timer bugfix.
1.0
- Initial version.
```

------------------------------------------------------------

### Compatibility

- Incompatible with mods that override fatigue calculation (this mod uses the standard formula: Str + Wil + Agi + End).
- Currently incompatible with "Potion Thrower".
- Other mods can use the Lua interface to exclude their potions/food items from counting.

------------------------------------------------------------

### Credits

Thanks to Rosynant for creating "Alchemical Hustle", from which I took the idea of how to limit potions.

------------------------------------------------------------

### Permissions

Do whatever you want. Just credit me.
