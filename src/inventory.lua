WarbandStorage = WarbandStorage or {}

function WarbandStorage:GetDesiredStock()
    WarbandStorageData = WarbandStorageData or { default = {} }
    WarbandStorageCharData = WarbandStorageCharData or { useDefault = true, override = {} }

    if WarbandStorageCharData.useDefault == false then
        local merged = {}
        for itemID, count in pairs(WarbandStorageData.default or {}) do
            local override = WarbandStorageCharData.override[itemID]
            if override ~= nil then
                merged[itemID] = override  -- may be 0
            else
                merged[itemID] = count
            end
        end

        -- Also include any character-only items not in global
        for itemID, count in pairs(WarbandStorageCharData.override or {}) do
            if WarbandStorageData.default[itemID] == nil then
                merged[itemID] = count
            end
        end

        return merged
    else
        return WarbandStorageData.default or {}
    end
end

function WarbandStorage:ScanBags()
    local inventory = {}
    -- Include reagent bag (index 5) when present
    local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
    local bagIDs = {}
    for bag = 0, NUM_BAG_SLOTS do table.insert(bagIDs, bag) end
    local ok = pcall(function() return C_Container.GetContainerNumSlots(REAGENT_BAG) end)
    if ok then
        local slots = C_Container.GetContainerNumSlots(REAGENT_BAG)
        if type(slots) == "number" and slots > 0 then table.insert(bagIDs, REAGENT_BAG) end
    end

    for _, bag in ipairs(bagIDs) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo then
                local itemID = itemInfo.itemID
                local quantity = itemInfo.stackCount or 1
                inventory[itemID] = (inventory[itemID] or 0) + quantity
            end
        end
    end

    self.inventory = inventory
    -- Debug: report bag scan coverage
    local dbg = {}
    for _, b in ipairs(bagIDs) do table.insert(dbg, tostring(b)) end
    self:DebugPrint("Bag scan complete. Scanned bags: " .. table.concat(dbg, ", "))
end

function WarbandStorage:PrintTrackedInventory()
    self:DebugPrint("Tracked items in your inventory:")
    for itemID, desiredCount in pairs(self:GetDesiredStock()) do
        local currentCount = self.inventory[itemID] or 0
        local itemName = C_Item.GetItemCount(itemID)

        if not itemName then
            C_Timer.After(0.5, function()
                local name = C_Item.GetItemCount(itemID) or ("Item " .. itemID)
                self:DebugPrint(string.format("- %s (ID: %d): %d / %d",name, itemID, currentCount, desiredCount))
            end)
        else
            self:DebugPrint(string.format("- %s (ID: %d): %d / %d",itemName, itemID, currentCount, desiredCount))
        end
    end
end

function WarbandStorage:ReportMissingItems()
    for itemID, desiredCount in pairs(self:GetDesiredStock()) do
        local currentCount = self.inventory[itemID] or 0
        if currentCount < desiredCount then
            local itemName = C_Item.GetItemCount(itemID) or ("Item " .. itemID)
            self:DebugPrint(("You need %d more of %s (have %d, want %d)"):format(
                desiredCount - currentCount, itemName, currentCount, desiredCount
            ))
        end
    end
end

-- Small window listing every tracked item this character's bags are short
-- of. Opens at login for profiles that opt in.
local MAX_ROWS = 12
local ROW_H = 22
local HIDE_AFTER = 10

local function LowStockFrame(self)
    if self.lowStockFrame then return self.lowStockFrame end
    local S = self.Strings
    local f = LuckyUI.CreatePanel("WarbandStockistLowStock", UIParent, 300, 100)
    LuckyUI.CreateHeader(f, S.lowStock.title)
    f:SetFrameStrata("MEDIUM")
    LuckyUI.EnableDrag(f, { db = WarbandStockistDB, key = "lowStockPos", default = { "TOPLEFT", "TOPLEFT", 20, -120 } })
    LuckyUI.EnableAutoHide(f, HIDE_AFTER)
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

function WarbandStorage:WarnLowStock()
    local mgr = self.ProfileManager
    local profileName = mgr:GetActiveProfileName()
    if not self:IsLowStockWarningEnabled(profileName) then return end

    local short, ids = {}, {}
    for key, want in pairs(mgr:GetDesiredStock(profileName)) do
        local itemID, desired = tonumber(key), tonumber(want) or 0
        local have = itemID and C_Item.GetItemCount(itemID, false) or 0
        if itemID and have < desired then
            short[itemID] = { have = have, want = desired }
            table.insert(ids, itemID)
        end
    end
    if #ids == 0 then return end

    local S = self.Strings
    LuckyItem:GetMany(ids, function(infos)
        table.sort(ids, function(a, b)
            local na, nb = infos[a] and infos[a].name or "", infos[b] and infos[b].name or ""
            return na < nb
        end)
        local f = LowStockFrame(self)
        local shown = math.min(#ids, MAX_ROWS)
        for i, row in ipairs(f.rows) do row:SetShown(i <= shown or (i == shown + 1 and #ids > MAX_ROWS)) end
        for i = 1, shown do
            local itemID, info, row = ids[i], infos[ids[i]], LowStockRow(f, i)
            row.icon:SetTexture(info and info.icon or 134400)
            row.name:SetText(info and info.link or S.commands.itemIdFallback:format(itemID))
            row.count:SetText(S.lowStock.count:format(short[itemID].have, short[itemID].want))
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
        f:StartAutoHide()
    end)
end
