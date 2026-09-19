WarbandStorage = WarbandStorage or {}

-- Settings added in this version or later are badged NEW and listed on the
-- What's New page. Raise it when the highlights from a release stop being worth
-- pointing at.
WarbandStorage.WHATS_NEW_MIN_VERSION = "2.0.0"

WarbandStorage.DB_DEFAULTS = {
    debugEnabled = false,
    sets = {},
    characters = {},
    reserves = {},
    sortAfterDeposit = false,
    ignoredCharacters = {},
    characterClasses = {},
    migratedLegacyChar = {},
    goldManagement = { brackets = {}, overrides = {} },
    warboundDeposit = { enabled = false, armor = false, weapons = false, tokens = false },
    devOpenOnLogin = false,
    minimap = {},
}
