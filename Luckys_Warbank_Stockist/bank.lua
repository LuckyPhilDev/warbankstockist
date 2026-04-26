WarbandStorage = WarbandStorage or {}

-- Tuning. Withdrawal advances on callbacks (cursor + lock), so timers only
-- exist as fallbacks and inter-step breathing room.
local LOCK_REPOLL = 0.1
local CURSOR_TICK = 0.04
local CURSOR_TRIES = 25
local STEP_GAP = 0.08
local depositDelay = 0.1
local pickupDelay = 0.1
local placeDelay = 0.05
local perItemDelay = 0.25

-- Bag helpers
local REAGENT_BAG = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
local function GetRegularBagIDs()
    local ids = {}
    for bag = 0, NUM_BAG_SLOTS do
        table.insert(ids, bag)
    end
    return ids
end

local function GetAllPlayerBagIDs()
    local ids = GetRegularBagIDs()
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
    mgr:EnsureProfile(pname)
    local rawDesired = mgr.GetDesiredStock and mgr:GetDesiredStock(pname) or {}
    local desired = {}
    for k, v in pairs(rawDesired) do
        local id = tonumber(k)
        if id then desired[id] = tonumber(v) or 0 end
    end
    return desired, pname
end

-- Walks the warband bank once and produces a flat list of moves keyed to
-- specific source slots. Each entry pre-commits a stack and amount so the
-- drainer never has to re-scan mid-flight.
local function PlanWithdrawals(self, itemIDs, desired)
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if type(tabIDs) ~= "table" or #tabIDs == 0 then
        self:DebugPrint("Warband bank has no purchased tabs to scan.")
        return {}
    end

    local plan = {}
    for _, itemID in ipairs(itemIDs) do
        local shortfall = (desired[itemID] or 0) - (C_Item.GetItemCount(itemID, false) or 0)
        self:DebugPrint(("Item %d: shortfall %d"):format(itemID, shortfall))
        if shortfall > 0 then
            for _, bagID in ipairs(tabIDs) do
                if shortfall <= 0 then break end
                local slots = C_Container.GetContainerNumSlots(bagID) or 0
                for slot = 1, slots do
                    if shortfall <= 0 then break end
                    local info = C_Container.GetContainerItemInfo(bagID, slot)
                    if info and info.itemID == itemID then
                        local stack = info.stackCount or 1
                        local take = math.min(stack, shortfall)
                        plan[#plan + 1] = {
                            itemID = itemID,
                            bagID = bagID,
                            slot = slot,
                            take = take,
                            stackAtPlan = stack,
                        }
                        shortfall = shortfall - take
                    end
                end
            end
        end
    end
    return plan
end

-- Polls GetCursorInfo() until the server attaches the split item or the
-- attempt budget runs out. Split is asynchronous; placing without this
-- check leaves the source slot locked and silently drops the operation.
local function AwaitCursorItem(onHave, onAbort)
    local left = CURSOR_TRIES
    local function poll()
        if GetCursorInfo() == "item" then
            onHave()
            return
        end
        left = left - 1
        if left <= 0 then
            onAbort()
            return
        end
        C_Timer.After(CURSOR_TICK, poll)
    end
    C_Timer.After(CURSOR_TICK, poll)
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

-- claimed: optional set of "bag:slot" strings already promised within this
-- batch. Avoids two queued tasks racing for the same empty slot before
-- BAG_UPDATE reflects the first placement.
function WarbandStorage:FindEmptyBagSlot(claimed)
    for _, bag in ipairs(GetRegularBagIDs()) do
        local freeSlots = C_Container.GetContainerFreeSlots(bag)
        if freeSlots then
            for _, slot in ipairs(freeSlots) do
                local key = bag .. ":" .. slot
                if not claimed or not claimed[key] then
                    if claimed then claimed[key] = true end
                    return bag, slot
                end
            end
        end
    end
    return nil, nil
end

