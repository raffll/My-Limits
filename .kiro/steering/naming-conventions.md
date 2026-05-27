# Naming Conventions

## camelCase Everywhere

All identifiers use camelCase — internal Lua names, external string keys, folder names, and file references:

- Folder names: `scripts/sptLimits/`, `l10n/sptLimits/`
- Require paths: `require("scripts.sptLimits.config")`, `require("scripts.sptLimits.exclusions")`
- L10n namespace: `core.l10n("sptLimits")`
- Interface name: `"sptLimits"`
- Event names: `"sptLimitsStateUpdate"`, `"sptLimitsShowMessage"`, `"sptLimitsExcludePotion"`, `"sptLimitsIncludePotion"`
- Storage section: `"sptLimitsState"`
- Storage field keys: `"drinkCount"`, `"countdown"`
- Event data fields: `data.knockedOut`, `data.drinkOverdose`
- L10n message keys: `"trainLimitReached"`, `"overdoseDeath"`, `"cantDrinkNow"`
- Local variables: `drinkCount`, `potionEffectCount`, `lastSent`
- Functions: `initState`, `handleDrinkDetected`, `checkAttributes`
- Config keys: `potionLimitEnabled`, `attributeCap`, `excludeSunsDusk`

## No snake_case

Do NOT use snake_case for any identifier in this project. The only underscores allowed are in OpenMW engine record IDs (e.g. `"sc_icarianflight_en"`) which are dictated by the game data.
