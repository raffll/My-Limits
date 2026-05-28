# Analysis Findings

Tracks issues found during code analysis to prevent circular re-discovery.

## Confirmed Bug — Fixed or Pending

(none)

## Dead Code (Confirmed)

- **`training.onSave()`** — exported function, never called. `player.lua` saves training state by reading `training.state` directly instead of calling `training.onSave()`. **REMOVED.**
- **`potionSlots.state.overdoseCollapse`** — never set to `true` anywhere. `assignDrinkToOverflow` does not set it. All reads/writes of this field are no-ops. The overflow knockout is maintained by `isOverflowOccupied()` check in `player.lua`, not by this flag. Save/load of the field is harmless but pointless. **REMOVED** (along with `handleOverflowRecovery`).

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
