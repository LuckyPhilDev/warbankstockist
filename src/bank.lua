WarbandStorage = WarbandStorage or {}

local S = WarbandStorage.Strings
local Sets = WarbandStorage.Sets
local StockRules = WarbandStorage.StockRules

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

-- Copies of itemID the Warband Bank will take. Soulbound copies never leave
-- the bags, so counting them would queue a deposit retried on every bank open.
local function DepositableCount(itemID)
    local count = 0
    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID
                and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, ItemLocation:CreateFromBagAndSlot(bag, slot)) then
                count = count + (info.stackCount or 1)
            end
        end
    end
    return count
end

local function CurrentRanges()
    return Sets:RangesFor(WarbandStorage.Utils:GetCharacterKey())
end

local function WarbankCounts()
    local counts = {}
    for _, bagID in ipairs(C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account) or {}) do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) or 0 do
            local info = C_Container.GetContainerItemInfo(bagID, slot)
            if info then counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1) end
        end
    end
    return counts
end

-- amounts = { [itemID] = qtyToTake }. Walks the warband bank for each item in
-- turn and produces a flat list of moves keyed to specific source slots. Each
-- entry pre-commits a stack and amount so the drainer never has to re-scan
-- mid-flight.
local function PlanWithdrawals(self, amounts)
    local tabIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Account)
    if type(tabIDs) ~= "table" or #tabIDs == 0 then
        self:DebugPrint("Warband bank has no purchased tabs to scan.")
        return {}
    end

    local itemIDs = {}
    for itemID, qty in pairs(amounts) do
        if qty > 0 then itemIDs[#itemIDs + 1] = itemID end
    end
    table.sort(itemIDs)

    local plan = {}
    for _, itemID in ipairs(itemIDs) do
        local remaining = amounts[itemID]
        self:DebugPrint(("Item %d: taking %d"):format(itemID, remaining))
        for _, bagID in ipairs(tabIDs) do
            if remaining <= 0 then break end
            local slots = C_Container.GetContainerNumSlots(bagID) or 0
            for slot = 1, slots do
                if remaining <= 0 then break end
                local info = C_Container.GetContainerItemInfo(bagID, slot)
                if info and info.itemID == itemID then
                    local stack = info.stackCount or 1
                    local take = math.min(stack, remaining)
                    plan[#plan + 1] = {
                        itemID = itemID,
                        bagID = bagID,
                        slot = slot,
                        take = take,
                        stackAtPlan = stack,
                    }
                    remaining = remaining - take
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

-- Places whatever item is currently on the cursor into the player's bags.
-- Tries to merge into an existing stack first; if the merge leaves anything
-- on the cursor (target stack filled up), falls back to an empty slot.
-- Bag-side mirror of PlaceCursorIntoBank. Calls onDone once the cursor has
-- been dealt with.
function WarbandStorage:PlaceCursorIntoBags(itemID, claimed, onDone)
    local function finish() if onDone then onDone() end end

    if GetCursorInfo() ~= "item" then
        self:DebugPrint("Cursor empty before bag placement; nothing to place.")
        finish()
        return
    end

    local destBag, destSlot = self:FindStackableBagSlot(itemID)
    if destBag then
        self:DebugPrint(("Merging into existing bag stack at %d:%d"):format(destBag, destSlot))
    else
        destBag, destSlot = self:FindEmptyBagSlot(claimed)
        if destBag then
            self:DebugPrint(("Using empty bag slot %d:%d"):format(destBag, destSlot))
        end
    end

    if not destBag then
        self:DebugPrint("No stackable or empty bag slot; falling back to PutItemInBackpack")
        PutItemInBackpack()
        finish()
        return
    end

    C_Container.PickupContainerItem(destBag, destSlot)
    C_Timer.After(placeDelay, function()
        -- If a stack merge didn't consume the whole cursor, the item is still
        -- held. Drop the remainder into a guaranteed-empty slot instead.
        if GetCursorInfo() == "item" then
            local eBag, eSlot = self:FindEmptyBagSlot(claimed)
            if eBag then
                self:DebugPrint(("Merge left a remainder; placing into empty slot %d:%d"):format(eBag, eSlot))
                C_Container.PickupContainerItem(eBag, eSlot)
                C_Timer.After(placeDelay, function()
                    if GetCursorInfo() == "item" then
                        self:DebugPrint("Item still on cursor after empty-slot placement; falling back to PutItemInBackpack")
                        PutItemInBackpack()
                    end
                    finish()
                end)
                return
            end
            self:DebugPrint("Merge left a remainder but no empty bag slot; falling back to PutItemInBackpack")
            PutItemInBackpack()
        end
        finish()
    end)
end

-- The restock's withdrawals, for RunWithdrawPlan.
function WarbandStorage:PlanRestock()
    local charKey = self.Utils:GetCharacterKey()
    local priority = Sets:IsPriority(charKey)
    local bankCounts = WarbankCounts()
    local amounts = {}
    for itemID, range in pairs(Sets:RangesFor(charKey)) do
        if range.min > 0 then
            amounts[itemID] = StockRules.Withdrawal(range, C_Item.GetItemCount(itemID, false) or 0,
                bankCounts[itemID] or 0, Sets:GetReserve(itemID), priority)
        end
    end

    local plan = PlanWithdrawals(self, amounts)
    self:DebugPrint(("Planned %d withdrawal step(s)"):format(#plan))
    return plan
end

-- Drives plan strictly sequentially. A step never starts until the prior
-- step's cursor work has resolved. Three failure modes are handled
-- distinctly: source slot still locked (retry same step), source slot
-- changed identity since planning (skip), cursor never picked up the split
-- (skip and clear).
function WarbandStorage:RunWithdrawPlan(plan, job)
    local idx = 1
    local claimedSlots = {}

    local function advance()
        idx = idx + 1
        job:Tick()
    end

    local function step()
        if idx > #plan then
            self:DebugPrint("Withdrawal plan finished.")
            job:Done()
            return
        end

        local task = plan[idx]
        local info = C_Container.GetContainerItemInfo(task.bagID, task.slot)

        if info and info.isLocked then
            self:DebugPrint(("Slot %d:%d still locked; re-polling"):format(task.bagID, task.slot))
            job:After(LOCK_REPOLL, step)
            return
        end

        if not info or info.itemID ~= task.itemID then
            self:DebugPrint(("Slot %d:%d no longer holds item %d; skipping step"):format(task.bagID, task.slot, task.itemID))
            advance()
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
            advance()
            job:After(STEP_GAP, step)
            return
        end

        self:DebugPrint(("Splitting %d of %d (item %d) from %d:%d"):format(toMove, liveStack, task.itemID, task.bagID, task.slot))
        ClearCursor()
        C_Container.SplitContainerItem(task.bagID, task.slot, toMove)

        AwaitCursorItem(
            function()
                self:PlaceCursorIntoBags(task.itemID, claimedSlots, function()
                    advance()
                    job:After(STEP_GAP, step)
                end)
            end,
            function()
                self:DebugPrint(("Cursor never received split from %d:%d; skipping step"):format(task.bagID, task.slot))
                ClearCursor()
                advance()
                job:After(STEP_GAP, step)
            end
        )
    end

    step()
end

-- Public single-item withdraw used by the /wbwithdraw slash command. Wraps
-- the same plan/run pipeline as the bulk path so behaviour is identical, except
-- that an explicit request ignores reserves.
function WarbandStorage:WithdrawItemFromWarbank(itemID, needed)
    needed = needed or 1
    LuckyBankRun:Queue({
        direction = "withdraw",
        plan = function()
            self:DebugPrint(("Manual withdraw: %d of item %d"):format(needed, itemID))
            return PlanWithdrawals(self, { [itemID] = needed })
        end,
        run = function(job, plan) self:RunWithdrawPlan(plan, job) end,
    })
end

-- The excess deposits, for ProcessDepositQueue.
function WarbandStorage:PlanExcessDeposits()
    self:ScanBags()
    local ranges = CurrentRanges()

    local itemIDs = {}
    for itemID, range in pairs(ranges) do
        if range.max < math.huge then itemIDs[#itemIDs + 1] = itemID end
    end
    table.sort(itemIDs)

    local depositQueue = {}
    for _, itemID in ipairs(itemIDs) do
        local have = self.inventory[itemID] or 0
        local excess = StockRules.Deposit(ranges[itemID], have)
        if excess > 0 then excess = math.min(excess, DepositableCount(itemID)) end
        if excess > 0 then
            self:DebugPrint(("Excess found: item %d x%d (have %d, keep %d)"):format(itemID, excess, have, ranges[itemID].max))
            depositQueue[#depositQueue + 1] = { itemID = itemID, amount = excess }
        end
    end
    return depositQueue
end

function WarbandStorage:ProcessDepositQueue(queue, index, job)
    if index > #queue then
        self:DebugPrint("Finished all excess deposits.")
        job:Done()
        return
    end

    local entry = queue[index]
    self:TryDepositItem(entry.itemID, entry.amount, function()
        job:Tick()
        job:After(perItemDelay, function()
            self:ProcessDepositQueue(queue, index + 1, job)
        end)
    end)
end

-- Mirrors the in-game "Clean Up Warband Bank" button. A short delay lets the
-- final placement settle before the sort reshuffles.
function WarbandStorage:SortWarbankAfterDeposit()
    if not WarbandStockistDB.sortAfterDeposit then return end
    if not C_Bank.CanViewBank(Enum.BankType.Account) then
        self:DebugPrint("Sort-after-deposit: Warband Bank not available; skipping sort.")
        return
    end
    C_Timer.After(perItemDelay, function()
        self:DebugPrint("Sort-after-deposit: sorting Warband Bank.")
        C_Container.SortAccountBankBags()
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

-- Places whatever item is currently on the cursor into the Account bank.
-- Tries to merge into an existing stack first; if the merge leaves anything
-- on the cursor (merge failed or only partially filled), falls back to an
-- empty slot. Calls onDone once the cursor has been dealt with.
function WarbandStorage:PlaceCursorIntoBank(itemID, onDone)
    local function finish() if onDone then onDone() end end

    if GetCursorInfo() ~= "item" then
        self:DebugPrint("Cursor empty before bank placement; nothing to deposit.")
        finish()
        return
    end

    local destBag, destSlot = self:FindStackableBankSlot(itemID)
    if destBag then
        self:DebugPrint(("Merging into existing stack at %d:%d"):format(destBag, destSlot))
    else
        destBag, destSlot = self:FindEmptyBankSlot()
        if destBag then
            self:DebugPrint(("Using empty bank slot %d:%d"):format(destBag, destSlot))
        end
    end

    if not destBag then
        self:DebugPrint("No bank slot available for deposit; returning item to bags.")
        ClearCursor()
        finish()
        return
    end

    C_Container.PickupContainerItem(destBag, destSlot)
    C_Timer.After(placeDelay, function()
        -- If a stack merge didn't consume the whole cursor, the item is still
        -- held. Drop the remainder into a guaranteed-empty slot instead.
        if GetCursorInfo() == "item" then
            local eBag, eSlot = self:FindEmptyBankSlot()
            if eBag then
                self:DebugPrint(("Merge left a remainder; placing into empty slot %d:%d"):format(eBag, eSlot))
                C_Container.PickupContainerItem(eBag, eSlot)
                C_Timer.After(placeDelay, function()
                    if GetCursorInfo() == "item" then
                        self:DebugPrint("Item still on cursor after empty-slot placement; returning to bags.")
                        ClearCursor()
                    end
                    finish()
                end)
                return
            end
            self:DebugPrint("Merge left a remainder but no empty slot; returning to bags.")
            ClearCursor()
        end
        finish()
    end)
end

-- slotFilter(bag, slot, info) may veto individual stacks; without it every
-- bank-allowed stack of the itemID is a deposit candidate.
function WarbandStorage:TryDepositItem(itemID, amountToDeposit, callback, slotFilter)
    local bagSlots = {}

    -- Collect all bag slots containing the item to deposit
    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc)
                    and (not slotFilter or slotFilter(bag, slot, info)) then
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

                    self:PlaceCursorIntoBank(itemID, function()
                        C_Timer.After(perItemDelay, function()
                            depositNext(index + 1, remaining - toMove)
                        end)
                    end)
                end)
            else
                self:DebugPrint("Picking up full stack")
                C_Container.PickupContainerItem(bag, slot)
                C_Timer.After(depositDelay, function()
                    self:PlaceCursorIntoBank(itemID, function()
                        C_Timer.After(perItemDelay, function()
                            depositNext(index + 1, remaining - toMove)
                        end)
                    end)
                end)
            end
        end)
    end

    depositNext(1, amountToDeposit)
end

-- ############################################################
-- ## Warbound Auto-Deposit — bank-open pass that moves warbound
-- ## armor, weapons, and tokens into the bank before restocking
-- ############################################################

-- An item instance only counts as warbound if it is already bound to the
-- account or is "Warbound until Equipped". Unbound BoE copies are neither,
-- even though the bank would accept them.
local function IsInstanceWarbound(bag, slot, info)
    if info.isBound then return true end
    return C_Item.IsBoundToAccountUntilEquip(ItemLocation:CreateFromBagAndSlot(bag, slot))
end

local function PlanWarboundQueue(self, cfg)
    -- Items a set keeps in bags must not be deposited here; the withdraw pass
    -- that follows would just pull them straight back.
    local ranges = CurrentRanges()

    local toDeposit = {}
    for _, bag in ipairs(GetAllPlayerBagIDs()) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not toDeposit[info.itemID]
                and not (ranges[info.itemID] and ranges[info.itemID].min > 0) then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                -- IsItemAllowedInBankType only means "not soulbound": grey junk
                -- and unbound BoE copies pass it, so the quality and warbound
                -- checks below keep them out of the deposit.
                local _, _, quality, _, _, _, _, _, _, _, _, classID, subclassID = C_Item.GetItemInfo(info.itemID)
                if quality and quality > Enum.ItemQuality.Poor
                    and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, loc)
                    and IsInstanceWarbound(bag, slot, info) then
                    if (cfg.armor and classID == 4)
                        or (cfg.weapons and classID == 2)
                        or (cfg.tokens and classID == 15 and subclassID == 0) then
                        toDeposit[info.itemID] = true
                        self:DebugPrint(("Warbound deposit: queueing item %d"):format(info.itemID))
                    end
                end
            end
        end
    end

    -- Counts may overcount non-warbound copies; the deposit loop's slot filter
    -- simply runs out of eligible stacks.
    local queue = {}
    for itemID in pairs(toDeposit) do
        local count = C_Item.GetItemCount(itemID, false) or 0
        if count > 0 then
            queue[#queue + 1] = { itemID = itemID, amount = count }
        end
    end
    return queue
end

local function RunWarboundQueue(self, queue, index, job)
    if index > #queue then
        job:Done()
        return
    end
    if not C_Bank.CanViewBank(Enum.BankType.Account) then
        self:DebugPrint("Warbound deposit: bank closed mid-run; stopping.")
        return
    end
    local entry = queue[index]
    self:TryDepositItem(entry.itemID, entry.amount, function()
        job:Tick()
        job:After(perItemDelay, function()
            RunWarboundQueue(self, queue, index + 1, job)
        end)
    end, IsInstanceWarbound)
end

-- The warbound gear deposits, for DepositWarboundItems. Runs before the
-- restock on bank open.
function WarbandStorage:PlanWarboundDeposits()
    local cfg = WarbandStockistDB.warboundDeposit or {}
    if not (cfg.enabled and (cfg.armor or cfg.weapons or cfg.tokens)) then return {} end
    local queue = PlanWarboundQueue(self, cfg)
    self:DebugPrint(("Warbound deposit: %d item type(s) queued"):format(#queue))
    return queue
end

-- Also the feature marker Lucky's Grab-bag checks to hand its own warbound gear
-- deposit over to this addon, so renaming it needs a matching change there.
function WarbandStorage:DepositWarboundItems(job, queue)
    RunWarboundQueue(self, queue, 1, job)
end

-- ############################################################
-- ## Gold Management — deposit/withdraw to hit a target
-- ############################################################

--- Resolves the gold target (whole gold pieces) for the current character.
--- Priority: per-character override > level bracket > nil (disabled).
local function ResolveGoldTarget()
    local gm = WarbandStockistDB and WarbandStockistDB.goldManagement
    if not gm then return nil end

    -- Ensure sub-tables exist (handles saves from before feature existed)
    gm.brackets  = gm.brackets  or {}
    gm.overrides = gm.overrides or {}

    -- Build the current character key the same way the rest of the addon does
    local name, realm = UnitFullName("player")
    local charKey = string.format("%s-%s",
        name  or UnitName("player") or "",
        realm or GetRealmName()     or "")

    -- 1. Per-character override takes priority
    local override = gm.overrides[charKey]
    if override ~= nil then
        return tonumber(override) or 0
    end

    -- 2. Find the first bracket that covers the player's level
    local level = UnitLevel("player") or 0
    for _, bracket in ipairs(gm.brackets) do
        local lo = tonumber(bracket.minLevel) or 0
        local hi = tonumber(bracket.maxLevel) or 0
        if level >= lo and level <= hi then
            return tonumber(bracket.gold) or 0
        end
    end

    -- 3. Nothing matched → feature disabled for this character
    return nil
end

--- Adjusts the current character's gold against the Warband Bank so that the
--- player holds exactly the resolved target gold (in whole gold pieces).
---
--- * Override > bracket > disabled (no match).
--- * Excess gold is deposited; shortfall is withdrawn.
--- * The warband-bank cap (9,999,999g 99s 99c) is respected on deposits.
function WarbandStorage:ManageGoldWithWarbank()
    local targetGold = ResolveGoldTarget()
    if targetGold == nil then
        self:DebugPrint("Gold management: no bracket or override matches this character.")
        return
    end
    if targetGold <= 0 then
        self:DebugPrint("Gold management: target is 0, skipping.")
        return
    end

    if not C_Bank.CanDepositMoney(Enum.BankType.Account) then
        self:DebugPrint("Cannot access Warband Bank for gold management.")
        return
    end

    local targetCopper  = targetGold * 10000
    local currentCopper = GetMoney()
    local wbCopper      = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or 0
    local WB_CAP        = 999999990000  -- 9,999,999g 99s 90c

    self:DebugPrint(string.format(
        "Gold management: have %dg, target %dg, warbank has %dg",
        math.floor(currentCopper / 10000),
        targetGold,
        math.floor(wbCopper / 10000)
    ))

    local diff = currentCopper - targetCopper

    if diff > 0 then
        -- Player has more than target → deposit the excess
        if wbCopper >= WB_CAP then
            self:DebugPrint("Warband bank is at gold cap; skipping deposit.")
            return
        end
        local toDeposit = diff
        if wbCopper + toDeposit > WB_CAP then
            toDeposit = WB_CAP - wbCopper
        end
        if toDeposit > 0 then
            C_Bank.DepositMoney(Enum.BankType.Account, toDeposit)
            print(string.format(
                S.addon.prefix .. " " .. S.gold.deposited,
                math.floor(toDeposit / 10000),
                math.floor((toDeposit % 10000) / 100),
                toDeposit % 100
            ))
        end
    elseif diff < 0 then
        -- Player has less than target → withdraw the shortfall
        local toWithdraw = math.abs(diff)
        if wbCopper == 0 then
            self:DebugPrint("Warband bank has no gold to withdraw.")
            return
        end
        if toWithdraw > wbCopper then
            toWithdraw = wbCopper
        end
        if toWithdraw > 0 then
            C_Bank.WithdrawMoney(Enum.BankType.Account, toWithdraw)
            print(string.format(
                S.addon.prefix .. " " .. S.gold.withdrew,
                math.floor(toWithdraw / 10000),
                math.floor((toWithdraw % 10000) / 100),
                toWithdraw % 100
            ))
        end
    else
        self:DebugPrint("Gold is already at target; no gold movement needed.")
    end
end

