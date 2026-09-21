local ADDON_NAME = ...

WarbandStorage = WarbandStorage or {}

local S = WarbandStorage.Strings
local PREFIX = S.addon.prefix

WarbandStorage.Events = CreateFrame("Frame")

WarbandStorage.Events:SetScript("OnEvent", function(_, event, ...)
    if WarbandStorage.OnEvent then
        WarbandStorage:OnEvent(event, ...)
    end
end)

function WarbandStorage:RegisterEvent(event)
    self.Events:RegisterEvent(event)
end

function WarbandStorage:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        self.Events:UnregisterEvent("ADDON_LOADED")
        -- Here rather than at PLAYER_LOGIN so the upgrade has finished before
        -- another addon's PLAYER_LOGIN handler calls into this one.
        WarbandStockistDB = WarbandStockistDB or {}
        WarbandStorage.Migration.Upgrade(WarbandStockistDB)

    elseif event == "PLAYER_LOGIN" then
        WarbandStorageCharData = WarbandStorageCharData or {}
        WarbandStorage.inventory = {}

        WarbandStorage.Utils:StoreCharacterClass()
        WarbandStorage.Migration.Login(WarbandStockistDB, WarbandStorage.Utils:GetCharacterKey(),
            WarbandStorageData, WarbandStorageCharData)

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

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if isLogin or isReload then
            -- ponytail: bag contents can still be streaming in here; a fixed
            -- delay beats tracking BAG_UPDATE_DELAYED for a one-off line.
            C_Timer.After(2, function() WarbandStorage:WarnLowStock() end)
        end

    elseif event == "BANKFRAME_OPENED" then
            WarbandStorage:DebugPrint("Bank Opened")
            -- Slight delay to ensure bank APIs/tab IDs are available
            C_Timer.After(0.2, function()
                local names = {}
                for _, set in ipairs(WarbandStorage.Sets:ActiveSetsFor(WarbandStorage.Utils:GetCharacterKey())) do
                    names[#names + 1] = set.name
                end
                WarbandStorage:DebugPrint("Active sets: " .. (#names > 0 and table.concat(names, ", ") or "none"))
                WarbandStorage:ManageGoldWithWarbank()
            end)
    end
end

WarbandStorage:RegisterEvent("ADDON_LOADED")
WarbandStorage:RegisterEvent("PLAYER_LOGIN")
WarbandStorage:RegisterEvent("BANKFRAME_OPENED")
WarbandStorage:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Item moves run through the shared Lucky bank run so they never overlap
-- another Lucky addon's. Every deposit goes before every withdrawal, which
-- frees bag space for the restock; the optional bank sort goes after everything.
LuckyBankRun:OnBankOpen(20, {
    direction = "deposit",
    plan = function() return WarbandStorage:PlanWarboundDeposits() end,
    run  = function(job, queue) WarbandStorage:DepositWarboundItems(job, queue) end,
})
LuckyBankRun:OnBankOpen(30, {
    direction = "deposit",
    plan = function() return WarbandStorage:PlanExcessDeposits() end,
    run  = function(job, queue) WarbandStorage:ProcessDepositQueue(queue, 1, job) end,
})
LuckyBankRun:OnBankOpen(50, {
    direction = "withdraw",
    plan = function() return WarbandStorage:PlanRestock() end,
    run  = function(job, plan) WarbandStorage:RunWithdrawPlan(plan, job) end,
})
LuckyBankRun:OnBankOpen(90, {
    plan = function() return {} end,
    run  = function(job)
        WarbandStorage:SortWarbankAfterDeposit()
        job:Done()
    end,
})

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

    if msg:lower():find("^report") then
        WarbandStorage:PrintReport()
        return
    end

    print(PREFIX .. " " .. S.settings.unknownCommand)
end
