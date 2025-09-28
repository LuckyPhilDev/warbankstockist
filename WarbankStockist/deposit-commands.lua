-- Warband Stockist — Item Deposit Command
-- Slash command to deposit items into the warband bank

-- Create a namespace for the command system
WarbandStockist_Commands = WarbandStockist_Commands or {}

-- ############################################################
-- ## Warband Bank API Functions
-- ############################################################

-- Check if warband bank is available and accessible
local function IsWarbandBankAvailable()
    -- Method 1: Check for standard UI frames
    local bankOpen = false
    
    -- Check standard bank frame
    if BankFrame and BankFrame:IsVisible() then
        bankOpen = true
    end
    
    -- Check for warband-specific frames (multiple possible names)
    local warbandFrames = {
        "AccountBankPanel",
        "WarbandBankFrame", 
        "BankFrameTab2",  -- Warband tab
        "BankFrameTab3"   -- Alternative warband tab
    }
    
    for _, frameName in ipairs(warbandFrames) do
        local frame = _G[frameName]
        if frame and frame:IsVisible() then
            bankOpen = true
            break
        end
    end
    
    -- Method 2: Check if warband containers are accessible (more reliable)
    -- Based on debug results, container 12 seems to be the warband bank
    if not bankOpen then
        local testContainers = {12, -3, -4, -5, -6, -7}
        for _, containerID in ipairs(testContainers) do
            local numSlots = C_Container.GetContainerNumSlots(containerID)
            if numSlots and numSlots > 0 then
                bankOpen = true
                break
            end
        end
    end
    
    -- Check via API methods
    if C_Bank then
        if C_Bank.IsAtBank and C_Bank.IsAtBank() then
            bankOpen = true
        end
    end
    
    return bankOpen
end

-- Find item in player bags by item ID
local function FindItemInBags(itemID)
    for bagID = 0, 4 do  -- Bags 0-4 (backpack + 4 bags)
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        for slotIndex = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
            if itemInfo and itemInfo.itemID == itemID then
                return bagID, slotIndex, itemInfo.stackCount
            end
        end
    end
    return nil, nil, 0
end

-- Find available slot in warband bank for deposit
-- First looks for existing stacks of the same item, then empty slots
local function FindWarbandBankSlot(targetItemID)
    -- Based on debug results, prioritize the containers that actually work
    local possibleContainers = {
        12,  -- From debug: this had 98 slots and worked
        11, 13, 14, 15, 16,  -- Adjacent containers
        -3, -4, -5, -6, -7   -- Negative container IDs for bank
    }
    
    -- Also try Enum-based containers if available
    if Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 then
        for i = 0, 4 do
            table.insert(possibleContainers, 1, Enum.BagIndex.AccountBankTab_1 + i)
        end
    end
    
    local emptySlot = nil
    local emptySlotContainer = nil
    
    -- Check each possible container
    for _, containerID in ipairs(possibleContainers) do
        local numSlots = C_Container.GetContainerNumSlots(containerID)
        
        if numSlots and numSlots > 0 then
            for slotIndex = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(containerID, slotIndex)
                
                if itemInfo and itemInfo.itemID then
                    -- Check if this slot contains the same item and can stack more
                    if itemInfo.itemID == targetItemID then
                        -- Get max stack size for this item
                        local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount = C_Item.GetItemInfo(targetItemID)
                        if itemStackCount and itemInfo.stackCount < itemStackCount then
                            -- Found existing stack with room for more
                            return containerID, slotIndex
                        end
                    end
                elseif not emptySlot then
                    -- Remember first empty slot we find
                    emptySlot = slotIndex
                    emptySlotContainer = containerID
                end
            end
        end
    end
    
    -- Return empty slot if no stackable slot was found
    return emptySlotContainer, emptySlot
end

-- Deposit item into warband bank
local function DepositItemToWarbandBank(bagID, slotIndex, quantity)
    quantity = quantity or 1
    
    if not IsWarbandBankAvailable() then
        print("|cffff0000Error:|r Warband bank is not available. You must be at a warband bank to use this command.")
        return false
    end
    
    -- Get item info to check stack count
    local containerItemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
    if not containerItemInfo or not containerItemInfo.itemID then
        print("|cffff0000Error:|r No item found in the specified bag slot.")
        return false
    end
    
    local itemID = containerItemInfo.itemID
    
    -- Split off exactly the quantity we want (default 1)
    if containerItemInfo.stackCount and containerItemInfo.stackCount > quantity then
        C_Container.SplitContainerItem(bagID, slotIndex, quantity)
    else
        -- If we want the whole stack or there's only 1, just pick it up normally
        C_Container.PickupContainerItem(bagID, slotIndex)
    end
    
    -- Check if we successfully picked up the item
    local cursorType = GetCursorInfo()
    if cursorType ~= "item" then
        print("|cffff0000Error:|r Failed to pick up item from bag.")
        return false
    end
    
    -- Find available warband bank slot (prioritize existing stacks)
    local bankTab, bankSlot = FindWarbandBankSlot(itemID)
    if not bankTab or not bankSlot then
        -- Put item back if no space
        C_Container.PickupContainerItem(bagID, slotIndex)
        print("|cffff0000Error:|r No available space in warband bank.")
        return false
    end
    
    -- Place item in warband bank slot
    C_Container.PickupContainerItem(bankTab, bankSlot)
    
    return true
