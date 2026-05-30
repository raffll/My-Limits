# Analysis Findings

Tracks issues found during code analysis to prevent circular re-discovery.

## Confirmed Bug — Fixed or Pending

- **`parseIcons` skips empty icon entries** — `string.gmatch(iconsStr, "[^|]+")` skips empty segments between consecutive `|` delimiters. If a potion has no icon (stored as `""`), the concat produces `"icon1||icon3"` and parsing skips the empty middle, shifting subsequent icons. **FIXED** — replaced with manual split that preserves empty entries; empty icons show as bordered placeholder.

## Dead Code (Confirmed)

- **`training.onSave()`** — exported function, never called. `player.lua` saves training state by reading `training.state` directly instead of calling `training.onSave()`. **REMOVED.**
- **`potionSlots.state.overdoseCollapse`** — never set to `true` anywhere. `assignDrinkToOverflow` does not set it. All reads/writes of this field are no-ops. The overflow knockout is maintained by `isOverflowOccupied()` check in `player.lua`, not by this flag. Save/load of the field is harmless but pointless. **REMOVED** (along with `handleOverflowRecovery`).
- **`potionSlots.writeStorage` unused `knockedOut` parameter** — function accepted a parameter that was never referenced in the body. **REMOVED.**
- **`potionSlots.onUpdate` redundant `activeSpellIdSet` rebuild** — `currentPotionSpellIds` already has `activeSpellId` as keys; rebuilding into a separate table was unnecessary. **REMOVED** (passing `currentPotionSpellIds` directly to `validateSlots`).

## Dead Code (Pending Removal)

- **`training.onUiModeChanged` body** — with the ESP handling service refusal via `sptTrainBlocked` global variable + Choice == 4 filter, the Training window never opens when blocked. The `removeMode("Training")` + `removeMode("Dialogue")` + `ui.showMessage` logic is now a redundant fallback. The `blocked` local variable is only consumed by this dead path. **REMOVED.**

## Naming Issues (Pending Fix)

- **`mwscriptGlobals.spttrainblocked`** in `global.lua` — should be `mwscriptGlobals.sptTrainBlocked` to match the ESP's variable ID and the project's camelCase convention. Works either way due to case-insensitive lookup, but violates naming rules. **FIXED.**

## Design Questions (Not Bugs, Flagged for Awareness)

(none)

## Confirmed By-Design (Do Not Re-Report)

- **`blockTrainingWindow` removes Dialogue mode** — intentional. Can't train = leave the conversation.

## False Positive (Do Not Re-Report)

- **Slot mode `excludeSunsDusk` variable**: Initially reported as missing, but the slot-mode branch at line 806 declares its own `local excludeSunsDusk = settings.get("excludeSunsDusk")`. Both counter and slot branches have their own correctly-scoped declaration. NOT a bug.

## Confirmed Not-Bugs (Do Not Re-Report)

- `state.drinkHour` and `state.timer` initialized in slot mode — required for runtime mode switching; subscribe handler sets them to 0 on switch.
- `clearSlotStorage()` in `onInit` for counter mode — removed (readers handle nil with fallback defaults).
- `onLoad` slot validation timing — acceptable per frame-tolerance rule; slots freed incorrectly would be re-detected next frame.
- Counter mode `drinkOverdose` not saved — it's derived state, recalculated on load.
- Slot countdown drift across save/load — cosmetic only, `validateSlots` is authority.
- Switching `potionTrackingMode` while knocked out from stat limit — one-frame recovery then re-collapse, acceptable per frame-tolerance.
- `potionSlotCount` change discards occupied slots — intentional reset per design.
- Large `onUpdate` and `settings.subscribe` — functional, not a quality bug.
- `training.onLoad` with `data = nil` sets `trainLevel = 0` — self-corrects on first training attempt via `checkTrainingLevelReset()`.
- `global.lua` `settingsCache` initialized from config defaults — player sends settings update on first frame per design.
- `potionSlots.onLoad` overrides `knockedOutRef.value = false` for stat-limit knockouts — one-frame recovery then re-collapse, acceptable per frame-tolerance.
- `drinkIcons` array can grow beyond `maxSlotDisplay` — display is capped at 11, save data grows but is harmless. Self-clears on cooldown reset.
- Old saves with `hudCounterEnabled` in `data.settings` — value ignored on upgrade, new `hudCounterMode` defaults to `"full"`. User preference lost but no crash.
- `drinkIcons` not cleared from storage on `potionTrackingMode` switch — `counter.lua` early-returns when mode is slots, so stale data is invisible. No functional impact.
- `hudCounterMode` name covers both counter and slot mode display — slightly misleading but functional and consistent with existing naming patterns.
- `counter.lua` initial element positions overwritten by `applyPosition` on first frame — elements start hidden, no visual artifact.
- HUD flicker when switching `potionTrackingMode` between counter and slots — two independent MENU scripts read shared storage. Data clearing and mode flag writes all happen in the same synchronous block, so reordering doesn't help. A "switching" intermediate value is redundant because data clearing already causes both HUDs to hide via their empty-state paths. The flicker is a rendering-level pop from element visibility toggling. Unfixable without merging both HUDs into one script. Acceptable per frame-tolerance.
- Slot-mode overdose flow: overflow slot IS assigned by `assignDrinkToSlot` (it's the `slotCount+1` slot). Overdose only triggers on the drink AFTER overflow is filled (when `assignDrinkToSlot` returns false). `areAllSlotsFull()` correctly returns true because overflow was assigned on the previous drink. NOT a bug.
- `potionCounter.state.drinkOverdose` in recovery branch — was redundant (recalculated every frame) but made explicit for clarity. Not a bug either way.
- Duplicated icon-extraction logic between `potionCounter.detectDrinks` and `potionSlots.detectDrinks` — code quality preference, not a bug. Could be shared utility but not required.
- `potionSlots.sendStateEvent` sends `allSlotsFull` in event data but `global.lua` never reads it — dead data in the payload, harmless. Global only needs `allNormalSlotsFull` and `knockedOut` for its blocking logic.
- `handleKnockoutRecovery` recovery branch clears both `potionCounter` and `potionSlots` state unconditionally regardless of active mode — defensive no-op writes, harmless.
- `potionSlots.onLoad` sets `knockedOutRef.value = true` without zeroing fatigue — first `onUpdate` frame enters maintain branch and zeros it. Acceptable per frame-tolerance.
- `settingPotionCooldownDesc` says "Seconds" without specifying game-time — OpenMW convention, players understand settings operate in game-time. Not incorrect.
- `training.onLoad` re-sends `sptLimitsTrainBlock` event even though the engine persists the MWScript global variable in the save — idempotent, ensures consistency if save is from before the ESP existed.
- ESP `sptTrainBlocked` persists in save even if mod is removed — standard behavior for any mod using MWScript globals, not a mod-specific issue.
