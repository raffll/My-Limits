## Attributes, Skills & Potions Limit (OpenMW)

This mod introduces attributes, skills, and potion consumption limits for players that like to constrain themselves. This will make a game more challenging, tactical, creative, and fun. Forces you to use sometimes potions with negative effects or create multieffect potions.

OpenMW only, because some functions don't work on the original engine.

This is my second approach to creating a cap on attributes, but this time it is not that deadly. I also incorporated potion consumption limits, heavily based on the Alchemical Hustle mod. It can be used as a replacement for the "Toxicity" module.

#### Negative effect

Once the player exceeds the limit, Fatigue, Strength, Intelligence, Luck, Alchemy, Enchant, and Armorer skills will be set to 0, leaving the player lying on the ground without the ability to do anything. The only way to recover is to wait until your attributes or skills go back to normal, or in the case of potions, until the 20-second cooldown ends.

- While active, you can't create potions, enchant or repair.
- To recover, for most attributes and skills, you just have to get rid of the fortify effect.
- You can wait until fortify effects run out; for most vanilla items, 1 hour should be enough.
- Strength, Intelligence, Luck, Alchemy, Enchant, and Armorer are special cases where you have to get rid of all fortify effects or get rid of the corresponding fortify effect and wait at least one hour. When you have a fortify attribute or skill permanent power, only the second option is available.
- Waiting while potion cooldown is running, just recover you from negative effect, because cooldown is always 20 seconds, but you have to wait at least 1 hour.
- Keep in mind that when you levitate, you cannot wait.
- After recovery your fatigue and magicka will be set to 0.

#### Attribute cap

Attribute cap is set to 100 + (Level * 5). With a maximum set to 300, except for Speed, where the cap is set to 300 + (level * 5) (max 500).
That's reasonable for me; that character on level 1 can drink 1 sujamma, but on level 40 can drink up to 4.

#### Skill cap

Skill cap is set to 100 + Level. With a maximum set to 150, except Acrobatics, where the cap is set to 1100 + Level (max 1150).
Increasing skills beyond 100 is more or less overpowered at all, but this is why we love this game. I think 150 cap here will still satisfy some power gamers.

#### Potion limit

Potion limit depends on Alchemy level:

0 - 19 -> 3 potions
20 - 39 -> 4 potions
40 - 59 -> 5 potions
60 - 79 -> 6 potions
80 - 99 -> 7 potions
100+ -> 8 potions 
 
- After every potion drunk, the cooldown timer is starting to count up to 20 seconds.
- Every time you drink a potion when the previous cooldown timer is still running, your drink counter increases, and the timer starts from the beginning.
- When you drink one more potion over the limit, you collapse.
- When you drink another one, you are dead.

There is a small Poison Resist 1% effect after every potion, just to visualize the cooldown timer. I chose Poison Resist because it cannot be resisted or cured and still somehow fits into the entire idea.

#### Compatibility
Probably incompatible with everything that changes how fatigue is calculated.

#### Changelog
1.0
- Initial version
1.1
- Strength, Intelligence and Luck also drop to 0 (to prevent using 800+ fortify spells)
- Negative effect increased from 1000 to 2000
- Potion timer bugfix
1.2
- Negative effect increased from 2000 to 100000 (to prevent using strong restore potions)

#### Credits
Rosynant for creating Alchemical Hustle from where I took the idea of how to limit potions.

#### Permissions
Do whatever you want.