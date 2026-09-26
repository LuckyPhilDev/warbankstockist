WarbandStorage = WarbandStorage or {}
WarbandStorage.Sets = {}

local Sets = WarbandStorage.Sets
local StockRules = WarbandStorage.StockRules
local Standard = WarbandStorage.StandardSets

local function DB()
    return WarbandStockistDB
end

local function Changed()
    WarbandStorage.Settings.Refresh()
end

-- NewSet, UniqueName and EnsureCharacter take the table they work on, so the
-- migration can build sets in LuckyDB's working copy.
function Sets.NewSet(db, name)
    local id = db.nextSetId or 1
    db.nextSetId = id + 1
    local set = {
        id = id,
        name = name,
        type = "keep",
        returnExtras = true, -- no longer a setting: every set returns extras
        everyCharacter = false,
        skip = {},
        lowStockWarning = false,
        items = {},
    }
    db.sets[id] = set
    return set
end

function Sets.UniqueName(db, base)
    local taken = {}
    for _, set in pairs(db.sets) do taken[set.name] = true end
    local name, n = base, 1
    while taken[name] do
        n = n + 1
        name = base .. " " .. n
    end
    return name
end

function Sets.EnsureCharacter(db, charKey)
    db.characters[charKey] = db.characters[charKey] or { sets = {} }
    return db.characters[charKey]
end

-- The Deposit All set the bank's drop slot adds to. It can be renamed but not
-- deleted; this puts it back if it goes missing all the same.
function Sets.EnsureMaster(db)
    if db.masterSetId and db.sets[db.masterSetId] then return db.sets[db.masterSetId] end
    local set = Sets.NewSet(db, Sets.UniqueName(db, WarbandStorage.Strings.sets.masterName))
    set.type = "deposit"
    set.everyCharacter = true
    db.masterSetId = set.id
    return set
end

function Sets.IsMaster(set)
    return set.id == DB().masterSetId
end

