WarbandStorage = WarbandStorage or {}

local function CurrentRanges()
    return WarbandStorage.Sets:RangesFor(WarbandStorage.Utils:GetCharacterKey())
end

-- { [itemID] = count } across the bags, reagent bag included when present.
function WarbandStorage:BagCounts()
    local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    local bagIDs = {}
    for bag = 0, NUM_BAG_SLOTS do table.insert(bagIDs, bag) end
    local ok = pcall(function() return C_Container.GetContainerNumSlots(REAGENT_BAG) end)
    if ok then
        local slots = C_Container.GetContainerNumSlots(REAGENT_BAG)
        if type(slots) == "number" and slots > 0 then table.insert(bagIDs, REAGENT_BAG) end
    end

    local counts = {}
    for _, bag in ipairs(bagIDs) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                counts[itemInfo.itemID] = (counts[itemInfo.itemID] or 0) + (itemInfo.stackCount or 1)
            end
        end
    end
    return counts
end

function WarbandStorage:ScanBags()
    self.inventory = self:BagCounts()
    self:DebugPrint("Bag scan complete.")
end

function WarbandStorage:PrintReport()
    local S = self.Strings
    local ranges = CurrentRanges()
    local ids = {}
    for itemID in pairs(ranges) do ids[#ids + 1] = itemID end
    if #ids == 0 then
        print(S.addon.prefix .. " " .. S.report.empty)
        return
    end

    LuckyItem:GetMany(ids, function(infos)
        local function name(itemID)
            return infos[itemID] and infos[itemID].name or S.items.unknownItem:format(itemID)
        end
        table.sort(ids, function(a, b) return name(a) < name(b) end)

        print(S.addon.prefix .. " " .. S.report.title)
        for _, itemID in ipairs(ids) do
            local range = ranges[itemID]
            local have = C_Item.GetItemCount(itemID, false) or 0
            local line = range.min == math.huge and S.report.lineAll:format(name(itemID), itemID, have)
                or S.report.line:format(name(itemID), itemID, have, range.min)
            if range.max < math.huge then line = line .. S.report.extras:format(range.max) end
            local reserve = self.Sets:GetReserve(itemID)
            if reserve then line = line .. S.report.reserve:format(reserve) end
            print("  " .. line)
        end
    end)
end

-- What the bags hold, what the Warband Bank can hand over towards range.min,
-- and what has to be bought or crafted on top.
function WarbandStorage:Supply(itemID, range)
    local StockRules = self.StockRules
    local inBags = C_Item.GetItemCount(itemID, false) or 0
    local inWarbank = (C_Item.GetItemCount(itemID, false, false, false, true) or 0) - inBags
    local reserve, priority = self.Sets:GetReserve(itemID), self.Sets:IsPriority(self.Utils:GetCharacterKey())
    return inBags,
        StockRules.Withdrawal(range, inBags, inWarbank, reserve, priority),
        StockRules.Purchase(range, inBags, inWarbank, reserve, priority)
end

-- short[itemID] = { have, want, fromBank, toBuy } for each warned item the bags
-- are below, and ids lists those items.
function WarbandStorage:LowStock()
    local short, ids = {}, {}
    for itemID, range in pairs(CurrentRanges()) do
        if range.warn then
            local have, fromBank, toBuy = self:Supply(itemID, range)
            if have < range.min then
                short[itemID] = { have = have, want = range.min, fromBank = fromBank, toBuy = toBuy }
                table.insert(ids, itemID)
            end
        end
    end
    return short, ids
end

local function CountText(S, item)
    local WC = LuckyUI.WC
    local text = S.lowStock.count:format(item.have, item.want)
    if item.toBuy > 0 then text = WC.danger .. text .. WC.reset end
    if item.fromBank > 0 then
        text = WC.info .. S.lowStock.inBank:format(item.fromBank) .. WC.reset .. "  " .. text
    end
    return text
end

function WarbandStorage:LowStockRows()
    local short, ids = self:LowStock()
    local rows = {}
    for i, itemID in ipairs(ids) do
        rows[i] = { itemID = itemID, detail = CountText(self.Strings, short[itemID]) }
    end
    return rows
end

function WarbandStorage:RefreshLowStock()
    local _, ids = self:LowStock()
    self.Minimap:SetLowCount(#ids)
    LuckyReminders:Refresh()
end
