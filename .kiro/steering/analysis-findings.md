# Analysis Findings

Tracks issues found during code analysis to prevent circular re-discovery.

## Confirmed Bug — Fixed or Pending

(none)

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
