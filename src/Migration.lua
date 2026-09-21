WarbandStorage = WarbandStorage or {}
WarbandStorage.Migration = {}

local Migration = WarbandStorage.Migration
local Sets = WarbandStorage.Sets
local S = WarbandStorage.Strings

local function CopyItems(from, to)
    for key, qty in pairs(from) do
        local itemID = tonumber(key)
        if itemID then to[itemID] = tonumber(qty) or 0 end
    end
end

local function AllZero(items)
    for _, qty in pairs(items) do
        if qty ~= 0 then return false end
    end
    return next(items) ~= nil
end

local function KnownCharacters(db)
    local known = {}
    for _, field in ipairs({ "assignments", "characterClasses", "_seenCharacters", "ignoredCharacters" }) do
        for charKey in pairs(db[field] or {}) do known[charKey] = true end
    end
    return known
end

-- Reproduces 1.13's stocking, bar Deposit Excess Items, which every set now
-- does. profiles and assignments stay behind so a downgrade still finds them.
function Migration.ProfilesToSets(db)
    db.sets = db.sets or {}
    db.characters = db.characters or {}
    db.profiles = db.profiles or {}
    local defaultName = db.defaultProfile or "Default"
    db.profiles[defaultName] = db.profiles[defaultName] or { items = {} }

    local names = {}
    for name in pairs(db.profiles) do names[#names + 1] = name end
    table.sort(names)

    local setIDs = {}
    for _, name in ipairs(names) do
        local profile = db.profiles[name]
        local set = Sets.NewSet(db, name)
        CopyItems(profile.items or {}, set.items)
        set.lowStockWarning = profile.lowStockWarning == true
        set.everyCharacter = name == defaultName
        if AllZero(set.items) then set.type = "deposit" end
        if profile.sortAfterDeposit == true then db.sortAfterDeposit = true end
        setIDs[name] = set.id
    end

    -- 1.13 gave Default to any character it had not seen before, so an
    -- unassigned character only opts out once it has been seen.
    local defaultSet = db.sets[setIDs[defaultName]]
    local assignments, seen = db.assignments or {}, db._seenCharacters or {}
    for charKey in pairs(KnownCharacters(db)) do
        local char = Sets.EnsureCharacter(db, charKey)
        local assigned = assignments[charKey]
        if assigned ~= defaultName and setIDs[assigned] then
            char.sets[setIDs[assigned]] = true
        end
        if assigned ~= defaultName and (assigned ~= nil or seen[charKey]) then
            defaultSet.skip[charKey] = true
        end
    end

    db.lastEditedSet = setIDs[db.lastEditedProfile]
    Migration.WarboundToSet(db)
end

-- The Bank page's warbound toggles became a set of their own. The flags stay
-- behind for a downgrade, and because Lucky's Grab-bag writes them when it
-- hands its own warbound deposit over, this keeps looking until there is
-- something to import.
function Migration.WarboundToSet(db)
    local cfg = db.warboundDeposit
    if db.migratedWarbound then return end
    if not (cfg and cfg.enabled and (cfg.armor or cfg.weapons or cfg.tokens)) then return end
    db.migratedWarbound = true

    local set = Sets.NewSet(db, Sets.UniqueName(db, S.standard.warbound))
    set.standard = "warbound"
    set.type = "deposit"
    set.everyCharacter = true
    set.armor = cfg.armor == true
    set.weapons = cfg.weapons == true
    set.tokens = cfg.tokens == true
end

function Migration.Upgrade(db)
    local ok, err = LuckyDB:Initialize(db, {
        version = 1,
        defaults = WarbandStorage.DB_DEFAULTS,
        migrations = { [1] = Migration.ProfilesToSets },
    })
    if not ok then
        print(S.addon.prefix .. " " .. S.migration.failed:format(err))
        -- Only fills what is missing, so the old data stays as it was and the
        -- next login tries again.
        LuckyUtils.ApplyDefaults(db, WarbandStorage.DB_DEFAULTS)
    end
    return ok, err
end

-- Imports from the lists that predate profiles, once per account and once per
-- character.
function Migration.Login(db, charKey, legacyGlobal, legacyChar)
    local char = Sets.EnsureCharacter(db, charKey)
    Migration.WarboundToSet(db)

    if not db.migratedLegacyGlobal and type(legacyGlobal) == "table"
        and type(legacyGlobal.default) == "table" and next(legacyGlobal.default) then
        local set = Sets.NewSet(db, Sets.UniqueName(db, S.sets.migratedGlobal))
        CopyItems(legacyGlobal.default, set.items)
        db.migratedLegacyGlobal = true
    end

    if not db.migratedLegacyChar[charKey] and type(legacyChar) == "table" and legacyChar.useDefault == false
        and type(legacyChar.override) == "table" and next(legacyChar.override) then
        local set = Sets.NewSet(db, Sets.UniqueName(db, S.sets.migratedCharacter:format(charKey)))
        CopyItems(legacyChar.override, set.items)
        char.sets[set.id] = true
        db.migratedLegacyChar[charKey] = true
    end
end
