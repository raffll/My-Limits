# Design Document

## Overview

This design replaces the hybrid MWScript/Lua architecture with pure OpenMW Lua. The MWScript `raffll_limits` script (running per-frame in the ESP) is replaced by a Lua PLAYER script that has direct access to `openmw.self` for stat queries. Inter-script communication uses OpenMW's event system and global storage instead of MWScript global variables.

## Architecture

### Script Roles

| Script | Context | File | Responsibility |
|--------|---------|------|----------------|
| Limit_Engine | PLAYER | `scripts/raffll_limits/player.lua` | Core logic: stat checks, potion counting, cooldown, knockout/recovery, state persistence |
| Item_Blocker | GLOBAL | `scripts/raffll_limits/global.lua` | Intercepts ItemUsage handlers, queries knockout state from player storage, blocks usage |
| Settings_Manager | GLOBAL | `scripts/raffll_limits/settings.lua` | Registers settings, sends events to player on change |
| Menu Page | MENU | `scripts/raffll_limits/menu.lua` | Registers settings page (unchanged) |
| HUD_Counter | MENU | `scripts/raffll_limits/counter.lua` | Reads player storage section for countdown display |

### Communication Flow

```
Settings_Manager (GLOBAL)
    │
    ├── onSettingChanged event ──► Limit_Engine (PLAYER)
    │
Limit_Engine (PLAYER)
    │
    ├── writes to playerSection('raffll_limits_state')
    │       ├── active (boolean) — knockout state
    │       ├── drinkCount (number)
    │       ├── maxCount (number)
    │       ├── countdown (number)
    │       └── drinkOverdose (boolean) — at overdose threshold
    │
    ├── read by Item_Blocker (GLOBAL) via player storage
    │
    └── read by HUD_Counter (MENU) via player storage
```

### State Storage Schema

**Player section key:** `raffll_limits_state`

```lua
{
    active = false,          -- knockout state flag
    drinkCount = 0,          -- potions consumed in current window
    maxCount = 3,            -- current max allowed potions
    countdown = 0,           -- seconds remaining in cooldown
    timer = 0,               -- seconds elapsed since last drink
    drinkHour = 0,           -- GameHour when last potion was consumed
    drinkOverdose = false,   -- whether at overdose threshold (for blocking)
    oldValueAttribute = 0,   -- last notified attribute cap (for change detection)
    oldValueSkill = 0,       -- last notified skill cap (for change detection)
    oldCount = 0,            -- last notified potion count (for change detection)
    -- Settings (received via events, persisted here for frame logic)
    potionsOnly = false,
    progressivePotions = false,
    progressiveStats = false,
}
```

### Saved State (onSave/onLoad)

Only runtime state that cannot be recomputed is saved:

```lua
{
    active = boolean,
    drinkCount = number,
    timer = number,
    drinkHour = number,
    potionsOnly = boolean,
    progressivePotions = boolean,
    progressiveStats = boolean,
}
```

Caps (`maxCount`, `oldValueAttribute`, etc.) are recomputed on load from player level and settings.

## Detailed Design

### Limit_Engine (player.lua)

#### Initialization

- `onInit`: Set all state to defaults (inactive, zero counts)
- `onLoad`: Restore saved state, recompute caps from current level and settings

#### Per-Frame Logic (onUpdate)

1. **Compute caps** based on current settings and player level
2. **Notify cap changes** via messages (only when cap differs from last notified value)
3. **Check attributes** (if not potionsOnly): iterate 8 attributes, compare to cap
4. **Check skills** (if not potionsOnly): iterate 27 skills, compare to cap; skip Acrobatics if Icarian Flight active
5. **Potion timer**: if drinkCount > 0, accumulate dt; check hour-skip; expire if >= 20s
6. **Determine limit state**: any of (limitAttribute, limitSkill, limitPotion) active
7. **Knockout/Recovery transitions**:
   - Not active + limit → set fatigue 0, set active, close menu
   - Active + limit → keep fatigue 0
   - Active + no limit → restore fatigue, clear active, show recovery message

#### Potion Drink Detection

Instead of detecting the "drink" sound (MWScript approach), the Item_Blocker sends a `potionConsumed` event to the player when a potion passes the usage handler. The Limit_Engine handles this event:

1. Reset timer to 0
2. Increment drinkCount
3. Check overdose/death thresholds:
   - If drinkCount == maxCount + 1 → overdose (set limitPotion, show message)
   - If drinkCount == maxCount + 2 → death (set health to 0, show message)

#### Icarian Flight Detection

Use `types.Actor.activeSpells(self)` to check for the spell effect `sc_icarianflight_en` or check for the Fortify Jump magic effect on the player. The original script checks `GetSpellEffects "sc_icarianflight_en"`.

