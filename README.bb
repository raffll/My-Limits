[b][center][size=6]Stats, Potions, and Training Limits (OpenMW)[/size][/center][/b]

Introduces configurable limits on attributes, skills, potion consumption, and training sessions. OpenMW only, pure Lua, rewritten from scratch.

------------------------------------------------------------

[size=4][b]Installation[/b][/size]

Requires OpenMW 0.49+. Copy [font=Courier New]Stats & Potions Limit.omwscripts[/font] and the [font=Courier New]scripts/[/font] folder into your data path. Add to [font=Courier New]openmw.cfg[/font]:

[code]
content=Stats & Potions Limit.omwscripts
[/code]

------------------------------------------------------------

[size=4][b]Configuration[/b][/size]

All settings are in [font=Courier New]scripts/sptLimits/config.lua[/font]. Edit the file directly.

[b]Toggles:[/b]
[list]
[*][font=Courier New]potionLimitEnabled[/font] — Enable potion consumption limit (default: true).
[*][font=Courier New]statLimitEnabled[/font] — Enable attribute/skill cap enforcement (default: true).
[*][font=Courier New]trainingLimitEnabled[/font] — Enable training session limit (default: true).
[/list]

[b]Limits:[/b]
[list]
[*][font=Courier New]attributeCap[/font] — Maximum allowed attribute value (default: 300).
[*][font=Courier New]skillCap[/font] — Maximum allowed skill value (default: 150).
[*][font=Courier New]potionLimit[/font] — Potions allowed per cooldown window (default: 3).
[*][font=Courier New]trainingLimit[/font] — Training sessions allowed per level (default: 5).
[*][font=Courier New]potionCooldown[/font] — Cooldown window in seconds (default: 20).
[/list]

[b]Exclusions:[/b]
[list]
[*][font=Courier New]excludeSunsDusk[/font] — Automatically exclude Sun's Dusk survival mod potions from the limit (default: true).
[*][font=Courier New]potions[/font] — Potion record IDs that bypass the limit. Supports Lua patterns (e.g. "^sd_.*").
[*][font=Courier New]attributes[/font] — Per-attribute spell IDs that bypass the cap while active.
[*][font=Courier New]skills[/font] — Per-skill spell IDs that bypass the cap while active (e.g. Scroll of Icarian Flight for Acrobatics).
[/list]

------------------------------------------------------------

[size=4][b]Stat Cap[/b][/size]

If any attribute exceeds [font=Courier New]attributeCap[/font] or any skill exceeds [font=Courier New]skillCap[/font], your character collapses (fatigue drops to 0). To recover, wait for the fortify effect to expire or dispel it.

[list]
[*]While collapsed, you can't create potions, enchant, or repair.
[*]For most vanilla items, waiting 1 hour is enough.
[*]Keep in mind that you cannot wait while levitating.
[*]After recovery, your fatigue bar starts at 0.
[/list]

------------------------------------------------------------

[size=4][b]Potion Limit[/b][/size]

[list]
[*]Each potion drunk starts a 20-second cooldown timer.
[*]Drinking another potion during cooldown increments the counter and resets the timer.
[*]At the limit (default: 3), the inventory UI blocks further drinks.
[*]Waiting or sleeping at least 1 hour clears the cooldown immediately.
[*]HUD counter in the bottom-right shows: countdown drinks/limit.
[*][b]Exception:[/b] Hotkeys bypass the inventory block. Drinking via hotkey past the limit causes overdose collapse.
[/list]

------------------------------------------------------------

[size=4][b]Training Limit[/b][/size]

You can train 5 times per level (configurable). The counter resets on level up. Once reached, the Training window is suppressed with a message.

------------------------------------------------------------

[size=4][b]Lua Interface[/b][/size]

Other mods can use [font=Courier New]require('openmw.interfaces').sptLimits[/font]:

[list]
[*][font=Courier New]isKnockedOut()[/font] — returns whether the player is collapsed
[*][font=Courier New]excludePotion(id)[/font] / [font=Courier New]includePotion(id)[/font] — manage potion exclusions at runtime
[*][font=Courier New]skipAttribute(name)[/font] / [font=Courier New]unskipAttribute(name)[/font] — temporarily bypass an attribute cap
[*][font=Courier New]skipSkill(name)[/font] / [font=Courier New]unskipSkill(name)[/font] — temporarily bypass a skill cap
[/list]

------------------------------------------------------------

[size=4][b]Compatibility[/b][/size]

[list]
[*]Incompatible with mods that override fatigue calculation (uses Str + Wil + Agi + End).
[*]Should be compatible with Potion Thrower if loaded after this mod.
[*]Other mods can use the Lua interface to exclude their potions/food items.
[/list]

------------------------------------------------------------

[size=4][b]Permissions[/b][/size]

Do whatever you want. Just credit me.

------------------------------------------------------------

[size=4][b]Changelog[/b][/size]

[code]
2.0alpha
- Complete rewrite to pure OpenMW Lua.
- Configuration moved to config.lua.
- Progressive limits for stats and potions removed.
- Training limit window flicker fixed.
- Counter now works while in real time menu.
- Option to exclude Sun's Dusk potions.
- Option to exclude any potion.
- Option to disable stat limit while spell active.
[/code]
