[b][center][size=6]Stats, Potions, and Training Limits (OpenMW)[/size][/center][/b]

------------------------------------------------------------

This mod introduces attributes, skills, training, and potion consumption limits for players that like to constrain themselves. This will make a game more challenging, tactical, creative, and fun. Forces you to more often create multi-effect potions and plan your training carefully.

OpenMW only, Lua edition.

This is my second approach to creating a cap on attributes, but this time it is not that deadly. I also incorporated potion consumption limits, heavily based on the Alchemical Hustle mod. It can be used as a replacement for the "Toxicity" module.

[b]**Now with a new HUD counter for potion tracking.**[/b]

------------------------------------------------------------

[size=4][b]### Options[/b][/size]

You can choose settings in the Lua scripts menu:

- Potions-Only Limits: If you want full limit (No) or only potions (Yes).
- Progressive Potion Limit: If you want a constant limit of 3 (No) or a limit based on player level (Yes).
- Progressive Stats Limit: If you want a constant 300/150 limit (No) or a progressive limit based on player level (Yes).

------------------------------------------------------------

[size=4][b]### Negative effect[/b][/size]

Once the player exceeds the limit, fatigue will be set to 0, leaving the player lying on the ground without the ability to do anything. The only way to recover is to wait until your attributes or skills go back to normal.

- While active, you can't drink or create potions, enchant, or repair.
- To recover, you just have to get rid of the fortify effect.
- You can wait until fortified effects run out; for most vanilla items, 1 hour should be enough.
- Keep in mind that when you levitate, you cannot wait.
- After recovery, your fatigue will be set to 0.

In the case of potions, if a player exceeds the limit, further drinking will be impossible until the 20-second cooldown ends. There is one exception to this. If you're using hotkeys with potions, then after exceeding the limit, your character collapses the same way as in the stats limit. This is because OpenMW Lua can't right now have the ability to prevent the use of hotkeys. Thankfully, hotkeys stop working when fatigue drops to 0.

------------------------------------------------------------

[size=4][b]### Attribute cap[/b][/size]

The progressive attribute cap is set to:

[code]100 + (Level * 5) with a maximum set to 300[/code]

[b]**The special case for Speed is removed in this version. You can still use "The Best Boots" with max level.**[/b]

------------------------------------------------------------

[size=4][b]### Skill cap[/b][/size]

The progressive skill cap is set to:

[code]100 + Level with a maximum set to 150[/code]

[b]**Except when the effect of "Scroll of Icarian Flight" is active, there is no limit for Acrobatics (but only then).**[/b]

------------------------------------------------------------

[size=4][b]### Potion limit[/b][/size]

The progressive potion limit depends on the player level:

[code]0 - 9   -> 3 potions
10 - 19 -> 4 potions
20 - 29 -> 5 potions
30 - 39 -> 6 potions
40 - 49 -> 7 potions
50+     -> 8 potions[/code]


- After every potion drunk, the cooldown timer starts to count up to 20 seconds.
- Every time you drink a potion when the previous cooldown timer is still running, your drink counter increases, and the timer starts from the beginning.
- If you reach the limit, you just can't drink another one.
- Unless you use a hotkey. Then when you drink one more potion over the limit, you collapse.

------------------------------------------------------------

[size=4][b]### Training limit[/b][/size]

You can train only 5 times per level. That's it. This plugin is independent from Stats & Potions.

------------------------------------------------------------

[size=4][b]### Changelog[/b][/size]

1.0
- Initial version.
1.1
- Strength, Intelligence, and Luck also drop to 0 (to prevent using 800+ fortify spells).
- Negative effect increased from 1000 to 2000.
- Potion timer bugfix.
1.2
- Negative effect increased from 2000 to 100000 (to prevent using strong restore potions).
1.3
- Use Lua to block the alchemy, enchant, and repair windows instead of dropping skills to 0.
1.4
- Potion limit only added.
- Fix for invisibility potion issue, but cooldown indicator is disabled in this version.
1.5
- Cleaning up and rewriting some scripts.
- Now you can't drink potions over the limit.
1.6
- "You have reached the limit of potions!" message removed.
- Both options merged into one esp.
- Settings menu created.
1.7
- Potion limit based on level option added.
- Constant limit for stats option added.
- Training limit module added.
1.8
- "You have recovered from the potion toxic effect!" message removed.
- More natural training limit message.
1.9
- Training limit bugfix.
1.10
- Training limit money and time loss fix.
1.11
- Training limit drops all windows for better compatibility with real-time menu mods.
- Lua interfaces added.
1.12
- Fixed error message when NPCs are drinking potions.
1.13
- Counter added to HUD.
- Speed exception removed.
- Acrobatics exception changed to work only with Scroll of Icarian Flight.
1.14
- Added constant potion limit.
- Removed potion limit by Alchemy.
- Counter bug fixes.

------------------------------------------------------------

[size=4][b]### Compatibility[/b][/size]

- Probably incompatible with everything that changes how fatigue is calculated. It uses a standard formula.
- Currently incompatible with "Potion Thrower".

------------------------------------------------------------

[size=4][b]### Credits[/b][/size]

Thanks to Rosynant for creating "Alchemical Hustle", from which I took the idea of how to limit potions.

------------------------------------------------------------

[size=4][b]### Permissions[/b][/size]

Do whatever you want. Just credit me.