#### Hour-Skip Detection

Store `drinkHour` when a potion is consumed. Each frame, compare current `core.getGameTime()` converted to hours against `drinkHour`. If delta > 1 hour, force timer expiry.

### Item_Blocker (global.lua)

#### ItemUsage Handlers

Register handlers for Potion, Apparatus, Repair, Miscellaneous types:

1. Skip non-player actors
2. Read player's storage section `raffll_limits_state`
3. If `active == true` → block with appropriate message, return false
4. For potions specifically: if `drinkOverdose == true` → block with "can't drink any more", return false
5. For potions that pass: send `potionConsumed` event to the player actor

#### No onUpdate Needed

The Item_Blocker no longer relays data to storage each frame. The Limit_Engine writes directly to player storage which is readable by menu scripts.

### Settings_Manager (settings.lua)

#### Changes from Current

- Remove all `world.mwscript.getGlobalVariables` calls
- On setting change, send event `{ type = 'raffll_limits_settingChanged', key = key, value = value }` to all players (just player 1 in practice)

### HUD_Counter (counter.lua)

#### Changes from Current

- Read from player storage section instead of global storage section
- Use `storage.playerSection('raffll_limits_state')` to get countdown, drinkCount, maxCount
- Display logic unchanged

### Menu Page (menu.lua)

No changes needed.

### Training Limit (training.lua)

No changes needed — already pure Lua with no MWScript dependency.

## File Changes Summary

| File | Action | Notes |
|------|--------|-------|
| `scripts/raffll_limits/player.lua` | CREATE | New core logic script |
| `scripts/raffll_limits/global.lua` | REWRITE | Remove MWScript refs, add event-based communication |
| `scripts/raffll_limits/settings.lua` | REWRITE | Remove MWScript refs, send events instead |
| `scripts/raffll_limits/counter.lua` | MODIFY | Read from player storage instead of global storage |
| `scripts/raffll_limits/menu.lua` | NO CHANGE | — |
| `scripts/raffll_limits/training.lua` | NO CHANGE | — |
| `Stats & Potions Limit.omwscripts` | MODIFY | Add PLAYER script, remove ESP reference |
| `Stats & Potions Limit.esp` | DELETE | No longer needed |

## Correctness Properties

### Property 1: Progressive Attribute Cap Formula (Req 2.3)

For all player levels L >= 1: attributeCap(L) == min(300, 100 + L * 5)

### Property 2: Progressive Skill Cap Formula (Req 3.3)

For all player levels L >= 1: skillCap(L) == min(150, 100 + L)

### Property 3: Progressive Potion Count Formula (Req 4.2)

For all player levels L >= 1: maxPotions(L) == clamp(floor(L / 10) + 3, 3, 8)

### Property 4: Knockout Invariant (Req 6.2)

While active == true and any limit is exceeded, fatigue == 0 after each frame update.

### Property 5: Timer Accumulation (Req 5.1)

For any sequence of frame deltas [dt1, dt2, ...dtN] with no hour-skip and no potion consumed, timer == sum(dt1..dtN).

### Property 6: State Round-Trip (Req 10.1, 10.2)

For any valid state S: onLoad(onSave(S)) produces a state equivalent to S (all persisted fields match).

### Property 7: Cooldown Expiry Resets State (Req 4.7, 5.3)

When timer >= 20, after the next frame update: drinkCount == 0 and timer == 0 and limitPotion == false.

### Property 8: Drink Count Monotonic Within Window (Req 4.4)

For each potionConsumed event within a single cooldown window, drinkCount strictly increases by 1.

## Testing Strategy

- Properties 1-3 (cap formulas): Pure function tests over random levels
- Property 4 (knockout invariant): Simulate frame updates with random stat configurations
- Property 5 (timer): Simulate frame sequences with random dt values
- Property 6 (round-trip): Generate random state objects, verify save/load cycle
- Properties 7-8 (potion mechanics): Simulate event sequences

Integration testing (manual): Load the mod in OpenMW, verify HUD display, test potion drinking sequences, verify knockout/recovery cycle, test settings changes.

## OpenMW Lua API Reference

API reference: https://openmw.readthedocs.io/en/latest/reference/lua-scripting/api.html

### Key API Calls Used in This Design

#### Stat Access (PLAYER script via `openmw.self`)

