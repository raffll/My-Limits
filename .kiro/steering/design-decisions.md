# Stats & Potions Limit — Design Decisions

## Potion Limit: Two-Layer Defense (ItemUsage block + hotkey overdose)

The `drinkOverdose` flag is set at `drinkCount >= maxCount` (e.g. 3 drinks with limit 3). This intentionally blocks further potions via the `ItemUsage` handler in the global script one drink *before* the actual overdose collapse.

The overdose collapse triggers at `maxCount + 1` (4th drink), which can only happen via hotkey (bypassing `ItemUsage`).

This is by design:
- Normal UI usage is blocked at the limit (soft cap via ItemUsage).
- Hotkey bypass is punished with overdose/collapse (hard cap via active spell detection).

Do NOT "fix" this as an off-by-one error.

## Engine Blocks Hotkeys While Collapsed

The engine prevents hotkey usage while the player is in the knocked-out state. This means there is no "double hotkey bypass" scenario — once overdose collapse triggers, the player cannot drink again via hotkey until they recover. There is no death-from-overdose mechanic.

Do NOT add death logic for a second hotkey bypass. It cannot happen.

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

## UiModeChanged Triggers Training Block Check

The `UiModeChanged` event handler in `player.lua` calls `checkTrainingLevelReset()` and re-applies `blockTrainingWindow()` if the training limit is reached and the new mode is `"Training"`. This is a fallback — the primary blocking happens in the `SkillLevelUpHandler` when the count reaches the limit. The `UiModeChanged` handler catches edge cases where the window opens without going through the skill handler first.

## Potion Detection: Known Frame-Perfect Edge Case

The potion drink detection tracks `activeSpellId` keys frame-over-frame. A new ID appearing in the current frame's set that wasn't in the previous frame's set counts as a new drink. If a potion effect expires on the exact same frame the player drinks a new potion, the expired ID is pruned and the new ID is detected — this works correctly in almost all cases. The only theoretical miss is if a new potion reuses the exact same `activeSpellId` as one that expired on the same frame (effectively impossible in practice).

This only affects hotkey drinks (normal UI drinks are already blocked by the `ItemUsage` handler).

Do NOT "fix" this.

## Stat Limit Message Fires Every Frame — Not a Bug

The `ui.showMessage` for attribute/skill limit fires every frame while the cap is exceeded and `state.knockedOut` is false. This is not a bug because:
- `handleKnockoutRecovery` sets `state.knockedOut = true` on the same frame, so the message only fires once.
- OpenMW deduplicates identical messages in the queue anyway.

Do NOT "fix" this by adding a flag or throttle.

## Maintain-Knockout Uses `fatigue.current = 0`, Not `-1`

In `handleKnockoutRecovery`, the "maintain knockout" branch sets `fatigue.current = 0` (not `-1`):

```lua
elseif state.knockedOut and anyLimit then
    types.Actor.stats.dynamic.fatigue(self).base = 0
    types.Actor.stats.dynamic.fatigue(self).current = 0
end
```

This is intentional. The initial collapse uses `-1` to trigger the knockdown animation. On subsequent frames, `current = 0` with `base = 0` keeps the fatigue bar empty and the player stays down — the engine does not allow recovery when max fatigue is 0. Setting `-1` every frame is unnecessary and would re-trigger the collapse animation repeatedly.

Do NOT "fix" this by changing `0` to `-1` in the maintain branch.

## Overdose Collapse: `handleDrinkDetected` Sets State Before `handleKnockoutRecovery`

When overdose triggers in `handleDrinkDetected`, it sets `state.knockedOut = true` and `fatigue.current = -1`. Later in the same frame, `handleKnockoutRecovery` sees `knockedOut == true` and `anyLimit == true`, entering the maintain branch which sets `current = 0`.

This is NOT a bug. OpenMW processes the `-1` assignment within the same frame before rendering, which is enough to trigger the knockdown animation. The subsequent `0` on the same frame does not cancel it — the engine latches the collapse state once triggered by a negative fatigue value.

Do NOT "fix" this by reordering the calls or adding early-return guards.

