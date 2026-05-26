-- Exclusion lists for Stats & Potions Limit.
-- Add record IDs to exclude them from limit checks.
-- Wildcards are supported: "sd_*" matches any ID starting with "sd_".
--
-- To find a record ID, open the console in-game and click on the item,
-- or check the mod's ESP/ESM in OpenMW-CS.

return {
    -- Potion record IDs that will not count towards the drink limit.
    -- Supports wildcards: "sd_*" matches any ID starting with "sd_".
    -- Example: Sun's Dusk food/drinks, custom healing items, etc.
    potions = {
        -- "sd_*",
    },

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