```lua
local self = require('openmw.self')
local types = require('openmw.types')

-- Attributes: returns AttributeStat with .modified (current value including modifiers)
types.Actor.stats.attributes.strength(self).modified
types.Actor.stats.attributes.intelligence(self).modified
types.Actor.stats.attributes.willpower(self).modified
types.Actor.stats.attributes.agility(self).modified
types.Actor.stats.attributes.speed(self).modified
types.Actor.stats.attributes.endurance(self).modified
types.Actor.stats.attributes.personality(self).modified
types.Actor.stats.attributes.luck(self).modified

-- Skills: returns SkillStat with .modified (current value)
-- NOTE: skill accessor names are lowercase, no separators
types.NPC.stats.skills.alchemy(self).modified
types.NPC.stats.skills.longblade(self).modified
types.NPC.stats.skills.acrobatics(self).modified
types.NPC.stats.skills.bluntweapon(self).modified
types.NPC.stats.skills.enchant(self).modified
types.NPC.stats.skills.security(self).modified
types.NPC.stats.skills.axe(self).modified
types.NPC.stats.skills.conjuration(self).modified
types.NPC.stats.skills.sneak(self).modified
types.NPC.stats.skills.armorer(self).modified
types.NPC.stats.skills.alteration(self).modified
types.NPC.stats.skills.lightarmor(self).modified
types.NPC.stats.skills.mediumarmor(self).modified
types.NPC.stats.skills.destruction(self).modified
types.NPC.stats.skills.marksman(self).modified
types.NPC.stats.skills.heavyarmor(self).modified
types.NPC.stats.skills.mysticism(self).modified
types.NPC.stats.skills.shortblade(self).modified
types.NPC.stats.skills.spear(self).modified
types.NPC.stats.skills.restoration(self).modified
types.NPC.stats.skills.handtohand(self).modified
types.NPC.stats.skills.block(self).modified
types.NPC.stats.skills.illusion(self).modified
types.NPC.stats.skills.mercantile(self).modified
types.NPC.stats.skills.athletics(self).modified
types.NPC.stats.skills.unarmored(self).modified
types.NPC.stats.skills.speechcraft(self).modified

-- Dynamic stats (health, fatigue, magicka): DynamicStat with .base and .current
types.Actor.stats.dynamic.fatigue(self).current = 0  -- set fatigue to 0
types.Actor.stats.dynamic.health(self).current = 0   -- kill player

-- Level
types.Actor.stats.level(self).current
```

#### Active Spell Detection (Icarian Flight)

```lua
-- Check if a specific spell is active on the actor
local activeSpells = types.Actor.activeSpells(self)
if activeSpells:isSpellActive('sc_icarianflight_en') then
    -- skip acrobatics check
end
```

#### Events (Global → Player communication)

```lua
-- In GLOBAL script (settings.lua): send event to player
local world = require('openmw.world')
local player = world.players[1]
player:sendEvent('raffll_limits_settingChanged', { key = key, value = value })
player:sendEvent('raffll_limits_potionConsumed', {})

-- In PLAYER script (player.lua): receive events
return {
    eventHandlers = {
        raffll_limits_settingChanged = function(data) ... end,
        raffll_limits_potionConsumed = function(data) ... end,
    }
}
```

#### Storage (Player section, readable by MENU scripts)

```lua
-- In PLAYER script: write state
local storage = require('openmw.storage')
storage.playerSection('raffll_limits_state'):set('active', true)
storage.playerSection('raffll_limits_state'):set('drinkCount', 3)

-- In MENU script (counter.lua): read state
local storage = require('openmw.storage')
local state = storage.playerSection('raffll_limits_state')
local countdown = state:get('countdown')
```

#### Game Time (for hour-skip detection)

```lua
local core = require('openmw.core')
-- core.getGameTime() returns game time in seconds
-- To get hours: core.getGameTime() / 3600
-- Or use core.getGameTimeInHours() if available
```

#### UI Messages

```lua
local ui = require('openmw.ui')
ui.showMessage("You have reached your attribute limit!")
```

#### Item Usage Handlers (GLOBAL script)

```lua
local interfaces = require('openmw.interfaces')
local types = require('openmw.types')

interfaces.ItemUsage.addHandlerForType(types.Potion, function(potion, actor)
    -- return false to block usage
    -- return nil to allow (don't consume the handler)
end)
```

#### Engine Handlers

```lua
return {
    engineHandlers = {
        onInit = function() end,           -- new game
        onLoad = function(data) end,       -- load save
        onSave = function() return data end, -- save game
        onUpdate = function(dt) end,       -- every frame (not paused)
        onFrame = function(dt) end,        -- every frame (MENU scripts)
    }
}
```

#### Character Generation Check

```lua
-- In PLAYER script, equivalent to MWScript's "if CharGenState != -1 return"
local types = require('openmw.types')
if not types.Player.isCharGenFinished(self) then return end
```