function WarbandStorage:CheckAndWithdrawItemsFromWarbank()
    self:DebugPrint("Running CheckAndWithdrawItemsFromWarbank")

    local desired, profileName = GetAssignedDesired()
    if profileName then
        self:DebugPrint(("Using assigned profile for withdraw: %s"):format(profileName))
    else
        self:DebugPrint("No assigned profile; nothing to withdraw.")
        return
    end

    local itemIDs = {}
    for itemID, qty in pairs(desired) do
        if qty and qty > 0 then itemIDs[#itemIDs + 1] = itemID end
    end
    table.sort(itemIDs)
    self:DebugPrint(("Desired map contains %d items"):format(#itemIDs))

    local plan = PlanWithdrawals(self, itemIDs, desired)
    self:DebugPrint(("Planned %d withdrawal step(s)"):format(#plan))

    self:RunWithdrawPlan(plan, function()
        if WarbandStorageCharData and WarbandStorageCharData.enableExcessDeposit then
            self:DepositExcessItemsToWarbank()
        end
    end)
end

-- Drives plan strictly sequentially. A step never starts until the prior
-- step's cursor work has resolved. Three failure modes are handled
-- distinctly: source slot still locked (retry same step), source slot
-- changed identity since planning (skip), cursor never picked up the split
-- (skip and clear).
function WarbandStorage:RunWithdrawPlan(plan, onComplete)
    if #plan == 0 then
        if onComplete then onComplete() end
        return
    end

    local idx = 1
    local claimedSlots = {}

    local function step()
        if idx > #plan then
            self:DebugPrint("Withdrawal plan finished.")
            if onComplete then onComplete() end
            return
        end

        local task = plan[idx]
        local info = C_Container.GetContainerItemInfo(task.bagID, task.slot)

        if info and info.isLocked then
            self:DebugPrint(("Slot %d:%d still locked; re-polling"):format(task.bagID, task.slot))
            C_Timer.After(LOCK_REPOLL, step)
            return
        end

        if not info or info.itemID ~= task.itemID then
            self:DebugPrint(("Slot %d:%d no longer holds item %d; skipping step"):format(task.bagID, task.slot, task.itemID))
            idx = idx + 1
            step()
            return
        end

        local liveStack = info.stackCount or 1
        local toMove = math.min(task.take, liveStack)

        if toMove >= liveStack then
            -- Whole-stack move: server-side, no cursor handoff. UseContainerItem
            -- on a warband-bank slot transfers the stack to player bags atomically.
            self:DebugPrint(("Auto-move full stack of %d (item %d) from %d:%d"):format(toMove, task.itemID, task.bagID, task.slot))
            C_Container.UseContainerItem(task.bagID, task.slot)
            idx = idx + 1
            C_Timer.After(STEP_GAP, step)
            return
        end

        self:DebugPrint(("Splitting %d of %d (item %d) from %d:%d"):format(toMove, liveStack, task.itemID, task.bagID, task.slot))
        ClearCursor()
        C_Container.SplitContainerItem(task.bagID, task.slot, toMove)

        AwaitCursorItem(
            function()
                local destBag, destSlot = self:FindEmptyBagSlot(claimedSlots)
                if destBag and destSlot then
                    self:DebugPrint(("Placing into %d:%d"):format(destBag, destSlot))
                    C_Container.PickupContainerItem(destBag, destSlot)
                else
                    self:DebugPrint("No empty bag slot reserved; falling back to PutItemInBackpack")
                    PutItemInBackpack()
                end
                idx = idx + 1
                C_Timer.After(STEP_GAP, step)
            end,
            function()
                self:DebugPrint(("Cursor never received split from %d:%d; skipping step"):format(task.bagID, task.slot))
                ClearCursor()
                idx = idx + 1
                C_Timer.After(STEP_GAP, step)
            end
        )
    end

    step()
end

-- Public single-item withdraw used by the /wbwithdraw slash command. Wraps
-- the same plan/run pipeline as the bulk path so behaviour is identical.
function WarbandStorage:WithdrawItemFromWarbank(itemID, needed)
    needed = needed or 1
    self:DebugPrint(("Manual withdraw: %d of item %d"):format(needed, itemID))
    local plan = PlanWithdrawals(self, { itemID }, { [itemID] = (C_Item.GetItemCount(itemID, false) or 0) + needed })
    self:DebugPrint(("Planned %d step(s) for manual withdraw"):format(#plan))
    self:RunWithdrawPlan(plan, nil)
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
        local freeSlots = C_Container.GetContainerFreeSlots(bankBag)
        if freeSlots and #freeSlots > 0 then
            return bankBag, freeSlots[1]
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
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc) then
                    table.insert(bagSlots, { bag = bag, slot = slot, count = info.stackCount })
                else
                    self:DebugPrint(("Item %d at %d:%d not allowed in Account bank; skipping"):format(itemID, bag, slot))
                end
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

            if lockInfo == true then
                self:DebugPrint(("Skipping locked item at %d:%d"):format(bag, slot))
                depositNext(index + 1, remaining)
                return
            end

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
