# Stats & Potions Limit — Design Decisions

## Potion Limit: Two-Layer Defense (ItemUsage block + hotkey overdose)

The `drinkOverdose` flag is set at `drinkCount >= maxCount` (e.g. 3 drinks with limit 3). This intentionally blocks further potions via the `ItemUsage` handler in the global script one drink *before* the actual overdose collapse.

The overdose collapse triggers at `maxCount + 1` (4th drink), which can only happen via hotkey (bypassing `ItemUsage`). Death triggers at `maxCount + 2` (5th drink via hotkey).

This is by design:
- Normal UI usage is blocked at the limit (soft cap via ItemUsage).
- Hotkey bypass is punished with overdose/collapse (hard cap via active spell detection).
- A second hotkey bypass while collapsed causes death.

Do NOT "fix" this as an off-by-one error.

## Per-Frame Logic is Intentional

The `onUpdate` handler in `player.lua` runs every frame by design. This is acceptable because:
- Stat checks must be immediate to prevent even a single frame of exceeding the cap.
- Potion detection via active spell counting needs frame-level granularity to catch hotkey drinks.
- Storage writes to `playerSection` feed the HUD counter which needs smooth updates.

Do NOT throttle or debounce the main `onUpdate` logic. The per-frame cost is acceptable for this mod's requirements.


## Fatigue Restoration Uses `.modified` Attributes

In `handleKnockoutRecovery`, fatigue base is restored using `.modified` (not `.base`):

```lua
local baseMax = attrs.strength(self).modified
              + attrs.willpower(self).modified
              + attrs.agility(self).modified
              + attrs.endurance(self).modified
```

This is intentional. The restored fatigue pool should reflect the player's current effective stats, including active Fortify effects. If a buff expires later, the engine naturally recalculates fatigue base on its own.

Do NOT "fix" this by switching to `.base`.
