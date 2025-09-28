WarbandStorage = WarbandStorage or {}

-- Delay Constants (tunable)
local perItemDelay = 0.25
local pickupDelay = 0.1
local withdrawDelay = 0.2
local placeDelay = 0.05
local depositDelay = 0.1

-- Bag constants/helpers
local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5 -- retail DF+: reagent bag index
local function GetRegularBagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do
        table.insert(ids, bag)
    end
    return ids
end

local function GetAllPlayerBagIDs()
    local ids = GetRegularBagIDs()
    -- Add reagent bag if it exists for this character/client
    local ok = pcall(function() return C_Container.GetContainerNumSlots(REAGENT_BAG) end)
    if ok then
        local slots = C_Container.GetContainerNumSlots(REAGENT_BAG)
        if type(slots) == "number" and slots > 0 then
            table.insert(ids, REAGENT_BAG)
        end
    end
    return ids
end

local function GetAssignedDesired()
    local mgr = WarbandStorage.ProfileManager
    if not mgr or not mgr.GetActiveProfileName then return {}, nil end
    local pname = mgr:GetActiveProfileName()
    if not pname or pname == "" then return {}, nil end
    -- Ensure profile exists and fetch desired items from it
    mgr:EnsureProfile(pname)
    local rawDesired = mgr.GetDesiredStock and mgr:GetDesiredStock(pname) or {}
    -- Normalize keys to numeric itemIDs to avoid string/number mismatches
    local desired = {}
    for k, v in pairs(rawDesired) do
        local id = tonumber(k)
        if id then desired[id] = tonumber(v) or 0 end
    end
    return desired, pname
end

