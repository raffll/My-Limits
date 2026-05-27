# OpenMW Lua Modding — Lessons Learned

This document captures hard-won knowledge from developing OpenMW Lua mods, specifically pitfalls when porting from MWScript to pure Lua.

## Module Availability by Script Context

| Module | GLOBAL | PLAYER | MENU |
|--------|--------|--------|------|
| `openmw.ui` | NO | YES | YES |
| `openmw.ambient` | NO | YES | YES |
| `openmw.self` | NO | YES | NO |
| `openmw.world` | YES | NO | NO |
| `openmw.storage` (globalSection read) | YES | YES | YES |
| `openmw.storage` (globalSection write) | YES | NO | NO |
| `openmw.storage` (playerSection read) | NO | YES | YES |
| `openmw.storage` (playerSection write) | NO | YES | NO |
| `openmw.interfaces` | YES | YES | YES |
| `openmw.core` | YES | YES | YES |
| `openmw.types` | YES | YES | YES |

Key rules:
- GLOBAL scripts CANNOT use `openmw.ui` — send events to the player script to show messages.
- GLOBAL scripts CANNOT read `storage.playerSection()` — it returns nil.
- PLAYER scripts CANNOT write to `storage.globalSection()` — it is read-only from non-global contexts.
- MENU scripts CAN read `storage.playerSection()` (useful for HUD elements reading player state).

## Inter-Script Communication Patterns

## Interface UI — Mode Management

`interfaces.UI.setMode(mode, options)` — drops all active modes and sets a new one.
- `mode` is **optional**. Calling `I.UI.setMode()` with no arguments drops all modes (closes all windows).
- `I.UI.addMode(mode, options)` — adds a mode to the stack without dropping others.
- `I.UI.removeMode(mode)` — removes a specific mode from the stack.

```lua
interfaces.UI.setMode()              -- close all windows
interfaces.UI.setMode('Interface')   -- close all, open interface
interfaces.UI.addMode('Journal')     -- open journal without closing others
interfaces.UI.removeMode('Training') -- close training window specifically
```

### Inter-Script Communication Patterns

### PLAYER → GLOBAL
Use `core.sendGlobalEvent('eventName', data)` from the player script.

### GLOBAL → PLAYER
Use `player:sendEvent('eventName', data)` where `player` is the actor object passed to handlers.

### PLAYER → MENU (HUD)
Write to `storage.playerSection('section_key')` from the player script. The menu script reads the same section.

### GLOBAL reading player state
The global script cannot read player storage. Instead, have the player script send state updates via `core.sendGlobalEvent()` each frame, and cache the state locally in the global script.

## Fatigue and Knockout

- Setting `fatigue.current = 0` does NOT cause the player to collapse. It just empties the bar.
- Setting `fatigue.current = -1` (negative) DOES trigger the knockout/collapse animation.
- To keep the player knocked down, set `fatigue.current = -1` every frame.
- For recovery, restore `fatigue.base` to the correct value (Str + Wil + Agi + End), then set `fatigue.current = 0`.

## SkillProgression Interface

### Blocking Skill Level Ups

`addSkillLevelUpHandler(function(skillid, source, options))` supports returning `false` to cancel the level up. When a handler returns `false`, all subsequent handlers (including the default one) are skipped.

```lua
interfaces.SkillProgression.addSkillLevelUpHandler(function(skillid, source, options)
    if someCondition then
        return false -- cancels the skill level up entirely
    end
    -- return nil (or nothing) to allow it to proceed
end)
```

The `options` table can also be mutated to change behavior (e.g. `options.skillIncreaseValue`).

Available `SKILL_INCREASE_SOURCES`: `Usage`, `Trainer`, `Book`, `Jail`.

## ItemUsage Handler Limitations

From the official docs: `interfaces.ItemUsage.addHandlerForType`:
- CAN intercept normal inventory UI usage
- CANNOT intercept quick key (hotkey) usage
- CANNOT intercept AI actions (NPCs drinking potions in combat)
- CANNOT intercept MWScript-triggered actions

To detect hotkey potion drinks, use an alternative detection method (see below).

## Detecting Potion Consumption (Including Hotkeys)

Since `ItemUsage` handlers don't fire for hotkey drinks, use `types.Actor.activeSpells(self)` to detect new potion effects by tracking `activeSpellId` keys frame-over-frame:

```lua
-- Build a set of current potion activeSpellIds
local currentIds = {}
for _, spell in pairs(types.Actor.activeSpells(self)) do
    local ok, rec = pcall(types.Potion.record, spell.id)
    if ok and rec then
        currentIds[spell.activeSpellId] = true
    end
end
-- Any ID in currentIds that wasn't in the previous frame's set = new drink
-- Any ID in previous set that isn't in currentIds = expired effect (prune it)
```

This is more reliable than counting total active potions, because it detects each individual drink even if another potion expires on the same frame. The only remaining edge case is if a potion expires AND a new one is added with the same `activeSpellId` on the same frame (effectively impossible).

This works for both normal UI and hotkey drinks, and does NOT trigger on dropping/selling potions.

Note: `ambient.isSoundPlaying("drink")` does NOT work for detecting potion drinks — the drink sound is a 3D sound on the actor, not a 2D ambient sound.

## OpenMW Lua API Quick Reference

### Stat Access (PLAYER script)
```lua
types.Actor.stats.attributes.strength(self).modified  -- current value with modifiers
types.Actor.stats.dynamic.fatigue(self).current       -- get/set current fatigue
types.Actor.stats.dynamic.fatigue(self).base          -- get/set base fatigue
types.Actor.stats.dynamic.health(self).current        -- get/set health
types.Actor.stats.level(self).current                 -- player level
types.NPC.stats.skills.alchemy(self).modified         -- skill value
```

### Active Spell Detection
```lua
local activeSpells = types.Actor.activeSpells(self)
activeSpells:isSpellActive('spell_id')  -- check specific spell
-- Iterate all active spells:
for _, spell in pairs(activeSpells) do
    -- spell.id, spell.name, spell.effects
end
```

### Character Generation Check
```lua
if not types.Player.isCharGenFinished(self) then return end
```

### Game Time
```lua
local gameTimeSeconds = core.getGameTime()
local gameHours = core.getGameTime() / 3600
```

`core.getGameTime()` returns total elapsed game-seconds since the start of the game — it is a monotonically increasing counter, NOT a 24-hour clock. Dividing by 3600 gives total elapsed game-hours, not time-of-day. It never wraps around at midnight. Differences between two `getGameTime()` values are always non-negative.

### UI Messages (PLAYER/MENU only)
```lua
ui.showMessage("Text here")
```

### Events
```lua
-- Send from PLAYER to GLOBAL:
core.sendGlobalEvent('eventName', { key = value })

-- Send from GLOBAL to PLAYER:
player:sendEvent('eventName', { key = value })

-- Receive in script:
return {
    eventHandlers = {
        eventName = function(data) ... end,
    }
}
```

### Storage
```lua
-- Write (only in appropriate context):
storage.playerSection('key'):set('field', value)
storage.globalSection('key'):set('field', value)

-- Read:
storage.playerSection('key'):get('field')
storage.globalSection('key'):get('field')
```

## omwscripts Registration

```
PLAYER: scripts/path/to/player_script.lua
GLOBAL: scripts/path/to/global_script.lua
MENU: scripts/path/to/menu_script.lua
```

- PLAYER scripts have access to `openmw.self`, run per-actor
- GLOBAL scripts have access to `openmw.world`, run once
- MENU scripts have access to UI creation, run in menu context
