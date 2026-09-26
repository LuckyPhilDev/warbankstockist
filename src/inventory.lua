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
            local line = S.report.line:format(name(itemID), itemID, C_Item.GetItemCount(itemID, false) or 0, range.min)
            if range.max < math.huge then line = line .. S.report.extras:format(range.max) end
            local reserve = self.Sets:GetReserve(itemID)
            if reserve then line = line .. S.report.reserve:format(reserve) end
            print("  " .. line)
        end
    end)
end

-- Small window listing every tracked item this character's bags are short
-- of. Opens at login and on entering a rest area, for sets that opt in.
local MAX_ROWS = 12
local ROW_H = 22

local function LowStockFrame(self)
    if self.lowStockFrame then return self.lowStockFrame end
    local S = self.Strings
    local f = LuckyUI.CreatePanel("WarbandStockistLowStock", UIParent, 340, 100)
    LuckyUI.CreateHeader(f, S.lowStock.title)
    f:SetFrameStrata("MEDIUM")
    LuckyUI.EnableDrag(f, { db = WarbandStockistDB, key = "lowStockPos", default = { "TOPLEFT", "TOPLEFT", 20, -120 } })
    LuckyUI.EnableAutoHide(f, WarbandStockistDB.lowStockSeconds)
    f.rows = {}
    self.lowStockFrame = f
    return f
end

local function LowStockRow(f, i)
    local row = f.rows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, f)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 10, -36 - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", -10, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(LuckyUI.BODY_FONT, 12, "")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetJustifyH("LEFT")
    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetFont(LuckyUI.BODY_FONT, 12, "")
    row.count:SetTextColor(LuckyUI.C.textMuted[1], LuckyUI.C.textMuted[2], LuckyUI.C.textMuted[3])
    row.count:SetPoint("RIGHT")
    row.name:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
    f.rows[i] = row
    return row
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

local function HoldWhileResting()
    return WarbandStockistDB.lowStockStayWhileResting and IsResting()
end

-- Opens the window, or with refreshOnly redraws it only if it is already up,
-- so a restock shrinks the list without popping the window back open.
function WarbandStorage:WarnLowStock(refreshOnly)
    local short, ids = self:LowStock()
    self.Minimap:SetLowCount(#ids)
    local f = self.lowStockFrame
    if #ids == 0 then
        if f and f:IsShown() then
            f:StopAutoHide()
            f:Hide()
        end
        return
    end
    if refreshOnly and not (f and f:IsShown()) then return end

    local S = self.Strings
    LuckyItem:GetMany(ids, function(infos)
        table.sort(ids, function(a, b)
            local na, nb = infos[a] and infos[a].name or "", infos[b] and infos[b].name or ""
            return na < nb
        end)
        local f = LowStockFrame(self)
        if refreshOnly and not f:IsShown() then return end
        local shown = math.min(#ids, MAX_ROWS)
        for i, row in ipairs(f.rows) do row:SetShown(i <= shown or (i == shown + 1 and #ids > MAX_ROWS)) end
        for i = 1, shown do
            local itemID, info, row = ids[i], infos[ids[i]], LowStockRow(f, i)
            row.icon:SetTexture(info and info.icon or 134400)
            row.name:SetText(info and info.link or S.commands.itemIdFallback:format(itemID))
            row.count:SetText(CountText(S, short[itemID]))
            row:Show()
        end
        if #ids > MAX_ROWS then
            local row = LowStockRow(f, shown + 1)
            row.icon:SetTexture(nil)
            row.name:SetText(S.lowStock.more:format(#ids - MAX_ROWS))
            row.count:SetText("")
            row:Show()
            shown = shown + 1
        end
        f:SetHeight(36 + shown * ROW_H + 10)
        f:Show()
        if refreshOnly then return end
        if HoldWhileResting() then
            f:StopAutoHide()
        else
            f:StartAutoHide(WarbandStockistDB.lowStockSeconds)
        end
    end)
end

-- Leaving the rest area lets a window held open by the setting fade as usual.
function WarbandStorage:OnRestingChanged()
    local resting = IsResting()
    if resting == self.wasResting then return end
    self.wasResting = resting
    if resting then
        self:WarnLowStock()
    elseif self.lowStockFrame and self.lowStockFrame:IsShown() and WarbandStockistDB.lowStockStayWhileResting then
        self.lowStockFrame:StartAutoHide(WarbandStockistDB.lowStockSeconds)
    end
end
