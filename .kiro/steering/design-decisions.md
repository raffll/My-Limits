# Stats & Potions Limit — Design Decisions

## Training Window Block Uses `removeMode` (One-Frame Flash Accepted)

OpenMW's `interfaces.UI.registerWindow` API has no deregister/unregister mechanism:

- `registerWindow("Training", nil, nil)` crashes — the engine calls `showFn()` unconditionally without nil-checking.
- `registerWindow("Training", showFn, hideFn)` permanently disables the built-in Training window via `ui._setWindowDisabled(window, true)`. There is no public API to reverse this.
- `ui._setWindowDisabled` (undocumented, underscore-prefixed internal) can hide/show the Training window widget, but the Training mode also contains a progress bar (`WaitDialogProgressBar`) that has no Lua ID — it cannot be disabled from Lua at all.

Therefore, the only viable approach is:

1. Track a `blocked` flag (set when training limit is reached, cleared on level-up or setting change).
2. In the `UiModeChanged` handler, when `blocked` and `newMode == "Training"`, call `removeMode("Training")` and show the limit message.
3. Accept the one-frame flash of the Training window + progress bar before `removeMode` takes effect.

This is the simplest solution. The one-frame flash is acceptable per frame-tolerance.

Do NOT use `registerWindow` for training blocking. Do NOT use `ui._setWindowDisabled`.

## Potion Limit: Two-Layer Defense (ItemUsage block + hotkey overdose)

The `drinkOverdose` flag is set at `drinkCount >= maxCount` (e.g. 3 drinks with limit 3). This intentionally blocks further potions via the `ItemUsage` handler in the global script one drink *before* the actual overdose collapse.

The overdose collapse triggers at `maxCount + 1` (4th drink), which can only happen via hotkey (bypassing `ItemUsage`).

This is by design:
- Normal UI usage is blocked at the limit (soft cap via ItemUsage).
- Hotkey bypass is punished with overdose/collapse (hard cap via active spell detection).

Do NOT "fix" this as an off-by-one error.

## Engine Blocks Hotkeys While Collapsed

The engine prevents hotkey usage while the player is in the knocked-out state. This means there is no "double hotkey bypass" scenario — once overdose collapse triggers, the player cannot drink again via hotkey until they recover.

The death branch (`potionLimit + 2`) exists as a defensive safeguard in case a future OpenMW version changes hotkey behavior during collapse. It is currently unreachable. Do NOT remove it, but do NOT treat it as active gameplay logic either.

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


## Config Defaults vs Runtime Settings

The `config.lua` file provides **default values only**. At runtime, all toggles and numeric limits are managed by the settings system (`settings.lua`) and can be changed mid-session via the OpenMW settings UI. The `settings.subscribe` mechanism propagates changes to all consumers (player script, global script via events, HUD via storage).

Only the exclusion lists (`potions`, `attributes`, `skills`) in `config.lua` are truly static — they are read once at script load and cannot be changed mid-session (except via the Lua interface for potions).

Do NOT treat `config.lua` toggles/limits as the runtime source of truth. Always use `settings.get(key)` for current values.

## Training Window Block: Superseded by removeMode Approach

The old `registerWindow`-based approach is removed. See the new "Training Window Block Uses `removeMode`" section above for the current design.

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


## Config Values Are Defaults, Not Runtime State

The `config.lua` toggles and limits (e.g. `hudCounterEnabled`, `potionLimitEnabled`, `attributeCap`) serve exclusively as **default values** for the settings system. They are referenced in `settings.lua` definitions as `default = config.X`. The actual runtime values live in `storage.playerSection` and are persisted per-save via `onSave`/`onLoad`.

Do NOT read `config.X` directly at runtime for any value that has a corresponding settings definition. Always use `settings.get(key)`.


## Settings Persistence: onSave/onLoad Is the Source of Truth

OpenMW's `storage.playerSection` with `permanentStorage = false` bleeds values across saves within the same session. To guarantee true per-save settings, all user-configurable values are saved in `onSave` (under `data.settings`) and restored in `onLoad` via `settings.loadAll(data.settings)`.

On load:
- `data.settings` present → restore those values to storage.
- `data` is `nil` (save predates the mod) → reset all settings to `config.lua` defaults.
- `data` exists but `data.settings` is missing → leave storage as-is (pre-2.0beta save, storage already holds values from the save file).

We only care about two scenarios: new saves with this mod installed, and old saves that never had this mod. There is no need to handle migration from intermediate mod versions or partial settings states.

Do NOT remove `data.settings` from `onSave`. Do NOT rely solely on `storage.playerSection` for per-save settings persistence.


## Slot Mode: validateSlots Is the Authority on Slot Lifetime

`tickSlots` only decrements the countdown for display purposes. It does NOT free slots when countdown reaches 0. Only `validateSlots` (which checks whether the `activeSpellId` is still present in the engine's active spells) can free a slot. This prevents slots from opening up before the engine has actually expired the effect.

Do NOT re-add slot-freeing logic to `tickSlots`.


## Slot Mode: handleOverflowRecovery Only Clears overdoseCollapse

When the overflow slot's spell expires (detected by `validateSlots`), `handleOverflowRecovery` sets `state.overdoseCollapse = false`. It does NOT set `state.knockedOut = false` or call `restoreFatigue()`. The actual recovery (or continued knockout if a stat limit is active) is handled by `handleKnockoutRecovery` later in the same frame.

Do NOT add `state.knockedOut = false` or `restoreFatigue()` back into `handleOverflowRecovery`.


## Re-Enabling potionLimitEnabled Resets Potion Tracking

When `potionLimitEnabled` is toggled from off to on, `state.potionSpellIdsInitialized` is set to `false` and `state.knownPotionSpellIds` is cleared. This forces the next `onUpdate` frame to snapshot all currently active potion spells as "already known" rather than treating them as new drinks. Without this, potions drunk while the limit was disabled would trigger overdose the moment the limit is re-enabled.

Do NOT remove this reset from the settings subscribe handler.
