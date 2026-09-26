-- luacheck: globals C_Item GetExpansionLevel C_TradeSkillUI C_SpellBook C_QuestLog C_TooltipInfo

LuckyStrings = { New = function(_, strings) return strings end }
WarbandStorage, WarbandStockistDB = nil, nil

-- itemID -> name, classID, subclassID, expansionID
local ITEMS = {
    [1] = { "Luredrop", 7, 9, 11 },
    [2] = { "Old Herb", 7, 9, 9 },
    [3] = { "Thalassian Lumber", 7, 11, 11 },
    [4] = { "Copper Ore", 7, 7, 11 },
    [5] = { "Some Sword", 2, 7, 11 },
    [6] = { "Misc Thing", 7, 11, 11 },
    [9] = { "Yellow Housing Dye", 20, 1, 11 },
}
local ALCHEMY, MINING = 245755, 245762

local bags = {}
local loaded = {}
local knownLines, knownSpells, questsDone, redTooltip = {}, {}, {}, {}

C_Item = {
    GetItemInfo = function(itemID)
        local item = loaded[itemID] and ITEMS[itemID]
        if not item then return nil end
        return item[1], nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, item[2], item[3], nil, item[4]
    end,
}
function GetExpansionLevel() return 11 end
C_TradeSkillUI = { GetAllProfessionTradeSkillLines = function() return knownLines end }
C_SpellBook = { IsSpellKnown = function(spellID) return knownSpells[spellID] == true end }
C_QuestLog = { IsQuestFlaggedCompleted = function(questID) return questsDone[questID] == true end }
C_TooltipInfo = {
    GetItemByID = function(itemID)
        local color = redTooltip[itemID] and { r = 1, g = 0.1, b = 0.1 } or { r = 1, g = 1, b = 1 }
        return { lines = { { leftText = "Requires", leftColor = color } } }
    end,
}

dofile("src/Strings.lua")
dofile("src/StockRules.lua")
dofile("src/StandardSets.lua")
dofile("src/Sets.lua")
WarbandStorage.Settings = { Refresh = function() end }
function WarbandStorage:BagCounts() return bags end
local warbank = {}
function WarbandStorage:WarbankCounts() return warbank end

local Standard, Sets = WarbandStorage.StandardSets, WarbandStorage.Sets

