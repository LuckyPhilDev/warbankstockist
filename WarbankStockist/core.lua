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
        
        -- Store current character's class for proper coloring
        if WarbandStorage.Utils and WarbandStorage.Utils.StoreCharacterClass then
            WarbandStorage.Utils:StoreCharacterClass()
        end
        
        -- Initialize settings panel after all modules are loaded
        if WarbandStorage.UI and WarbandStorage.UI.CreateTabbedSettingsCategory then
            WarbandStorage.UI:CreateTabbedSettingsCategory()
        end
        
        WarbandStorage:DebugPrint("WarbandStorage loaded!")
        
    elseif event == "BANKFRAME_OPENED" then
        WarbandStorage:DebugPrint("Bank Opened")
        WarbandStorage:CheckAndWithdrawItemsFromWarbank()
    end
end

-- Register PLAYER_LOGIN via dispatcher
WarbandStorage:RegisterEvent("PLAYER_LOGIN")
WarbandStorage:RegisterEvent("BANKFRAME_OPENED")

-- Open settings helper: tries category ID, object, name lookup, then panel frame
function WarbandStorage:OpenSettings()
    -- Ensure settings category is created
    if not self.SettingsCategory then
        if self.UI and self.UI.CreateTabbedSettingsCategory then
            self.UI:CreateTabbedSettingsCategory()
        end
    end

    -- Prefer modern Settings API
    if Settings and Settings.OpenToCategory then
        local cat = self.SettingsCategory
        if cat then
            -- Try by ID first if available
            local id = self.SettingsCategoryID
            if type(cat) == "table" then
                id = id or cat.ID or cat.Id
                if not id and type(cat.GetID) == "function" then id = cat:GetID() end
            end
            if id then
                Settings.OpenToCategory(id)
                -- Some clients require a second call shortly after to focus correctly
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.1, function() Settings.OpenToCategory(id) end)
                end
                return
            end
            -- Fallback to passing the category object
            Settings.OpenToCategory(cat)
            if C_Timer and C_Timer.After then
                C_Timer.After(0.1, function() Settings.OpenToCategory(cat) end)
            end
            return
        end

        -- Try lookup by registered name
        local name = self.Theme and self.Theme.STRINGS and self.Theme.STRINGS.SETTINGS_NAME
        if name and Settings.GetCategory then
            local found = Settings.GetCategory(name)
            if found then
                local fid = found.ID or found.Id
                if not fid and type(found.GetID) == "function" then fid = found:GetID() end
                if fid then
                    Settings.OpenToCategory(fid)
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.05, function() Settings.OpenToCategory(fid) end)
                    end
                else
                    Settings.OpenToCategory(found)
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0.05, function() Settings.OpenToCategory(found) end)
                    end
                end
                return
            end
        end

        -- Last resort: if panel frame exists, try opening to it
        local panel = _G["WarbandStockistOptionsPanel"]
        if panel then
            Settings.OpenToCategory(panel)
            return
        end
    end

    -- Legacy fallback (pre-DF or if Settings API misbehaves)
    local legacyPanel = _G and _G["WarbandStockistOptionsPanel"]
    local legacyOpen = _G and _G["InterfaceOptionsFrame_OpenToCategory"]
    if legacyPanel and type(legacyOpen) == "function" then
        legacyOpen(legacyPanel)
        legacyOpen(legacyPanel) -- Call twice per known quirk
        return
    end

    print("|cff7fd5ff[Warband Stockist]|r Unable to open addon settings panel.")
end

SLASH_WARBANDSTORAGE1 = "/wbs"
SlashCmdList["WARBANDSTORAGE"] = function(msg)
    msg = type(msg) == "string" and msg:match("^%s*(.-)%s*$") or msg
    if msg and msg:lower():find("^settings") then
        WarbandStorage:OpenSettings()
        return
    end

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
