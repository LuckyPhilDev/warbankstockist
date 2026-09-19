WarbandStorage = WarbandStorage or {}
WarbandStorage.StandardSets = {}

local Standard = WarbandStorage.StandardSets

local TRADEGOODS = 7
local OTHER_SUBCLASS = 11

-- Keys and Tradegoods subclasses match Lucky's Grab-bag's Reagent Mains
-- categories, so its settings carry over category for category.
local REAGENTS = {
    { key = "herb",       subclasses = { 9 } },
    { key = "leather",    subclasses = { 6 } },
    { key = "cloth",      subclasses = { 5 } },
    { key = "metalstone", subclasses = { 7 } },
    { key = "gems",       subclasses = { 4 } },
    { key = "enchanting", subclasses = { 12 } },
    { key = "cooking",    subclasses = { 8 } },
    { key = "elemental",  subclasses = { 10 } },
    { key = "crafting",   subclasses = { 13, 15 } },
    { key = "finishing",  subclasses = { 16, 19 } },
    { key = "other",      subclasses = { 11, 14 } },
}

-- Midnight treatises: the profession's skill line variant, the spell learned
-- with it, the treatise, and the hidden weekly quest that using it completes.
local TREATISES = {
    { variant = 2871, spell = 423321, itemID = 245755, quest = 95127 }, -- Alchemy
    { variant = 2872, spell = 423332, itemID = 245763, quest = 95128 }, -- Blacksmithing
    { variant = 2874, spell = 423334, itemID = 245759, quest = 95129 }, -- Enchanting
    { variant = 2875, spell = 423335, itemID = 245809, quest = 95138 }, -- Engineering
    { variant = 2877, spell = 441327, itemID = 245761, quest = 95130 }, -- Herbalism
    { variant = 2878, spell = 423338, itemID = 245757, quest = 95131 }, -- Inscription
    { variant = 2879, spell = 423339, itemID = 245760, quest = 95133 }, -- Jewelcrafting
    { variant = 2880, spell = 423340, itemID = 245758, quest = 95134 }, -- Leatherworking
    { variant = 2881, spell = 423341, itemID = 245762, quest = 95135 }, -- Mining
    { variant = 2882, spell = 423342, itemID = 245828, quest = 95136 }, -- Skinning
    { variant = 2883, spell = 423343, itemID = 245756, quest = 95137 }, -- Tailoring
}

Standard.kinds = {}
Standard.order = {}

local itemInfo = {}

-- nil while the client has not loaded the item; the next scan tries again.
local function Info(itemID)
    if itemInfo[itemID] then return itemInfo[itemID] end
    local name, _, _, _, _, _, _, _, _, _, _, classID, subclassID, _, expansionID = C_Item.GetItemInfo(itemID)
    if not classID then return nil end
    itemInfo[itemID] = { name = name, classID = classID, subclassID = subclassID, expansionID = expansionID }
    return itemInfo[itemID]
end

local function BagItems(matches)
    local items = {}
    for itemID in pairs(WarbandStorage:BagCounts()) do
        local info = Info(itemID)
        if info and matches(info) then items[itemID] = 0 end
    end
    return items
end

local function Add(key, kind)
    Standard.kinds[key] = kind
    table.insert(Standard.order, key)
end

for _, category in ipairs(REAGENTS) do
    local subclasses = {}
    for _, subclassID in ipairs(category.subclasses) do subclasses[subclassID] = true end
    Add(category.key, {
        type = "deposit",
        reagent = true,
        items = function(set)
            local expansion = set.currentExpansionOnly and GetExpansionLevel()
            return BagItems(function(info)
                return info.classID == TRADEGOODS and subclasses[info.subclassID]
                    and (not expansion or info.expansionID == expansion)
            end)
        end,
    })
end

Add("lumber", {
    type = "deposit",
    items = function()
        return BagItems(function(info)
            -- Lumber shares the catch-all Other subclass, so the name narrows it.
            -- ponytail: English item names only, as Grab-bag matched them; a list
            -- of lumber item IDs if other locales need it.
            return info.classID == TRADEGOODS and info.subclassID == OTHER_SUBCLASS
                and info.name ~= nil and info.name:lower():find("lumber", 1, true) ~= nil
        end)
    end,
})

local function KnownProfessionVariants()
    local known = {}
    for _, lineID in pairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines() or {}) do known[lineID] = true end
    return known
end

-- The tooltip draws an unmet requirement, such as too little skill, in red.
local function MeetsRequirements(itemID)
    local data = C_TooltipInfo.GetItemByID(itemID)
    for _, line in ipairs(data and data.lines or {}) do
        local color = line.leftColor
        if color and color.r > 0.9 and color.g < 0.3 and color.b < 0.3 then return false end
    end
    return true
end

Add("treatise", {
    type = "keep",
    items = function()
        local items, known = {}, KnownProfessionVariants()
        for _, treatise in ipairs(TREATISES) do
            if (known[treatise.variant] or C_SpellBook.IsSpellKnown(treatise.spell))
                and not C_QuestLog.IsQuestFlaggedCompleted(treatise.quest)
                and MeetsRequirements(treatise.itemID) then
                items[treatise.itemID] = 1
            end
        end
        return items
    end,
})

-- The set as StockRules.Merge reads it, with its items worked out now.
function Standard.Resolve(set)
    local kind = Standard.kinds[set.standard]
    return {
        type = set.type,
        returnExtras = set.returnExtras,
        lowStockWarning = set.lowStockWarning,
        -- A kind added by a newer version of the addon has no rule here.
        items = kind and kind.items(set) or {},
    }
end
