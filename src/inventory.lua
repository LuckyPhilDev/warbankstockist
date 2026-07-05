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
