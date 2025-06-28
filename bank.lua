WarbandStorage = WarbandStorage or {}

-- Delay Constants (tunable)
local perItemDelay = 0.25
local pickupDelay = 0.1
local withdrawDelay = 0.2
local placeDelay = 0.05
local depositDelay = 0.1

function WarbandStorage:CheckAndWithdrawItemsFromWarbank()
    self:DebugPrint("Running CheckAndWithdrawItemsFromWarbank")

    local desired = self:GetDesiredStock()
    local withdrawQueue = {}

    for itemID, desiredQty in pairs(desired) do
        if desiredQty > 0 then
            local countInBags = C_Item.GetItemCount(itemID, false)
            local needed = desiredQty - countInBags
            if needed > 0 then
                table.insert(withdrawQueue, { itemID = itemID, needed = needed })
            end
        end
    end

    self:ProcessWithdrawQueue(withdrawQueue, 1)
end

function WarbandStorage:ProcessWithdrawQueue(queue, index)
    if index > #queue then
        self:DebugPrint("Finished all queued withdrawals.")
        if WarbandStorageCharData.enableExcessDeposit then
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
    local maxStackSize = select(8, C_Item.GetItemInfo(itemID))
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and info.stackCount < maxStackSize then
                return bag, slot
            end
        end
    end
    return nil, nil
end

function WarbandStorage:FindEmptyBagSlot()
    for bag = 0, NUM_BAG_SLOTS do
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
                                self:DebugPrint("No valid bag slot found to place withdrawn item:", itemID)
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

    local desired = self:GetDesiredStock()
    local inventory = self.inventory or {}

    local depositQueue = {}

    for itemID, countInBags in pairs(inventory) do
        local desiredCount = desired[itemID] or 0
        local excess = countInBags - desiredCount

        if desired[itemID] and excess > 0 then
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
    local maxStackSize = select(8, C_Item.GetItemInfo(itemID))
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    for _, bagID in ipairs(tabIDs) do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info and info.itemID == itemID and info.stackCount < maxStackSize then
                return bagID, slot
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
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                table.insert(bagSlots, { bag = bag, slot = slot, count = info.stackCount })
            end
        end
    end

    local function depositNext(index, remaining)
        if index > #bagSlots or remaining <= 0 then
            self:DebugPrint("Deposit complete or no more bag slots. Remaining:", remaining)
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
                -- Split into empty slot first
                local tmpBag, tmpSlot = self:FindEmptyBagSlot()
                if not tmpBag then
                    self:DebugPrint("No empty bag slot available to complete split.")
                    if callback then callback() end
                    return
                end

                C_Container.SplitContainerItem(bag, slot, toMove)
                C_Timer.After(placeDelay, function()
                    self:DebugPrint(("AFTER SPLIT: Cursor now has: %s"):format(C_Cursor.GetCursorItem() and C_Item.GetItemName(C_Cursor.GetCursorItem()) or "nil"))
                    C_Container.PickupContainerItem(tmpBag, tmpSlot)

                    C_Timer.After(depositDelay, function()
                        -- Now pick up the newly split stack from its temp location
                        local info = C_Container.GetContainerItemInfo(tmpBag, tmpSlot)
                        if info and info.itemID == itemID then
                            C_Container.PickupContainerItem(tmpBag, tmpSlot)

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
                        else
                            self:DebugPrint("Failed to find or pick up newly split stack.")
                        end

                        C_Timer.After(perItemDelay, function()
                            depositNext(index + 1, remaining - toMove)
                        end)
                    end)
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
