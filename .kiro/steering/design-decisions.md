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

## UiModeChanged Closes All Modes Intentionally

When the training limit is reached and the player opens Training mode, the `UiModeChanged` handler removes `'Training'`, `'Dialogue'`, and `'Interface'` modes. This is intentional — the goal is to fully close the NPC interaction, not just the training window. If another mod's Dialogue/Interface mode gets closed as a side effect, that's acceptable.

Do NOT "fix" this by only removing `'Training'`.

## Potion Detection: Known Frame-Perfect Edge Case

The potion drink detection uses frame-over-frame delta of active potion effect count. If a potion effect expires on the exact same frame the player drinks a new potion, the count stays flat and the drink goes undetected.

This only affects hotkey drinks (normal UI drinks are already blocked by the `ItemUsage` handler). Frame-perfect bugs that can only happen via quick keys are not worth fixing.

Do NOT "fix" this.

## Stat Limit Message Fires Every Frame — Not a Bug

The `ui.showMessage` for attribute/skill limit fires every frame while the cap is exceeded and `state.active` is false. This is not a bug because:
- `handleKnockoutRecovery` sets `state.active = true` on the same frame, so the message only fires once.
- OpenMW deduplicates identical messages in the queue anyway.

Do NOT "fix" this by adding a flag or throttle.

## Maintain-Knockout Uses `fatigue.current = 0`, Not `-1`

In `handleKnockoutRecovery`, the "maintain knockout" branch sets `fatigue.current = 0` (not `-1`):

```lua
elseif state.active and anyLimit then
    types.Actor.stats.dynamic.fatigue(self).base = 0
    types.Actor.stats.dynamic.fatigue(self).current = 0
end
```

This is intentional. The initial collapse uses `-1` to trigger the knockdown animation. On subsequent frames, `current = 0` with `base = 0` keeps the fatigue bar empty and the player stays down — the engine does not allow recovery when max fatigue is 0. Setting `-1` every frame is unnecessary and would re-trigger the collapse animation repeatedly.

Do NOT "fix" this by changing `0` to `-1` in the maintain branch.

## Overdose Collapse: `handleDrinkDetected` Sets State Before `handleKnockoutRecovery`

When overdose triggers in `handleDrinkDetected`, it sets `state.active = true` and `fatigue.current = -1`. Later in the same frame, `handleKnockoutRecovery` sees `active == true` and `anyLimit == true`, entering the maintain branch which sets `current = 0`.

This is NOT a bug. OpenMW processes the `-1` assignment within the same frame before rendering, which is enough to trigger the knockdown animation. The subsequent `0` on the same frame does not cancel it — the engine latches the collapse state once triggered by a negative fatigue value.

Do NOT "fix" this by reordering the calls or adding early-return guards.

## Interface Version is Always 1

The `interface` block in player.lua uses `version = 1` unless explicitly told otherwise. Do NOT bump the interface version number.