end

-- ############################################################
-- ## Command Handler
-- ############################################################

-- Main deposit command function
local function HandleDepositCommand(args)
    local itemID = tonumber(args)
    
    if not itemID then
        print("|cff7fd5ff[Warband Stockist]|r Usage: /wbdeposit <itemID>")
        print("|cff7fd5ff[Warband Stockist]|r Example: /wbdeposit 6948")
        return
    end
    
    -- Find the item in player bags
    local bagID, slotIndex, stackCount = FindItemInBags(itemID)
    
    if not bagID then
        local itemName = C_Item.GetItemNameByID(itemID)
        print("|cffff0000Error:|r Item " .. (itemName or ("ID: " .. itemID)) .. " not found in your bags.")
        return
    end
    
    if stackCount < 1 then
        print("|cffff0000Error:|r No items available to deposit.")
        return
    end
    
    -- Get item name for confirmation
    local itemName = C_Item.GetItemNameByID(itemID) or ("Item ID: " .. itemID)
    
    -- Attempt to deposit the item
    local success = DepositItemToWarbandBank(bagID, slotIndex, 1)
    
    if success then
        print("|cff00ff00Success:|r Deposited 1x " .. itemName .. " into warband bank.")
    else
        print("|cffff0000Error:|r Failed to deposit " .. itemName .. " into warband bank.")
    end
end

-- ############################################################
-- ## Slash Command Registration
-- ############################################################

-- Register the slash command
SLASH_WBDEPOSIT1 = "/wbdeposit"
SLASH_WBDEPOSIT2 = "/warbanddeposit"

SlashCmdList["WBDEPOSIT"] = function(msg)
    HandleDepositCommand(msg)
end

-- ############################################################
-- ## Alternative API Approach (Fallback)
-- ############################################################

-- Alternative method using direct bank API if the above doesn't work  
local function DepositItemAlternative(itemID)
    -- This uses a more direct approach with bank containers
    local bagID, slotIndex = FindItemInBags(itemID)
    
    if not bagID or not slotIndex then
        return false, "Item not found in bags"
    end
    
    -- Use SplitContainerItem to split 1 item if it's a stack
    C_Container.SplitContainerItem(bagID, slotIndex, 1)
    
    -- This would need the proper warband bank container ID
    -- The exact API may vary - this is a framework for the approach
    local warbandBankBag = -1  -- Placeholder - need actual warband bank bag ID
    
    -- Find empty slot in warband bank
    for slot = 1, 28 do  -- Standard bank slots
        local itemInfo = C_Container.GetContainerItemInfo(warbandBankBag, slot)
        if not itemInfo then
            -- Found empty slot, place item here
            C_Container.PickupContainerItem(warbandBankBag, slot)
            return true, "Success"
        end
    end
    
    return false, "No space in warband bank"
end

-- ############################################################
-- ## Withdraw Functions
-- ############################################################

-- Find item in warband bank and return slot to withdraw from
local function FindWarbandBankItem(targetItemID)
    local possibleContainers = {
        12,  -- From debug: this had 98 slots and worked
        11, 13, 14, 15, 16,  -- Adjacent containers
        -3, -4, -5, -6, -7   -- Negative container IDs for bank
    }
    
    -- Also try Enum-based containers if available
    if Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 then
        for i = 0, 4 do
            table.insert(possibleContainers, 1, Enum.BagIndex.AccountBankTab_1 + i)
        end
    end
    
    -- Check each possible container for the item
    for _, containerID in ipairs(possibleContainers) do
        local numSlots = C_Container.GetContainerNumSlots(containerID)
        
        if numSlots and numSlots > 0 then
            for slotIndex = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(containerID, slotIndex)
                
                if itemInfo and itemInfo.itemID == targetItemID then
                    -- Found the item
                    return containerID, slotIndex
                end
            end
        end
    end
    
    return nil, nil
end