function WarbandStorage:CheckAndWithdrawItemsFromWarbank()
    self:DebugPrint("Running CheckAndWithdrawItemsFromWarbank")

    local desired, profileName = GetAssignedDesired()
    if profileName then
        self:DebugPrint(("Using assigned profile for withdraw: %s"):format(profileName))
    else
        self:DebugPrint("No assigned profile; nothing to withdraw.")
    end
    local desiredKeys = {}
    for itemID, desiredQty in pairs(desired) do
        table.insert(desiredKeys, itemID)
    end
    table.sort(desiredKeys)
    self:DebugPrint(("Desired map contains %d items"):format(#desiredKeys))
    local withdrawQueue = {}

    for _, itemID in ipairs(desiredKeys) do
        local desiredQty = desired[itemID]
        if desiredQty > 0 then
            local countInBags = C_Item.GetItemCount(itemID, false)
            local needed = desiredQty - countInBags
            self:DebugPrint(("Item %d: want %d, have %d, need %d"):format(itemID, desiredQty, countInBags or 0, needed))
            if needed > 0 then table.insert(withdrawQueue, { itemID = itemID, needed = needed }) end
        end
    end

    self:DebugPrint(("Withdraw queue size: %d"):format(#withdrawQueue))
    self:ProcessWithdrawQueue(withdrawQueue, 1)
end

function WarbandStorage:ProcessWithdrawQueue(queue, index)
    if index > #queue then
        self:DebugPrint("Finished all queued withdrawals.")
        if WarbandStorageCharData and WarbandStorageCharData.enableExcessDeposit then
            self:DepositExcessItemsToWarbank()
        end
        return
    end

    local entry = queue[index]
    self:WithdrawItemFromWarbank(entry.itemID, entry.needed)

    C_Timer.After(perItemDelay, function()
        self:ProcessWithdrawQueue(queue, index + 1)
    end)
end

function WarbandStorage:FindStackableBagSlot(itemID)
    local function slotMax(bag, slot)
        if ItemLocation and ItemLocation.CreateFromBagAndSlot then
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if loc and C_Item.DoesItemExist(loc) then
                local m = C_Item.GetItemMaxStackSize(loc)
                if m and m > 0 then return m end
            end
        end
        return select(8, C_Item.GetItemInfo(itemID))
    end
    -- Allow stacking into any bag that already contains this item, including reagent bag
    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                local maxStack = slotMax(bag, slot)
                if maxStack and (info.stackCount or 0) < maxStack then
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

function WarbandStorage:FindEmptyBagSlot()
    -- Prefer only regular bags for empty-slot placement to avoid invalid moves into reagent bag
    for _, bag in ipairs(GetRegularBagIDs()) do
        local freeSlots = C_Container.GetContainerFreeSlots(bag)
        if freeSlots and #freeSlots > 0 then
            return bag, freeSlots[1]
        end
    end
    return nil, nil
end

function WarbandStorage:WithdrawItemFromWarbank(itemID, needed)
    self:DebugPrint(string.format("Withdrawing %d of item %d", needed, itemID))

    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if not tabIDs then
        self:DebugPrint("No warband bank tabs found.")
        return
    end
    if type(tabIDs) ~= "table" or #tabIDs == 0 then
        self:DebugPrint("Warband bank tab list is empty or invalid.")
    else
        self:DebugPrint(("Warband bank tabs available: %d"):format(#tabIDs))
    end

    local function findAndWithdraw()
        for _, bagID in ipairs(tabIDs) do
            local numSlots = C_Container.GetContainerNumSlots(bagID)
            for slot = 1, numSlots do
                local id = C_Container.GetContainerItemID(bagID, slot)
                if id == itemID then
                    local info = C_Container.GetContainerItemInfo(bagID, slot)
                    local stackSize = info and info.stackCount or 1
                    local toWithdraw = math.min(stackSize, needed)

                    self:DebugPrint(string.format("Found stack of %d in bank bag %d, slot %d", stackSize, bagID, slot))

                    C_Timer.After(pickupDelay, function()
                        ClearCursor()
                        if toWithdraw < stackSize then
                            C_Container.SplitContainerItem(bagID, slot, toWithdraw)
                        else
                            C_Container.PickupContainerItem(bagID, slot)
                        end

                        C_Timer.After(placeDelay, function()
                            local destBag, destSlot = self:FindStackableBagSlot(itemID)
                            if not destBag then
                                destBag, destSlot = self:FindEmptyBagSlot()
                            end

                            if destBag and destSlot then
                                C_Container.PickupContainerItem(destBag, destSlot)
                            else
                                self:DebugPrint(("No valid bag slot found to place withdrawn item: %s"):format(tostring(itemID)))
                            end

                            local remaining = needed - toWithdraw
                            if remaining > 0 then
                                C_Timer.After(withdrawDelay, function()
                                    self:WithdrawItemFromWarbank(itemID, remaining)
                                end)
                            end
                        end)
                    end)

                    return true
                end
            end
        end

        self:DebugPrint(string.format("No more stacks found for item %s", itemID))
        return false
    end

    findAndWithdraw()
end

function WarbandStorage:DepositExcessItemsToWarbank()
    self:DebugPrint("Checking for excess items to deposit.")
    self:ScanBags()

    local desired, profileName = GetAssignedDesired()
    if profileName then
        self:DebugPrint(("Using assigned profile for deposit: %s"):format(profileName))
    else
        self:DebugPrint("No assigned profile for deposit.")
    end
    local inventory = self.inventory or {}
    -- Debug: summarize desired vs inventory keys (small sets only)
    do
        local dcount, icount = 0, 0
        for _ in pairs(desired) do dcount = dcount + 1 end
        for _ in pairs(inventory) do icount = icount + 1 end
        self:DebugPrint(("Desired entries: %d | Inventory entries: %d"):format(dcount, icount))
        -- Print small lists (<=5) to aid troubleshooting
        if dcount <= 5 then
            for id, want in pairs(desired) do
                self:DebugPrint(("Desired: %d -> %d"):format(id, want))
            end
        end
        if icount <= 5 then
            for id, have in pairs(inventory) do
                self:DebugPrint(("Inventory: %d -> %d"):format(id, have))
            end
        end
    end

    local depositQueue = {}

    for itemID, countInBags in pairs(inventory) do
        local hasDesiredEntry = (desired[itemID] ~= nil)
        local desiredCount = hasDesiredEntry and desired[itemID] or 0
        local excess = countInBags - desiredCount

        -- Deposit if the item exists in the desired map (even if desiredCount is 0) and we have more than desired
        if hasDesiredEntry and excess > 0 then
            self:DebugPrint(("Excess found: Item %d x%d (have %d, want %d)"):format(
                itemID, excess, countInBags, desiredCount))
            table.insert(depositQueue, { itemID = itemID, amount = excess })
        end
    end

    self:ProcessDepositQueue(depositQueue, 1)
end

function WarbandStorage:ProcessDepositQueue(queue, index)
    if index > #queue then
        self:DebugPrint("Finished all excess deposits.")
        return
    end

    local entry = queue[index]
    self:TryDepositItem(entry.itemID, entry.amount, function()
        C_Timer.After(perItemDelay, function()
            self:ProcessDepositQueue(queue, index + 1)
        end)
    end)
end

function WarbandStorage:FindStackableBankSlot(itemID)
    local function slotMax(bag, slot)
        if ItemLocation and ItemLocation.CreateFromBagAndSlot then
            local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if loc and C_Item.DoesItemExist(loc) then
                local m = C_Item.GetItemMaxStackSize(loc)
                if m and m > 0 then return m end
            end
        end
        return select(8, C_Item.GetItemInfo(itemID))
    end
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    for _, bagID in ipairs(tabIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID == itemID then
                local maxStack = slotMax(bagID, slot)
                if maxStack and (info.stackCount or 0) < maxStack then
                    return bagID, slot
                end
            end
        end
    end
    return nil, nil
end

function WarbandStorage:FindEmptyBankSlot()
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    for _, bankBag in ipairs(tabIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bankBag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bankBag, slot)
            if not info then
                return bankBag, slot
            end
        end
    end
    return nil, nil
end

function WarbandStorage:TryDepositItem(itemID, amountToDeposit, callback)
    local bagSlots = {}

    -- Collect all bag slots containing the item to deposit
    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                table.insert(bagSlots, { bag = bag, slot = slot, count = info.stackCount })
            end
        end
    end

    -- Debug: show where we found stacks (helps verify reagent bag coverage)
    if #bagSlots == 0 then
        self:DebugPrint("No bag stacks found for item in any player bag (including reagent bag if available).")
    else
        local countsByBag = {}
        for _, e in ipairs(bagSlots) do countsByBag[e.bag] = (countsByBag[e.bag] or 0) + 1 end
        local parts = {}
        for bag, cnt in pairs(countsByBag) do table.insert(parts, ("%d=%d slots"):format(bag, cnt)) end
        table.sort(parts)
        self:DebugPrint("Candidate bag slots by bag: " .. table.concat(parts, ", "))
    end

    local function depositNext(index, remaining)
        if index > #bagSlots or remaining <= 0 then
            self:DebugPrint(("Deposit complete or no more bag slots. Remaining: %d"):format(remaining or 0))
            if callback then callback() end
            return
        end

        local entry = bagSlots[index]
        local bag, slot, stackCount = entry.bag, entry.slot, entry.count
        local toMove = math.min(stackCount, remaining)

        self:DebugPrint(("Preparing to move %d from bag %d slot %d (stack=%d, remaining=%d)"):format(
            toMove, bag, slot, stackCount, remaining))

        C_Timer.After(pickupDelay, function()
            ClearCursor()
            local lockInfo = select(3, C_Container.GetContainerItemInfo(bag, slot))
            self:DebugPrint(("Pre-split: Item lock state at %d:%d: %s"):format(bag, slot, tostring(lockInfo)))

            if toMove < stackCount then
                -- Split off the portion we want directly to the cursor, then place into bank
                C_Container.SplitContainerItem(bag, slot, toMove)
                C_Timer.After(placeDelay, function()
                    local cursorType = GetCursorInfo()
                    if cursorType ~= "item" then
                        self:DebugPrint("Split did not put item on cursor; aborting this move.")
                        C_Timer.After(perItemDelay, function()
                            depositNext(index + 1, remaining) -- do not decrement; nothing moved
                        end)
                        return
                    end

                    local destBag, destSlot = self:FindStackableBankSlot(itemID)
                    if not destBag then
                        destBag, destSlot = self:FindEmptyBankSlot()
                        self:DebugPrint("No stackable slot, using empty bank slot instead.")
                    else
                        self:DebugPrint(("Found stackable slot: %d:%d"):format(destBag, destSlot))
                    end

                    if destBag and destSlot then
                        self:DebugPrint(("Placing split item into %d:%d"):format(destBag, destSlot))
                        C_Container.PickupContainerItem(destBag, destSlot)
                        C_Timer.After(perItemDelay, function()
                            depositNext(index + 1, remaining - toMove)
                        end)
                    else
                        self:DebugPrint("No valid destination slot found for bank deposit (split path). Returning item to original slot.")
                        -- Try to put it back
                        C_Container.PickupContainerItem(bag, slot)
                        C_Timer.After(perItemDelay, function()
                            depositNext(index + 1, remaining) -- do not decrement
                        end)
                    end
                end)
            else
                self:DebugPrint("Picking up full stack")
                C_Container.PickupContainerItem(bag, slot)
                C_Timer.After(depositDelay, function()
                    local destBag, destSlot = self:FindStackableBankSlot(itemID)
                    if not destBag then
                        destBag, destSlot = self:FindEmptyBankSlot()
                        self:DebugPrint("No stackable slot, using empty bank slot instead.")
                    else
                        self:DebugPrint(("Found stackable slot: %d:%d"):format(destBag, destSlot))
                    end

                    if destBag and destSlot then
                        self:DebugPrint(("Placing item into %d:%d"):format(destBag, destSlot))
                        C_Container.PickupContainerItem(destBag, destSlot)
                    else
                        self:DebugPrint("No valid destination slot found for bank deposit.")
                        ClearCursor()
                    end

                    C_Timer.After(perItemDelay, function()
                        depositNext(index + 1, remaining - toMove)
                    end)
                end)
            end
        end)
    end

    depositNext(1, amountToDeposit)
end