## Interface Version is Always 1

The `interface` block in player.lua uses `version = 1` unless explicitly told otherwise. Do NOT bump the interface version number.


## Config Cannot Be Changed Mid-Session

The `config.lua` values (toggles, limits, caps, exclusions) are read once at script load and are never hot-reloaded during gameplay. There is no scenario where `potionLimitEnabled`, `statLimitEnabled`, `trainingLimitEnabled`, or any other config value changes while the game is running.

Do NOT add guards, fallback resets, or cleanup logic for "what if a config toggle changes mid-session" — it cannot happen.

## Training Window Uses registerWindow + removeMode

When the training limit is reached, `blockTrainingWindow()` calls `interfaces.UI.registerWindow("Training", showFn, hideFn)` where `showFn` immediately calls `removeMode("Training")` and shows the limit message. This suppresses the built-in Training window content and removes the mode in one step — no borders, no empty window.

The HUD briefly flickers (shows then hides) on each click because `removeMode` triggers a mode stack change. This is an accepted tradeoff — there is no OpenMW API to prevent it without reintroducing the empty bordered window or the original Training window flash.

`unblockTrainingWindow()` calls `registerWindow("Training", nil, nil)` to restore the default Training window on level up.

Do NOT revert this to the old `UiModeChanged`-only approach. Do NOT remove the `removeMode("Training")` from `showFn`. Do NOT replace `registerWindow` with a different mechanism.

## Potion Exclusion: Shared Module + Event Sync

Potion exclusion logic lives in `scripts/sptLimits/exclusions.lua` — a shared module required by both `player.lua` and `global.lua`. It processes `config.potions` (exact IDs and wildcard patterns) and `config.excludeSunsDusk` (Sun's Dusk interface check) at load time.

Because GLOBAL and PLAYER scripts run in separate Lua VMs, `require` gives each their own instance of the module. Config-based exclusions are identical on both sides (same `config.lua`). Runtime exclusions added via the `sptLimits` interface (`excludePotion`/`includePotion`) are synced from player to global via `core.sendGlobalEvent("sptLimitsExcludePotion", ...)` and `core.sendGlobalEvent("sptLimitsIncludePotion", ...)`.

The global script's `ItemUsage` handler checks `isPotionExcluded` before blocking — excluded potions always pass through regardless of overdose state.

Do NOT inline the exclusion logic back into individual scripts. Do NOT remove the event sync.

## Global Script Has No Persistent State — By Design

The global script (`global.lua`) does not implement `onSave`/`onLoad`. Its `playerState` cache starts fresh on every load. The player script re-sends `sptLimitsStateUpdate` on the first frame after load (because `lastSent` values start as `nil`), so the global catches up immediately. The one-frame window where the global doesn't know the player's state is not reproducible in practice — `ItemUsage` handlers don't fire before the first `onUpdate` completes.

Do NOT add `onSave`/`onLoad` to the global script to persist `playerState`.

## HUD Element Lifecycle Is Fire-and-Forget

The `counter.lua` MENU script creates its HUD element at module load and never destroys it. Mods cannot be disabled mid-session in OpenMW — the engine does not support hot-unloading scripts. There is no scenario where cleanup is needed.

Do NOT add destroy/cleanup logic for the HUD element.

## Sun's Dusk Interface Availability Is Not a Load-Order Race

OpenMW resolves all script interfaces before gameplay begins. The `interfaces.SunsDusk` reference in `isPotionExcluded` is always available by the time any `ItemUsage` handler or `onUpdate` fires. There is no race condition between mod load order and interface availability.

Do NOT add deferred checks, retries, or "interface not yet available" guards for `interfaces.SunsDusk`.


## Config-Only Toggles Are Never Persisted

Values that are purely controlled by `config.lua` toggles (e.g. `hudCounterEnabled`, `potionLimitEnabled`) must NOT be saved in `onSave` or written to storage for persistence purposes. They are read once at load from `config.lua` and that is the single source of truth.

Do NOT add save/load logic, storage fields, or interface methods whose sole purpose is to persist a config-driven toggle across sessions.
