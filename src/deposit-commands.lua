-- Warband Stockist — Item Deposit/Withdraw Commands
-- Slash commands to manually deposit or withdraw individual items to/from the warband bank.
-- All move logic is delegated to WarbandStorage methods in bank.lua.

WarbandStockist_Commands = WarbandStockist_Commands or {}

local S = WarbandStorage.Strings
local PREFIX = S.addon.prefix
local C = S.commands

-- ############################################################
-- ## Deposit Command Handler
-- ############################################################

local function HandleDepositCommand(args)
    local itemID = tonumber(args)

    if not itemID then
        print(PREFIX .. " " .. C.depositUsage)
        print(PREFIX .. " " .. C.depositExample)
        return
    end

    if not C_Bank.CanViewBank(Enum.BankType.Account) then
        print(S.addon.errorPrefix .. " " .. C.bankUnavailable)
        return
    end

    local itemName = C_Item.GetItemNameByID(itemID) or C.itemIdFallback:format(itemID)
    WarbandStorage:TryDepositItem(itemID, 1, function()
        print(S.addon.successPrefix .. " " .. C.depositSuccess:format(itemName))
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
        print(S.addon.errorPrefix .. " " .. C.withdrawInvalid)
        print(C.withdrawUsage)
        return
    end

    if not C_Bank.CanViewBank(Enum.BankType.Account) then
        print(S.addon.errorPrefix .. " " .. C.bankUnavailable)
        return
    end

    if not C_Item.GetItemInfoInstant(itemID) then
        print(S.addon.errorPrefix .. " " .. C.invalidItemId:format(tostring(itemID)))
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
    print(C.helpTitle)
    print(C.helpDeposit)
    print(C.helpDepositAlias)
    print(C.helpWithdraw)
    print(C.helpWithdrawAlias)
    print(C.helpHelp)
    print(C.helpNote)
end

-- Print load message
print(PREFIX .. " " .. C.loaded)
