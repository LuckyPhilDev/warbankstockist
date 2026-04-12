-- Warband Stockist — Item Deposit/Withdraw Commands
-- Slash commands to manually deposit or withdraw individual items to/from the warband bank.
-- All move logic is delegated to WarbandStorage methods in bank.lua.

WarbandStockist_Commands = WarbandStockist_Commands or {}

-- ############################################################
-- ## Deposit Command Handler
-- ############################################################

local function HandleDepositCommand(args)
    local itemID = tonumber(args)

    if not itemID then
        print("|cff7fd5ff[Warband Stockist]|r Usage: /wbdeposit <itemID>")
        print("|cff7fd5ff[Warband Stockist]|r Example: /wbdeposit 6948")
        return
    end

    if not C_Bank.CanViewBank(Enum.BankType.Account) then
        print("|cffff0000Error:|r Warband bank is not available. You must be at a warband bank to use this command.")
        return
    end

    local itemName = C_Item.GetItemNameByID(itemID) or ("Item ID: " .. itemID)
    WarbandStorage:TryDepositItem(itemID, 1, function()
        print("|cff00ff00Success:|r Deposited 1x " .. itemName .. " into warband bank.")
    end)
end

-- ############################################################
-- ## Slash Command Registration — Deposit
-- ############################################################

SLASH_WBDEPOSIT1 = "/wbdeposit"
SLASH_WBDEPOSIT2 = "/warbanddeposit"

SlashCmdList["WBDEPOSIT"] = function(msg)
    HandleDepositCommand(msg)
end

-- ############################################################
-- ## Withdraw Command Handler
-- ############################################################

local function HandleWithdrawCommand(msg)
    local itemID = tonumber(msg)

    if not itemID then
        local itemString = msg:match("item:(%d+)")
        if itemString then itemID = tonumber(itemString) end
    end

    if not itemID then
        print("|cffff0000Error:|r Please provide a valid item ID or item link.")
        print("|cffccccccUsage:|r /wbwithdraw <itemID> or /wbwithdraw [item link]")
        return
    end

    if not C_Bank.CanViewBank(Enum.BankType.Account) then
        print("|cffff0000Error:|r Warband bank is not available. You must be at a warband bank to use this command.")
        return
    end

    if not C_Item.GetItemInfoInstant(itemID) then
        print("|cffff0000Error:|r Invalid item ID: " .. tostring(itemID))
        return
    end

    WarbandStorage:WithdrawItemFromWarbank(itemID, 1)
end

-- ############################################################
-- ## Slash Command Registration — Withdraw
-- ############################################################

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