local passed = 0
local function check(label, actual, expected)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local function keys(items)
    local list = {}
    for itemID in pairs(items) do list[#list + 1] = itemID end
    table.sort(list)
    return table.concat(list, ",")
end

local function items(kind, set)
    set = set or {}
    set.standard, set.type = kind, Standard.kinds[kind].type
    return Standard.Resolve(set).items
end

for itemID in pairs(ITEMS) do bags[itemID] = 3; loaded[itemID] = true end
bags[7] = 1 -- an item the client has not loaded yet

check("herbs", keys(items("herb")), "1,2")
check("herbs of the current expansion", keys(items("herb", { currentExpansionOnly = true })), "1")
check("metal and stone", keys(items("metalstone")), "4")
check("lumber by name only", keys(items("lumber")), "3")
check("housing dyes", keys(items("housingDye")), "9")
check("other reagents", keys(items("other")), "3,6")
check("deposit all sets send everything", items("herb")[1], 0)

warbank = { [1] = 50, [2] = 5, [4] = 20, [5] = 1 }
local withdraw = function(set) set = set or {}; set.standard, set.type = "herb", "keep"; return Standard.Resolve(set).items end
check("withdraw all reads the warband bank", keys(withdraw()), "1,2")
check("withdraw all takes everything", withdraw()[1], math.huge)
check("withdraw all keeps the expansion filter", keys(withdraw({ currentExpansionOnly = true })), "1")
warbank = {}

bags[8], ITEMS[8] = 2, { "Late Herb", 7, 9, 11 }
check("unloaded items wait", keys(items("herb")), "1,2")
loaded[8] = true
check("a late load joins the next scan", keys(items("herb")), "1,2,8")

check("no profession, no treatise", keys(items("treatise")), "")
knownLines = { 2871 }
check("treatise for a known profession", items("treatise")[ALCHEMY], 1)
knownSpells[423341] = true
check("treatise for a learned spell", items("treatise")[MINING], 1)
questsDone[95127] = true
check("used this week", items("treatise")[ALCHEMY], nil)
redTooltip[MINING] = true
check("skill too low", items("treatise")[MINING], nil)

check("a kind from a newer version resolves empty", keys(Standard.Resolve({ standard = "future", type = "deposit" }).items), "")

-- Through Sets: a Keep set wins over a standard Deposit All set.
local me = "Lucky-Area52"
WarbandStockistDB = { sets = {}, characters = { [me] = { sets = {} } }, ignoredCharacters = {}, reserves = {} }
local herbs = Sets:AddStandard("herb")
check("standard set named for its direction", herbs.name, "Herbs: Deposit")
check("standard set type", herbs.type, "deposit")
check("second copy gets a unique name", Sets:AddStandard("herb").name, "Herbs: Deposit 2")
Sets:SetMember(herbs.id, me, true)
local raiding = Sets:Create("Raiding")
Sets:SetItem(raiding.id, 1, 5)
Sets:SetMember(raiding.id, me, true)
local ranges = Sets:RangesFor(me)
check("keep wins over the standard set", ranges[1].min, 5)
check("keep wins with its extras returned", ranges[1].max, 5)
check("other herbs deposited", ranges[8].max, 0)
check("the unticked copy does nothing", ranges[4], nil)

-- Switching direction renames a set still under its own name.
Sets:SetType(herbs.id, "keep")
check("withdraw set named for its direction", herbs.name, "Herbs: Withdraw")
Sets:SetType(herbs.id, "deposit")
check("and back again", herbs.name, "Herbs: Deposit")
local herbs2 = Sets:Get(herbs.id + 1)
Sets:SetType(herbs.id, "keep")
Sets:SetType(herbs2.id, "keep")
check("a numbered copy is renamed too, uniquely", herbs2.name, "Herbs: Withdraw 2")
Sets:Rename(herbs2.id, "AH Mule")
Sets:SetType(herbs2.id, "deposit")
check("a renamed set keeps its name", herbs2.name, "AH Mule")
check("but still changes direction", herbs2.type, "deposit")
Sets:SetType(herbs.id, "deposit")
herbs.name = "Herbs"
Sets:SetType(herbs.id, "keep")
check("a set from before directions is renamed", herbs.name, "Herbs: Withdraw")
Sets:SetType(herbs.id, "deposit")
check("lumber has no direction", Sets:AddStandard("lumber").name, "Lumber")

-- What Lucky's Grab-bag calls to hand its settings over.
local skip = { ["Main-Area52"] = true }
local cloth = Sets:Get(WarbandStorage:ImportStandardSet("cloth", { everyCharacter = true, skip = skip, currentExpansionOnly = true }))
check("imported for everyone", cloth.everyCharacter, true)
check("mains skipped", cloth.skip["Main-Area52"], true)
skip["Other-Area52"] = true
check("skip list copied", cloth.skip["Other-Area52"], nil)
check("expansion option carried", cloth.currentExpansionOnly, true)
check("unknown kind refused", WarbandStorage:ImportStandardSet("future", {}), nil)
local list = Sets:Get(WarbandStorage:ImportDepositList("Custom Item Whitelist", { 800, 801 }, false))
check("list is deposit all", list.type, "deposit")
check("disabled list reaches nobody", list.everyCharacter, false)
check("list items", list.items[801], 0)

Sets:SetEveryCharacter(cloth.id, false)
check("Every Character off reaches nobody", #Sets:CharactersUsing(cloth.id), 0)
Sets:SetEveryCharacter(cloth.id, true)
check("Every Character on reaches everyone", #Sets:CharactersUsing(cloth.id), 1)

-- Warbound gear is scanned by bag slot in bank.lua, so the kind only has to
-- pass the set through and the bank pass has to see the right categories.
local scanned
function WarbandStorage:WarboundBagItems(cfg)
    scanned = cfg
    return { [99] = 0 }
end

local gear = Sets:AddStandard("warbound")
check("warbound set deposits", gear.type, "deposit")
check("armor on by default", gear.armor, true)
check("weapons on by default", gear.weapons, true)
check("tokens on by default", gear.tokens, true)
check("everything else on by default", gear.other, true)
check("warbound items come from the bag scan", keys(Standard.Resolve(gear).items), "99")
check("the scan reads the set's own categories", scanned, gear)
Sets:SetEveryCharacter(gear.id, true)
check("warbound stays out of the stock ranges", Sets:RangesFor("Main-Area52")[99], nil)
check("its categories reach the bank pass", Sets:WarboundOptions("Main-Area52").tokens, true)
check("no gear quality floor by default", Sets:WarboundOptions("Main-Area52").minGearQuality, 0)
local epicOnly = Sets:AddStandard("warbound")
epicOnly.minGearQuality = 4
Sets:SetEveryCharacter(epicOnly.id, true)
check("the loosest quality floor wins", Sets:WarboundOptions("Main-Area52").minGearQuality, 0)
gear.minGearQuality = 3
check("floors combine to the lowest", Sets:WarboundOptions("Main-Area52").minGearQuality, 3)
Sets:Delete(epicOnly.id)
gear.armor, gear.weapons, gear.tokens, gear.other = false, false, false, false
check("a warbound set asking for nothing runs no pass", Sets:WarboundOptions("Main-Area52"), nil)

print(string.format("%d StandardSets tests passed", passed))
