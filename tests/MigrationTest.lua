LuckyUtils, LuckyDB, WarbandStorage, WarbandStockistDB = nil, nil, nil, nil
LuckyStrings = { New = function(_, strings) return strings end }

dofile("../Luckys_Utils/LuckyUtils.lua")
dofile("../Luckys_Utils/LuckyDB.lua")
dofile("src/Strings.lua")
dofile("src/Defaults.lua")
dofile("src/StockRules.lua")
dofile("src/StandardSets.lua")
dofile("src/Sets.lua")
dofile("src/Migration.lua")

local Migration = WarbandStorage.Migration
local Sets = WarbandStorage.Sets

local passed = 0

local function check(label, actual, expected)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local function serialize(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. serialize(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function setNamed(db, name)
    for _, set in pairs(db.sets) do
        if set.name == name then return set end
    end
end

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- A 1.13 account: Default plus four profiles, characters on each.
local db = {
    defaultProfile = "Default",
    lastEditedProfile = "Raiding",
    profiles = {
        Default = { items = { [1001] = 5 }, lowStockWarning = true },
        Raiding = { items = { [2001] = 20, ["2002"] = "3" }, enableExcessDeposit = false, sortAfterDeposit = true },
        ["Bank Dump"] = { items = { [3001] = 0, [3002] = 0 }, enableExcessDeposit = true, defaultQtyZero = true },
        Empty = { items = {}, enableExcessDeposit = true },
        ["Zero Keeper"] = { items = { [4001] = 0 }, enableExcessDeposit = false },
    },
    assignments = {
        ["Lucky-Area 52"] = "Raiding",
        ["Philthy-Area 52"] = "Default",
        ["Bankalt-Area 52"] = "Bank Dump",
        ["Ignored-Area 52"] = "Raiding",
        ["Ghost-Area 52"] = "Gone",
    },
    _seenCharacters = {
        ["Lucky-Area 52"] = true, ["Philthy-Area 52"] = true, ["Bankalt-Area 52"] = true,
        ["Ignored-Area 52"] = true, ["Ghost-Area 52"] = true, ["Unassigned-Area 52"] = true,
    },
    characterClasses = { ["Newbie-Area 52"] = "MAGE", ["Lucky-Area 52"] = "DRUID" },
    ignoredCharacters = { ["Ignored-Area 52"] = true },
    goldManagement = { brackets = { { minLevel = 1, maxLevel = 79, gold = 500 } }, overrides = {} },
    warboundDeposit = { enabled = true, armor = true, weapons = false, tokens = true },
}
local profilesBefore = serialize(db.profiles)
local assignmentsBefore = serialize(db.assignments)

local ok, version = Migration.Upgrade(db)
check("upgrade succeeds", ok, db)
check("upgrade version", version, 1)
check("schema version stored", db.__schemaVersion, 1)
check("one set per profile, plus the warbound set", count(db.sets), 6)
check("profiles left for a downgrade", serialize(db.profiles), profilesBefore)
check("assignments left for a downgrade", serialize(db.assignments), assignmentsBefore)
check("gold settings untouched", db.goldManagement.brackets[1].gold, 500)
check("defaults fill new keys", type(db.reserves), "table")

local default, raiding = setNamed(db, "Default"), setNamed(db, "Raiding")
local dump, empty, zero = setNamed(db, "Bank Dump"), setNamed(db, "Empty"), setNamed(db, "Zero Keeper")

check("ids follow sorted names", dump.id, 1)
check("ids follow sorted names, last", zero.id, 5)
check("next id", db.nextSetId, 7)

check("default is every character", default.everyCharacter, true)
check("others are not every character", raiding.everyCharacter, false)
check("every set returns extras", default.returnExtras, true)
check("a profile with excess off still returns extras", raiding.returnExtras, true)
check("low stock warning carried", default.lowStockWarning, true)
check("low stock warning off", raiding.lowStockWarning, false)
check("items carried", default.items[1001], 5)
check("string items become numbers", raiding.items[2002], 3)
check("keep type", raiding.type, "keep")
check("all-zero deposit-only profile becomes Deposit All", dump.type, "deposit")
check("empty profile with excess on stays Keep", empty.type, "keep")
check("all-zero profile becomes Deposit All whatever excess said", zero.type, "deposit")
check("Default Qty to 0 is dropped", dump.defaultQtyZero, nil)
check("sort after deposit goes account-wide", db.sortAfterDeposit, true)
check("last edited profile carries over", db.lastEditedSet, raiding.id)

local warbound = setNamed(db, "Warbound Items")
check("warbound toggles become a set", warbound.standard, "warbound")
check("warbound set deposits", warbound.type, "deposit")
check("warbound set is every character", warbound.everyCharacter, true)
check("warbound categories carried", serialize({ warbound.armor, warbound.weapons, warbound.tokens }),
    serialize({ true, false, true }))
check("the catch-all category is not switched on behind you", warbound.other, nil)
check("warbound flags left for a downgrade", db.warboundDeposit.enabled, true)
Migration.WarboundToSet(db)
check("warbound imports once", count(db.sets), 6)

check("assigned character ticks its set", db.characters["Lucky-Area 52"].sets[raiding.id], true)
check("assigned character skips Default", default.skip["Lucky-Area 52"], true)
check("Default character ticks nothing", next(db.characters["Philthy-Area 52"].sets), nil)
check("Default character keeps Default", default.skip["Philthy-Area 52"], nil)
check("Unassigned character skips Default", default.skip["Unassigned-Area 52"], true)
check("unseen character gets Default", default.skip["Newbie-Area 52"], nil)
check("missing profile ticks nothing", next(db.characters["Ghost-Area 52"].sets), nil)
check("missing profile skips Default", default.skip["Ghost-Area 52"], true)
check("ignored character keeps its set", db.characters["Ignored-Area 52"].sets[raiding.id], true)
check("ignored character stays ignored", db.ignoredCharacters["Ignored-Area 52"], true)
check("every known character listed", count(db.characters), 7)

WarbandStockistDB = db
check("Default active on its character", Sets:IsActiveFor(default, "Philthy-Area 52"), true)
check("Default active on an unseen character", Sets:IsActiveFor(default, "Newbie-Area 52"), true)
check("Default off for Unassigned", Sets:IsActiveFor(default, "Unassigned-Area 52"), false)
check("ignored character runs nothing", #Sets:ActiveSetsFor("Ignored-Area 52"), 0)
check("assigned character runs its set and the warbound one", #Sets:ActiveSetsFor("Lucky-Area 52"), 2)
check("ranges keep 1.13 amounts", Sets:RangesFor("Lucky-Area 52")[2001].min, 20)
check("the warbound set stays out of the ranges", count(Sets:RangesFor("Lucky-Area 52")), 2)
check("warbound categories reach the bank pass", serialize(Sets:WarboundOptions("Lucky-Area 52")),
    serialize({ armor = true, weapons = false, tokens = true, other = false, minGearQuality = 0 }))
check("an ignored character runs no warbound pass", Sets:WarboundOptions("Ignored-Area 52"), nil)

local afterFirst = serialize(db)
Migration.Upgrade(db)
check("running twice changes nothing", serialize(db), afterFirst)

-- A fresh install.
local fresh = {}
Migration.Upgrade(fresh)
check("fresh install gets one set", count(fresh.sets), 1)
check("fresh set is Default", fresh.sets[1].name, "Default")
check("fresh Default is every character", fresh.sets[1].everyCharacter, true)
check("fresh Default keeps", fresh.sets[1].type, "keep")
check("fresh Default is empty", next(fresh.sets[1].items), nil)
check("fresh install has no characters", next(fresh.characters), nil)

-- Imports from before profiles, at login.
local legacyGlobal = { default = { ["5001"] = 4 } }
local legacyChar = { useDefault = false, override = { [6001] = 2 }, enableExcessDeposit = false }
Migration.Login(fresh, "Oldie-Area 52", legacyGlobal, legacyChar)
local global, own = setNamed(fresh, "Global (Migrated)"), setNamed(fresh, "Oldie-Area 52 (Migrated)")
check("login lists the character", type(fresh.characters["Oldie-Area 52"]), "table")
check("global list imported", global.items[5001], 4)
check("global list goes to nobody", next(global.skip) == nil and not global.everyCharacter, true)
check("global list returns extras", global.returnExtras, true)
check("character list imported", own.items[6001], 2)
check("character list returns extras", own.returnExtras, true)
check("character list ticked", fresh.characters["Oldie-Area 52"].sets[own.id], true)
Migration.Login(fresh, "Oldie-Area 52", legacyGlobal, legacyChar)
check("imports run once", count(fresh.sets), 3)
Migration.Login(fresh, "Newer-Area 52", legacyGlobal, { useDefault = true, override = { [7001] = 1 } })
check("a character using the global list imports nothing", count(fresh.sets), 3)

-- Lucky's Grab-bag writes these after the first login, so the import keeps looking.
fresh.warboundDeposit = { enabled = true, weapons = true }
Migration.Login(fresh, "Oldie-Area 52", legacyGlobal, legacyChar)
local handover = setNamed(fresh, "Warbound Items")
check("a later hand-over still imports", handover.weapons, true)
check("and only what it asked for", handover.armor, false)

print(string.format("%d Migration tests passed", passed))
