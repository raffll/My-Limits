# Naming Conventions

## Internal Identifiers — camelCase

All Lua-internal names use camelCase:

- Local variables: `drinkCount`, `potionEffectCount`, `lastSent`
- Functions: `initState`, `handleDrinkDetected`, `checkAttributes`
- Table fields (internal state): `state.drinkOverdose`, `state.overdoseCollapse`
- Config keys: `potionLimitEnabled`, `attributeCap`, `excludeSunsDusk`

## External Identifiers — snake_case

All identifiers visible to other mods, scripts, or the engine use snake_case:

- Interface name: `"spt_limits"`
- Event names: `"spt_limits_state_update"`, `"spt_limits_show_message"`
- Storage section names: `"spt_limits_state"`
- Storage field keys: `"drink_count"`, `"countdown"`
- Event data field names: `data.knocked_out`, `data.drink_overdose`
- L10n message keys: `"train_limit_reached"`, `"overdose_death"`, `"cant_drink_now"`
- L10n namespace: `"spt_limits"`

## Rule of Thumb

If another mod, script, or file could reference the string by name, it is external and must be snake_case. If it only exists within a single Lua file's scope, it is internal and must be camelCase.
