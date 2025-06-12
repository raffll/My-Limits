# Stats & Potions Limit (OpenMW)

This mod introduces attributes, skills, and potion consumption limits for players that like to constrain themselves. This will make a game more challenging, tactical, creative, and fun. Forces you to sometimes use potions with negative effects or create multieffect potions.

OpenMW only, Lua edition.

This is my second approach to creating a cap on attributes, but this time it is not that deadly. I also incorporated potion consumption limits, heavily based on the Alchemical Hustle mod. It can be used as a replacement for the "Toxicity" module.

*You can choose in the settings menu if you want the full limit or only potions.*

------------------------------------------------------------

### Negative effect

Once the player exceeds the limit, fatigue will be set to 0, leaving the player lying on the ground without the ability to do anything. The only way to recover is to wait until your attributes or skills go back to normal.

- While active, you can't drink or create potions, enchant, or repair.
- To recover, you just have to get rid of the fortify effect.
- You can wait until fortify effects run out; for most vanilla items, 1 hour should be enough.
- Keep in mind that when you levitate, you cannot wait.
- After recovery, your fatigue will be set to 0.

In the case of potions, if player exceed the limit, further drinking will be impossible until the 20-second cooldown ends. There is one exception to this. If you're using hotkeys with potions, then after exceeding the limit, your character collapses the same way as in the stats limit. This is because OpenMW Lua can't right now have the ability to prevent the use of hotkeys.

------------------------------------------------------------

### Attribute cap

The attribute cap is set to:
```
100 + (Level * 5) with a maximum set to 300
```
Except for Speed, where the cap is set to:
```
300 + (level * 5) with a maximum set to 500
```
That's reasonable for me; that character on level 1 can drink 1 sujamma, but on level 40 can drink up to 4.

------------------------------------------------------------

### Skill cap

The skill cap is set to:
```
100 + Level with a maximum set to 150
```
Except for Acrobatics, where the cap is set to:
```
1100 + Level with a maximum set to 1150
```
Increasing skills beyond 100 is more or less overpowered at all, but this is why we love this game. I think a 150 cap here will still satisfy some power gamers.

------------------------------------------------------------

### Potion limit

The potion limit depends on Alchemy level:
```
 0 - 19 -> 3 potions
20 - 39 -> 4 potions
40 - 59 -> 5 potions
60 - 79 -> 6 potions
80 - 99 -> 7 potions
100+    -> 8 potions
```
- After every potion drunk, the cooldown timer starts to count up to 20 seconds.
- Every time you drink a potion when the previous cooldown timer is still running, your drink counter increases, and the timer starts from the beginning.
- <s>When you drink one more potion over the limit, you collapse.</s>
- <s>When you drink another one, you are dead.</s>
- Now you just can't drink another one (unless you use a hotkey).

------------------------------------------------------------

### Changelog
```
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
```

------------------------------------------------------------

### Compatibility

This mod is probably incompatible with everything that changes how fatigue is calculated.

------------------------------------------------------------

### Credits
Rosynant for creating Alchemical Hustle, from which I took the idea of how to limit potions.

------------------------------------------------------------

### Permissions
Do whatever you want.