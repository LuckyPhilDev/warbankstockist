-- Ensure shared namespace exists
WarbandStorage = WarbandStorage or { debugEnabled = false }

-- Shared Event Dispatcher
WarbandStorage.Events = CreateFrame("Frame")

WarbandStorage.Events:SetScript("OnEvent", function(_, event, ...)
    if WarbandStorage.OnEvent then
        WarbandStorage:OnEvent(event, ...)
    end
end)

function WarbandStorage:RegisterEvent(event)
    self.Events:RegisterEvent(event)
end

-- Shared OnEvent handler
function WarbandStorage:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        -- Saved variables are now safe to access
        WarbandStorageData = WarbandStorageData or { default = {} }
        WarbandStorageCharData = WarbandStorageCharData or {
            useDefault = true, 
            override = {},
            enableExcessDeposit = true,
        }

        WarbandStorage.inventory = {}

        WarbandStorage:DebugPrint("Loaded saved variables.")
        WarbandStorage:DebugPrint("WarbandStorage loaded!")
        
    elseif event == "BANKFRAME_OPENED" then
        WarbandStorage:DebugPrint("Bank Opened")
        WarbandStorage:CheckAndWithdrawItemsFromWarbank()
    end
end

-- Register PLAYER_LOGIN via dispatcher
WarbandStorage:RegisterEvent("PLAYER_LOGIN")
WarbandStorage:RegisterEvent("BANKFRAME_OPENED")

SLASH_WARBANDSTORAGE1 = "/wbs"
SlashCmdList["WARBANDSTORAGE"] = function()
    local wasEnabled = WarbandStorage.debugEnabled
    WarbandStorage.debugEnabled = true
    WarbandStorage:DebugPrint("Running /wbs command")

    WarbandStorage:ScanBags()

    C_Timer.After(0.3, function()
        WarbandStorage:PrintTrackedInventory()
        WarbandStorage:ReportMissingItems()
        WarbandStorage.debugEnabled = wasEnabled
    end)
end
