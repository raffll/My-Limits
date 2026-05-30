# Implementation Plan

## Overview

Refactor stat limiting from knockout-based to modifier-clamping. Four code tasks plus one verification task. Tasks 1 and 2 are the core changes; tasks 3 and 4 are cleanup that depends on tasks 1-2.

## Task Dependency Graph

```json
{
  "waves": [
    ["Task 1"],
    ["Task 2"],
    ["Task 3", "Task 4"],
    ["Task 5"]
  ]
}
```

## Tasks

- [x] 1. Refactor statChecker.lua — replace boolean checks with clampStats function. Remove `checkAttributes(cap)` and `checkSkills(cap)`. Add `clampStats(attributeCap, skillCap)` that iterates all attributes and skills, reads `.base`, `.damage`, `.modifier`, computes `modified = math.max(0, base - damage + modifier)`, and if `modified > cap` and `modifier > 0` writes `stat.modifier = math.max(0, cap - base + damage)`. Keep all exclusion logic and exported tables unchanged. Update module return table.
- [x] 2. Update player.lua onUpdate — replace stat-limit knockout with clamping call. Remove `limitAttribute`/`limitSkill` variables, remove `ui.showMessage(L("attributeLimit"))` and `ui.showMessage(L("skillLimit"))` calls, add `statChecker.clampStats(settings.get("attributeCap"), settings.get("skillCap"))` when `statLimitEnabled` is true, remove stat-limit params from `handleKnockoutRecovery` call.
- [x] 3. Simplify handleKnockoutRecovery — potion-only. Remove `limitAttribute` and `limitSkill` parameters. Compute `anyLimit` from potion state only: `potionCounter.state.overdoseCollapse` or `(state.potionTrackingMode == "slots" and potionSlots.areAllSlotsFull())`. Keep all potion knockout/recovery logic unchanged.
- [x] 4. Simplify settings.subscribe handler — remove stat-limit knockout recovery branch. Remove the block that calls `restoreFatigue()` and sets `state.knockedOut = false` when `statLimitEnabled` is toggled off (no longer needed since stat limits don't cause knockout). Keep `sendSettingsToGlobal()` call.
- [x] 5. Verify old save compatibility — confirm that loading a save where `knockedOut = true` due to stat limits recovers on first frame. Since `anyLimit` is now potion-only, recovery fires immediately with "recovered" message. No code changes needed.

## Notes

- No new files created. Changes are contained in `statChecker.lua` and `player.lua`.
- The `sptLimits` interface remains at version 1. `isKnockedOut()` now only returns true for potion overdose.
- The `l10n` keys `"attributeLimit"` and `"skillLimit"` become unused but are left in the yaml file (removing them is optional cleanup).
- The global script's `sptLimitsStateUpdate` event still receives `knockedOut` — it now only reflects potion state.
