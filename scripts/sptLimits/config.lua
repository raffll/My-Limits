return {
    -- Toggles (set to false to disable a limit entirely)
    potionLimitEnabled = true,
    statLimitEnabled = true,
    trainingLimitEnabled = true,

    -- Limits
    attributeCap = 300,
    skillCap = 150,
    potionLimit = 3,
    trainingLimit = 5,
    potionCooldown = 20, -- seconds

    -- Exclude Sun's Dusk survival mod potions from the limit.
    excludeSunsDusk = true,

    -- Potion record IDs that will not count towards the drink limit.
    -- Supports Lua patterns: "^sd_.*" matches any ID starting with "sd_".
    -- Plain IDs (no pattern characters) are matched exactly.
    potions = {},

    -- Spell/effect IDs that bypass the attribute limit check.
    -- While any of these are active, the corresponding attribute will not be checked.
    attributes = {
        strength = {},
        intelligence = {},
        willpower = {},
        agility = {},
        speed = {},
        endurance = {},
        personality = {},
        luck = {},
    },

    -- Spell/effect IDs that bypass the skill limit check.
    -- While any of these are active, the corresponding skill will not be checked.
    skills = {
        alchemy = {},
        longblade = {},
        acrobatics = {
            "sc_icarianflight_en",
        },
        bluntweapon = {},
        enchant = {},
        security = {},
        axe = {},
        conjuration = {},
        sneak = {},
        armorer = {},
        alteration = {},
        lightarmor = {},
        mediumarmor = {},
        destruction = {},
        marksman = {},
        heavyarmor = {},
        mysticism = {},
        shortblade = {},
        spear = {},
        restoration = {},
        handtohand = {},
        block = {},
        illusion = {},
        mercantile = {},
        athletics = {},
        unarmored = {},
        speechcraft = {},
    },
}
