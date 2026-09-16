# TODO

Feature requests from the mod page, pending implementation.

## HUD position: 4 corners

Currently `hudPosition` supports only `bottom` and `top` (both right-aligned).

- Add left-side placement so there are 4 positions: top-right, bottom-right, top-left, bottom-left.
- Extend the `hudPosition` setting options and the `applyPosition` logic in `counterHud.lua` (and `slotsHud.lua`) to anchor left as well as right.
- Left anchor mirrors the horizontal offset (positive X from the left edge instead of negative X from the right).

## Counter-only HUD mode (no icons)

Requested "old interface": just the timer and the consumed fraction, no potion icon stack.

- Current `hudCounterMode` values: `full` (text + icons), `minimal` (icons only, no text), `hidden`.
- Add a mode that shows the timer + `count/limit` fraction text with the icon stack suppressed.
- Reconcile naming with existing modes so the intent is clear (text-only vs icon-only vs both).

## Training point banking / carryover

Requested: unused training points carry over to later levels. Toggleable option, off by default (preserves current behavior when disabled).

- Current behavior: `trainCount` resets to 0 on every level-up (`checkTrainingLevelReset` in `training.lua`), and the per-level cap is `trainingLimit`.
- Desired: if fewer than `trainingLimit` points are spent in a level, the remainder rolls over. Example: limit 5, spend 3 at one level, next level allows 7.
- Add a `trainingBankingEnabled` boolean setting (default `false`) in `config.lua` and `settings.lua`, in the `sptLimitsTraining` group.
- Implementation notes:
  - When enabled, on level-up credit the unused amount (`trainingLimit - trainCount`, floored at 0) into a banked pool instead of resetting `trainCount` to 0.
  - When disabled, keep the current reset-to-0 behavior and ignore any banked pool.
  - Effective allowance for a level = `trainingLimit + banked` (banked treated as 0 when disabled).
  - Persist the banked pool via `onSave`/`onLoad` alongside `trainCount`/`trainLevel`.
  - Update the block/unblock checks to compare against the effective allowance.
  - Handle the toggle at runtime via the settings subscribe handler (toggling off should stop applying the bank).
