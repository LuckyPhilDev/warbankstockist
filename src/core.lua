-- Ensure shared namespace exists
WarbandStorage = WarbandStorage or {}

local S = WarbandStorage.Strings
local PREFIX = S.addon.prefix

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
        }

        WarbandStorage.inventory = {}

        WarbandStorage:DebugPrint("Loaded saved variables.")
        
        -- Store current character's class for proper coloring
        if WarbandStorage.Utils and WarbandStorage.Utils.StoreCharacterClass then
            WarbandStorage.Utils:StoreCharacterClass()
        end
        
        -- Warbound auto-deposit settings (missing on saves from before the feature)
        WarbandStockistDB.warboundDeposit = WarbandStockistDB.warboundDeposit or {}

        -- Ensure reserved default profile exists
        do
            WarbandStockistDB.profiles = WarbandStockistDB.profiles or {}
            local reserved = (WarbandStockistDB and WarbandStockistDB.defaultProfile) or "Default"
            WarbandStockistDB.profiles[reserved] = WarbandStockistDB.profiles[reserved] or { items = {} }
        end

        -- Auto-assign default profile to new characters (first-seen) while preserving Unassigned if user sets it
        do
            WarbandStockistDB.assignments = WarbandStockistDB.assignments or {}
            WarbandStockistDB._seenCharacters = WarbandStockistDB._seenCharacters or {}
            local charKey = WarbandStorage.Utils:GetCharacterKey()
            local reserved = (WarbandStockistDB and WarbandStockistDB.defaultProfile) or "Default"
            if not WarbandStockistDB._seenCharacters[charKey] then
                -- First time we see this character in SavedVariables for this account
                if WarbandStockistDB.assignments[charKey] == nil then
                    -- Assign default profile by default; user can still set Unassigned later
                    WarbandStockistDB.assignments[charKey] = reserved
                    WarbandStorage:DebugPrint("Assigned default profile to new character: " .. tostring(charKey))
                end
                WarbandStockistDB._seenCharacters[charKey] = true
            end
        end

        WarbandStorage.Settings.Create()

        -- Minimap button
        if WarbandStorage.Minimap then
            WarbandStorage.Minimap:Init(WarbandStockistDB)
            if not WarbandStorage.Minimap.button then
                C_Timer.After(1, function()
                    WarbandStorage.Minimap:Init(WarbandStockistDB)
                end)
            end
        end
        
        WarbandStorage:DebugPrint("WarbandStorage loaded!")
        
        local autoOpenReason
        if WarbandStockistDB.devOpenOnLogin then
            autoOpenReason = "devOpenOnLogin"
        elseif WarbandStorageCharData.autoOpenSettings then
            autoOpenReason = "autoOpenSettings"
        end
        if autoOpenReason then
            C_Timer.After(0.2, function()
                WarbandStorage:DebugPrint("Auto-opening settings on login (" .. autoOpenReason .. ")")
                WarbandStorage:OpenSettings()
            end)
        end

    elseif event == "BANKFRAME_OPENED" then
            WarbandStorage:DebugPrint("Bank Opened")
            -- Slight delay to ensure bank APIs/tab IDs are available
            C_Timer.After(0.2, function()
                -- Log current profile assignment and desired stock size
                local activeProfileName = WarbandStorage.ProfileManager and WarbandStorage.ProfileManager:GetActiveProfileName() or (WarbandStorage.GetActiveProfileName and WarbandStorage:GetActiveProfileName())
                if activeProfileName then
                    WarbandStorage:DebugPrint("Active profile: " .. tostring(activeProfileName))
                else
                    WarbandStorage:DebugPrint("No active profile assigned to this character (unassigned)")
                end
                -- Show how many desired items we think there are
                local desired = WarbandStorage.GetDesiredStock and WarbandStorage:GetDesiredStock() or {}
                local desiredCount = 0
                for _ in pairs(desired) do desiredCount = desiredCount + 1 end
                WarbandStorage:DebugPrint(("Desired stock entries: %d"):format(desiredCount))
                -- Deposit warbound gear first so bag space is free, then
                -- restock from the profile and balance gold.
                WarbandStorage:DepositWarboundItems(function()
                    WarbandStorage:CheckAndWithdrawItemsFromWarbank()
                    WarbandStorage:ManageGoldWithWarbank()
                end)
            end)
    end
end

-- Register PLAYER_LOGIN via dispatcher
WarbandStorage:RegisterEvent("PLAYER_LOGIN")
WarbandStorage:RegisterEvent("BANKFRAME_OPENED")

function WarbandStorage:OpenSettings()
    WarbandStorage.Settings.Create():Open()
end

SLASH_WARBANDSTORAGE1 = "/wbs"
SlashCmdList["WARBANDSTORAGE"] = function(msg)
    msg = type(msg) == "string" and msg:match("^%s*(.-)%s*$") or msg
    if not msg or msg == "" or msg:lower():find("^settings") then
        WarbandStorage:OpenSettings()
        return
    end

    -- /wbs autoopen [on|off|toggle]
    if msg and msg:lower():find("^autoopen") then
        local arg = msg:match("^autoopen%s+(%S+)%s*")
        WarbandStorageCharData = WarbandStorageCharData or {}
        local current = (WarbandStorageCharData.autoOpenSettings == true)
        if arg then arg = arg:lower() end
        if arg == "on" then current = true
        elseif arg == "off" then current = false
        else current = not current end
        WarbandStorageCharData.autoOpenSettings = current
        print(string.format("%s autoOpenSettings: %s", PREFIX, tostring(current)))
        return
    end

    -- Dev helper: /wbs perf [reset]
    if msg and msg:lower():find("^perf") then
        if msg:lower():find("reset") then
            WarbandStorage.Perf:Reset()
            print(PREFIX .. " perf counters reset.")
        else
            WarbandStorage.Perf:Dump("on demand")
        end
        return
    end

    -- Dev helper: /wbs devopen [on|off|toggle]
    if msg and msg:lower():find("^devopen") then
        local arg = msg:match("^devopen%s+(%S+)%s*")
        local current = (WarbandStockistDB and WarbandStockistDB.devOpenOnLogin) and true or false
        if arg then arg = arg:lower() end
        if arg == "on" then current = true
        elseif arg == "off" then current = false
        else current = not current end
        WarbandStockistDB.devOpenOnLogin = current
        print(string.format("%s devOpenOnLogin: %s", PREFIX, tostring(current)))
        return
    end

    -- /wbs report - scan bags and print tracked inventory (previous default behavior)
    if msg:lower():find("^report") then
        local wasEnabled = WarbandStockistDB.debugEnabled
        WarbandStockistDB.debugEnabled = true
        WarbandStorage:DebugPrint("Running /wbs report")

        WarbandStorage:ScanBags()

        C_Timer.After(0.3, function()
            WarbandStorage:PrintTrackedInventory()
            WarbandStorage:ReportMissingItems()
            WarbandStockistDB.debugEnabled = wasEnabled
        end)
        return
    end

    print(PREFIX .. " " .. S.settings.unknownCommand)
end