-- Find bag slot to place withdrawn item (prioritize existing stacks)
local function FindBagSlotForItem(targetItemID)
    -- Helper: get max stack for the specific bag slot (more reliable than item info cache)
    local function getSlotMaxStack(bagID, slotIndex)
        if ItemLocation and ItemLocation.CreateFromBagAndSlot then
            local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
            if loc and C_Item.DoesItemExist(loc) then
                local m = C_Item.GetItemMaxStackSize(loc)
                if m and m > 0 then return m end
            end
        end
        -- Fallback to item info
        return select(8, C_Item.GetItemInfo(targetItemID))
    end

    -- First pass: look across ALL bags for an existing stack we can merge into
    for bagID = 0, 4 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots and numSlots > 0 then
            for slotIndex = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
                if itemInfo and itemInfo.itemID == targetItemID then
                    local maxStackSize = getSlotMaxStack(bagID, slotIndex)
                    if maxStackSize and (itemInfo.stackCount or 0) < maxStackSize then
                        return bagID, slotIndex
                    end
                end
            end
        end
    end

    -- Second pass: choose the first available empty slot across bags
    for bagID = 0, 4 do
        local freeSlots = C_Container.GetContainerFreeSlots(bagID)
        if freeSlots and #freeSlots > 0 then
            return bagID, freeSlots[1]
        end
    end

    return nil, nil
end

-- Withdraw item from warband bank to bags
local function WithdrawItemFromWarbandBank(itemID, quantity)
    quantity = quantity or 1
    
    if not IsWarbandBankAvailable() then
        print("|cffff0000Error:|r Warband bank is not available. You must be at a warband bank to use this command.")
        return false
    end
    
    -- Find the item in warband bank
    local bankBag, bankSlot = FindWarbandBankItem(itemID)
    if not bankBag or not bankSlot then
        print("|cffff0000Error:|r Item not found in warband bank.")
        return false
    end
    
    -- Get item info to check stack count
    local bankItemInfo = C_Container.GetContainerItemInfo(bankBag, bankSlot)
    if not bankItemInfo or not bankItemInfo.itemID then
        print("|cffff0000Error:|r No item found in warband bank slot.")
        return false
    end
    
    -- Find where to place the item in bags
    local targetBag, targetSlot = FindBagSlotForItem(itemID)
    if not targetBag or not targetSlot then
        print("|cffff0000Error:|r No available space in bags for this item.")
        return false
    end
    
    -- Ensure we don't already have something on the cursor
    ClearCursor()

    -- Split off exactly the quantity we want (default 1)
    if bankItemInfo.stackCount and bankItemInfo.stackCount > quantity then
        C_Container.SplitContainerItem(bankBag, bankSlot, quantity)
    else
        -- If we want the whole stack or there's only 1, just pick it up normally
        C_Container.PickupContainerItem(bankBag, bankSlot)
    end
    
    -- Check if we successfully picked up the item
    local cursorType = GetCursorInfo()
    if cursorType ~= "item" then
        print("|cffff0000Error:|r Failed to pick up item from warband bank.")
        return false
    end
    
    -- Place item in bag (tiny delay helps ensure merges rather than swaps)
    C_Timer.After(0.05, function()
        C_Container.PickupContainerItem(targetBag, targetSlot)
    end)
    
    return true
end

-- ############################################################
-- ## Withdraw Command Handler
-- ############################################################

local function HandleWithdrawCommand(msg)
    local itemID = tonumber(msg)
    
    if not itemID then
        -- Try to extract item ID from item link
        local itemString = msg:match("item:(%d+)")
        if itemString then
            itemID = tonumber(itemString)
        end
    end
    
    if not itemID then
        print("|cffff0000Error:|r Please provide a valid item ID or item link.")
        print("|cffccccccUsage:|r /wbwithdraw <itemID> or /wbwithdraw [item link]")
        return
    end
    
    -- Validate that the item exists
    local itemInfo = C_Item.GetItemInfoInstant(itemID)
    if not itemInfo then
        print("|cffff0000Error:|r Invalid item ID: " .. tostring(itemID))
        return
    end
    
    -- Attempt to withdraw the item
    local success = WithdrawItemFromWarbandBank(itemID, 1)
    if success then
        print("|cff00ff00Success:|r Withdrew " .. (itemInfo or "item") .. " from warband bank.")
    end
end

-- Register withdraw slash commands
SLASH_WBWITHDRAW1 = "/wbwithdraw"
SLASH_WBWITHDRAW2 = "/warbandwithdraw"
SlashCmdList["WBWITHDRAW"] = HandleWithdrawCommand

-- ############################################################
-- ## Help Command
-- ############################################################

-- Add help information
SLASH_WBHELP1 = "/wbhelp"
SlashCmdList["WBHELP"] = function()
    print("|cff7fd5ff[Warband Stockist] Available Commands:|r")
    print("|cff00ff00/wbdeposit <itemID>|r - Deposit 1 of the specified item into warband bank")
    print("|cff00ff00/warbanddeposit <itemID>|r - Same as above")
    print("|cff00ff00/wbwithdraw <itemID>|r - Withdraw 1 of the specified item from warband bank")
    print("|cff00ff00/warbandwithdraw <itemID>|r - Same as above")
    print("|cff00ff00/wbhelp|r - Show this help message")
    print("|cffccccccNote:|r You must be at a warband bank to use these commands.")
end

-- Print load message
print("|cff7fd5ff[Warband Stockist]|r Deposit commands loaded. Type /wbhelp for usage.")
