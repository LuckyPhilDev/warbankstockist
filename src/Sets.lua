WarbandStorage = WarbandStorage or {}
WarbandStorage.Sets = {}

local Sets = WarbandStorage.Sets
local StockRules = WarbandStorage.StockRules

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
        returnExtras = true,
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

function Sets:ClearItems(id)
    DB().sets[id].items = {}
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

-- Whether the character has the set ticked, ignored or not. The Characters
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

-- Turning Every Character off ticks the set for everyone who has it now, so
-- nobody loses it until they untick it.
function Sets:SetEveryCharacter(id, on)
    local db = DB()
    local set = db.sets[id]
    for _, charKey in ipairs(self:AllCharacterKeys()) do
        Sets.EnsureCharacter(db, charKey).sets[id] = (not on and self:IsMember(set, charKey)) or nil
    end
    set.everyCharacter = on
    set.skip = {}
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
    return StockRules.Merge(self:ActiveSetsFor(charKey))
end

-- Ignored characters last, then alphabetical.
function Sets:AllCharacterKeys()
    local keys = {}
    for charKey in pairs(DB().characters) do keys[#keys + 1] = charKey end
    table.sort(keys, function(a, b)
        local ia, ib = self:IsIgnored(a), self:IsIgnored(b)
        if ia ~= ib then return ib end
        return a < b
    end)
    return keys
end
