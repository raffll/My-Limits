[center][b][size=6]Stats, Potions, and Training Limits (OpenMW)[/size][/b][/center]


Introduces configurable limits on attributes, skills, potion consumption, and training sessions. OpenMW only, pure Lua, rewritten from scratch.

------------------------------------------------------------

[size=4][b]Installation[/b][/size]

Requires OpenMW 0.49+. Copy Stats & Potions Limit.omwscripts and the scripts/ folder into your data path. Add to openmw.cfg:

[code]content=Stats & Potions Limit.omwscripts[/code]

------------------------------------------------------------

[size=4][b]Configuration[/b][/size]

All settings are in scripts/sptLimits/config.lua. Edit the file directly.

[b]Toggles:[/b]

- potionLimitEnabled — Enable potion consumption limit (default: true).
- statLimitEnabled — Enable attribute/skill cap enforcement (default: true).
- trainingLimitEnabled — Enable training session limit (default: true).

[b]Limits:[/b]

- attributeCap — Maximum allowed attribute value (default: 300).
- skillCap — Maximum allowed skill value (default: 150).
- potionLimit — Potions allowed per cooldown window (default: 3).
- trainingLimit — Training sessions allowed per level (default: 5).
- potionCooldown — Cooldown window in seconds (default: 20).

[b]Exclusions:[/b]

- excludeSunsDusk — Automatically exclude Sun's Dusk survival mod potions from the limit (default: true).
- potions — Potion record IDs that bypass the limit. Supports Lua patterns (e.g. "^sd_.*").
- attributes — Per-attribute spell IDs that bypass the cap while active.
- skills — Per-skill spell IDs that bypass the cap while active (e.g. Scroll of Icarian Flight for Acrobatics).

------------------------------------------------------------

[size=4][b]Stat Cap[/b][/size]

If any attribute exceeds attributeCap or any skill exceeds skillCap, your character collapses (fatigue drops to 0). To recover, wait for the fortify effect to expire or dispel it.

- While collapsed, you can't create potions, enchant, or repair.
- For most vanilla items, waiting 1 hour is enough.
- Keep in mind that you cannot wait while levitating.
- After recovery, your fatigue bar starts at 0.

------------------------------------------------------------

[size=4][b]Potion Limit[/b][/size]

- Each potion drunk starts a 20-second cooldown timer.
- Drinking another potion during cooldown increments the counter and resets the timer.
- At the limit (default: 3), the inventory UI blocks further drinks.
- Waiting or sleeping at least 1 hour clears the cooldown immediately.
- HUD counter in the bottom-right shows: countdown drinks/limit.
- [b]Exception:[/b] Hotkeys bypass the inventory block. Drinking via hotkey past the limit causes overdose collapse.

------------------------------------------------------------

[size=4][b]Training Limit[/b][/size]

You can train 5 times per level (configurable). The counter resets on level up. Once reached, the Training window is suppressed with a message.

------------------------------------------------------------

[size=4][b]Lua Interface[/b][/size]

Other mods can use require('openmw.interfaces').sptLimits:

- isKnockedOut() — returns whether the player is collapsed
- excludePotion(id) / includePotion(id) — manage potion exclusions at runtime
- skipAttribute(name) / unskipAttribute(name) — temporarily bypass an attribute cap
- skipSkill(name) / unskipSkill(name) — temporarily bypass a skill cap

------------------------------------------------------------

[size=4][b]Compatibility[/b][/size]

- Incompatible with mods that override fatigue calculation (uses Str + Wil + Agi + End).
- Should be compatible with Potion Thrower if loaded after this mod.
- Other mods can use the Lua interface to exclude their potions/food items.

------------------------------------------------------------

[size=4][b]Permissions[/b][/size]

Do whatever you want. Just credit me.

------------------------------------------------------------

[size=4][b]Changelog[/b][/size]

[code]2.0alpha
- Complete rewrite to pure OpenMW Lua.
- Configuration moved to config.lua.
- Progressive limits for stats and potions removed.
- Training limit window flicker fixed.
- Counter now works while in real time menu.
- Option to exclude Sun's Dusk potions.
- Option to exclude any potion.
- Option to disable stat limit while spell active.[/code]
