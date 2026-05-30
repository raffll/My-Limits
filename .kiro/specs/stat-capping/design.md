# Design Document

## Overview

Replace the stat-limit knockout mechanic with direct modifier clamping. The `statChecker.lua` module is refactored from a boolean "does any stat exceed cap?" checker into an active capper that writes clamped `.modifier` values every frame. The potion overdose knockout remains unchanged.

## Architecture

The stat capping logic lives entirely in the PLAYER script context. No changes to GLOBAL or MENU scripts. The `statChecker.lua` module becomes the single point of stat modification, called once per frame from `player.lua`'s `onUpdate`.

## Components and Interfaces

**statChecker.lua** (modified):
- Removes: `checkAttributes(cap)`, `checkSkills(cap)`
- Adds: `clampStats(attributeCap, skillCap)` — iterates all attributes and skills, writes clamped modifier when needed
- Keeps: `shouldSkipAttribute(name)`, `shouldSkipSkill(name)`, `skippedAttributes`, `skippedSkills`, `attributeNames`, `skillNames`

**player.lua** (modified):
- `onUpdate`: replaces stat-limit boolean checks + knockout trigger with single `statChecker.clampStats(...)` call
- `handleKnockoutRecovery(limitAttribute, limitSkill)` → `handleKnockoutRecovery()` — potion-only
- `settings.subscribe`: removes stat-limit knockout recovery branch
- Interface: unchanged (version 1), `isKnockedOut` now only reflects potion knockout

**Unchanged modules**: `potionCounter.lua`, `potionSlots.lua`, `training.lua`, `global.lua`, `exclusions.lua`, `config.lua`, `settings.lua`, HUD scripts

## Data Models

No new persistent state. Clamping is stateless — computed fresh each frame from current stat values and settings.

Existing save data:
- `state.knockedOut` — still saved/loaded, now only reflects potion knockout
- Old saves with `knockedOut = true` from stat limits recover on first frame (potion-only `anyLimit` is false → recovery fires)

## Capping Formula

For each stat (attribute or skill):

```
modified = max(0, base - damage + modifier)
if modified > cap and modifier > 0 then
    newModifier = max(0, cap - base + damage)
    stat.modifier = newModifier
end
```

Ensures:
- Fortify effects reduced so modified equals the cap
- Drain effects (negative modifier) never touched
- Damage accounted for correctly
- Base values exceeding cap left alone (modifier zeroed)

## Frame Order (Why This Works)

Each frame:
1. Engine recalculates `modifier` from active Fortify/Drain spell effects
2. Lua `onUpdate` fires — our script reads the recalculated modifier and writes the clamped value
3. Engine applies cached Lua stat writes before rendering

The user never sees the unclamped value.

## Data Flow

```
onUpdate
  ├─ if statLimitEnabled:
  │    └─ statChecker.clampStats(attributeCap, skillCap)
  │         ├─ for each attribute: read base/damage/modifier, clamp if needed
  │         └─ for each skill: read base/damage/modifier, clamp if needed
  ├─ if potionLimitEnabled:
  │    └─ (unchanged potion tracking logic)
  └─ handleKnockoutRecovery() (potion-only now)
```

## Correctness Properties

Property 1: Clamping is idempotent — calling `clampStats` multiple times per frame produces the same result. **Validates: Requirements 7.1**

Property 2: Disabling `statLimitEnabled` stops all modifier writes; engine restores natural values next frame. **Validates: Requirements 5.1, 5.2, 5.3**

Property 3: Changing `attributeCap` or `skillCap` takes effect on the next `onUpdate` call. **Validates: Requirements 6.1, 6.2**

Property 4: Excluded stats are never written to, regardless of their value. **Validates: Requirements 3.1, 3.2, 3.3, 3.4**

Property 5: Negative modifiers are never increased (Drain effects always pass through). **Validates: Requirements 7.3**

Property 6: Load order conflicts — if another Lua mod writes `.modifier` after this script, their value wins. Acceptable per frame-tolerance. **Validates: Requirements 1.5, 2.5**

## Error Handling

- `pcall` is not needed for stat access (engine guarantees valid stat objects for the player)
- If `attributeCap` or `skillCap` settings return nil, `settings.get` already falls back to config defaults
- If `base - damage` is negative (heavily damaged stat), `cap - base + damage` may exceed the engine's modifier; `math.max(0, ...)` prevents writing negative modifiers

## Testing Strategy

Manual in-game testing:
- Drink Fortify Attribute potion → verify stat caps at configured value
- Apply Drain effect while Fortified → verify drain reduces modified below cap (no clamping)
- Use console to set base above cap → verify modifier zeroed, no crash
- Toggle `statLimitEnabled` off → verify stats return to natural values
- Change `attributeCap` mid-session → verify immediate effect
- Load old save with stat-knockout → verify immediate recovery