function Sets:All()
    local list = {}
    for _, set in pairs(DB().sets) do list[#list + 1] = set end
    table.sort(list, function(a, b)
        local na, nb = a.name:lower(), b.name:lower()
        if na ~= nb then return na < nb end
        return a.id < b.id
    end)
    return list
end

function Sets:Get(id)
    return id and DB().sets[id]
end

function Sets:Create(name)
    local set = Sets.NewSet(DB(), name)
    Changed()
    return set
end

-- kind is a key of StandardSets.kinds.
function Sets:AddStandard(kind)
    local db = DB()
    local rule = Standard.kinds[kind]
    local set = Sets.NewSet(db, "")
    set.standard = kind
    set.type = rule.type
    set.name = Sets.UniqueName(db, Sets.StandardName(set))
    for option, value in pairs(rule.defaults or {}) do set[option] = value end
    Changed()
    return set
end

function Sets:Rename(id, name)
    DB().sets[id].name = name
    Changed()
end

function Sets:Duplicate(id)
    local db = DB()
    local source = db.sets[id]
    local copy = Sets.NewSet(db, Sets.UniqueName(db, source.name .. " Copy"))
    for key, value in pairs(source) do
        if key ~= "id" and key ~= "name" then
            copy[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
    Changed()
    return copy
end

function Sets:Delete(id)
    local db = DB()
    db.sets[id] = nil
    for _, char in pairs(db.characters) do char.sets[id] = nil end
    Changed()
end

function Sets:SetItem(id, itemID, qty)
    DB().sets[id].items[tonumber(itemID)] = tonumber(qty)
    Changed()
end

function Sets:RemoveItem(id, itemID)
    DB().sets[id].items[tonumber(itemID)] = nil
    Changed()
end

-- Standard sets list their items by rule, so an item is left out rather than removed.
function Sets:SetExcluded(id, itemID, excluded)
    local set = DB().sets[id]
    set.excluded = set.excluded or {}
    set.excluded[tonumber(itemID)] = excluded or nil
    Changed()
end

function Sets:ClearItems(id)
    DB().sets[id].items = {}
    Changed()
end

-- A reagent set can run either way, so its name says which.
function Sets.StandardName(set)
    local S = WarbandStorage.Strings.standard
    if not Standard.kinds[set.standard].reagent then return S[set.standard] end
    return (set.type == "keep" and S.withdrawName or S.depositName):format(S[set.standard])
end

-- A standard set still under its own name, " 2" and all, is renamed to match
-- its direction; one the player has renamed keeps their name. The bare
-- category name is what reagent sets were called before they had a direction.
function Sets:SetType(id, setType)
    local db = DB()
    local set = db.sets[id]
    if set.type == setType then return end
    local base = set.standard and (set.name:gsub(" %d+$", ""))
    local ownName = base == Sets.StandardName(set) or base == WarbandStorage.Strings.standard[set.standard]
    set.type = setType
    if ownName then set.name = Sets.UniqueName(db, Sets.StandardName(set)) end
    Changed()
end

function Sets:SetOption(id, key, value)
    DB().sets[id][key] = value
    Changed()
end

function Sets:IsIgnored(charKey)
    return DB().ignoredCharacters[charKey] == true
end

function Sets:SetIgnored(charKey, ignored)
    DB().ignoredCharacters[charKey] = ignored or nil
    Changed()
end

-- Whether the character has the set ticked, ignored or not. The Assignments
-- page shows this; IsActiveFor is what the bank runs.
function Sets:IsMember(set, charKey)
    local char = DB().characters[charKey]
    if char and char.sets[set.id] then return true end
    return set.everyCharacter == true and not set.skip[charKey]
end

function Sets:IsActiveFor(set, charKey)
    return not self:IsIgnored(charKey) and self:IsMember(set, charKey)
end

function Sets:SetMember(id, charKey, on)
    local set = DB().sets[id]
    local char = Sets.EnsureCharacter(DB(), charKey)
    if set.everyCharacter then
        set.skip[charKey] = not on or nil
        char.sets[id] = nil
    else
        char.sets[id] = on or nil
    end
    Changed()
end

-- Either way the set starts from a clean slate: on reaches everyone, off reaches nobody.
function Sets:SetEveryCharacter(id, on)
    local db = DB()
    for _, char in pairs(db.characters) do char.sets[id] = nil end
    db.sets[id].everyCharacter = on
    db.sets[id].skip = {}
    Changed()
end

function Sets:ActiveSetsFor(charKey)
    local active = {}
    for _, set in ipairs(self:All()) do
        if self:IsActiveFor(set, charKey) then active[#active + 1] = set end
    end
    return active
end

function Sets:CharactersUsing(id)
    local set, using = DB().sets[id], {}
    for _, charKey in ipairs(self:AllCharacterKeys()) do
        if self:IsActiveFor(set, charKey) then using[#using + 1] = charKey end
    end
    return using
end

function Sets:IsPriority(charKey)
    local char = DB().characters[charKey]
    return char ~= nil and char.priority == true
end

function Sets:SetPriority(charKey, on)
    Sets.EnsureCharacter(DB(), charKey).priority = on or nil
    Changed()
end

function Sets:GetReserve(itemID)
    return DB().reserves[itemID]
end

function Sets:SetReserve(itemID, qty)
    DB().reserves[tonumber(itemID)] = tonumber(qty)
    Changed()
end

function Sets:RemoveReserve(itemID)
    DB().reserves[tonumber(itemID)] = nil
    Changed()
end

function Sets:AllReserves()
    return DB().reserves
end

function Sets:RangesFor(charKey)
    local sets = {}
    for _, set in ipairs(self:ActiveSetsFor(charKey)) do
        -- A warbound set deposits by bag slot rather than by item id, so it
        -- runs its own bank pass instead of joining the stock ranges.
        if not Sets.IsWarbound(set) then
            sets[#sets + 1] = set.standard and Standard.Resolve(set) or set
        end
    end
    return StockRules.Merge(sets)
end

function Sets.IsWarbound(set)
    local rule = set.standard and Standard.kinds[set.standard]
    return rule ~= nil and rule.warbound == true
end

-- Only what every warbound set leaves out is kept back, as any one of them
-- would deposit the rest.
-- ponytail: ignores which categories each set asks for, so an armour-only set
-- excluding a piece does not hold it back from a second set taking everything.
local function ExcludedByAll(excluded, set)
    if not excluded then
        excluded = {}
        for itemID in pairs(set.excluded or {}) do excluded[itemID] = true end
        return excluded
    end
    for itemID in pairs(excluded) do
        if not (set.excluded and set.excluded[itemID]) then excluded[itemID] = nil end
    end
    return excluded
end

-- The categories the warbound sets this character runs ask for between them,
-- the loosest gear quality floor among them and the items all of them exclude,
-- or nil when it runs none that ask for anything.
function Sets:WarboundOptions(charKey)
    local cfg = { armor = false, weapons = false, tokens = false, other = false }
    local any, minGearQuality, excluded = false, nil, nil
    for _, set in ipairs(self:ActiveSetsFor(charKey)) do
        if Sets.IsWarbound(set) then
            excluded = ExcludedByAll(excluded, set)
            for option in pairs(cfg) do
                cfg[option] = cfg[option] or set[option] == true
                any = any or cfg[option]
            end
            minGearQuality = math.min(minGearQuality or math.huge, set.minGearQuality or 0)
        end
    end
    if not any then return nil end
    cfg.minGearQuality = minGearQuality
    cfg.excluded = excluded
    return cfg
end

function WarbandStorage:GetAllCharacterKeys()
    return Sets:AllCharacterKeys()
end

-- Ignored characters last, Priority characters first, then alphabetical.
function Sets:AllCharacterKeys()
    local keys = {}
    for charKey in pairs(DB().characters) do keys[#keys + 1] = charKey end
    table.sort(keys, function(a, b)
        local ia, ib = self:IsIgnored(a), self:IsIgnored(b)
        if ia ~= ib then return ib end
        local pa, pb = self:IsPriority(a), self:IsPriority(b)
        if pa ~= pb then return pa end
        return a < b
    end)
    return keys
end

-- Public API for the other Lucky addons. Lucky's Grab-bag loads first, so it
-- calls these at PLAYER_LOGIN or later.

-- Creates a standard set and returns its id, or nil for a kind this version does
-- not have. opts: everyCharacter, skip = { [charKey] = true }, currentExpansionOnly.
function WarbandStorage:ImportStandardSet(kind, opts)
    if not Standard.kinds[kind] then return nil end
    opts = opts or {}
    local set = Sets:AddStandard(kind)
    set.everyCharacter = opts.everyCharacter == true
    for charKey in pairs(opts.skip or {}) do set.skip[charKey] = true end
    set.currentExpansionOnly = opts.currentExpansionOnly == true
    Changed()
    return set.id
end

-- Creates a Deposit All set of itemIDs with a unique name and returns its id.
function WarbandStorage:ImportDepositList(name, itemIDs, everyCharacter)
    local db = DB()
    local set = Sets.NewSet(db, Sets.UniqueName(db, name))
    set.type = "deposit"
    set.everyCharacter = everyCharacter == true
    for _, itemID in ipairs(itemIDs) do set.items[itemID] = 0 end
    Changed()
    return set.id
end
