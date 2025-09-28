WarbandStorageData = WarbandStorageData or {}

local THEME_COLORS = WarbandStorage.Theme.COLORS

-- Simple debug print with formatting
function WarbandStorage:DebugPrint(msg)
    -- Use the main addon's debug toggle so Settings checkbox controls all logs
    if WarbandStockistDB and WarbandStockistDB.debugEnabled then
        print("|cff00ccff[WBS]:|r " .. tostring(msg))
    end
end

function WarbandStorage:IsItemOverridden(itemID)
    return WarbandStorageCharData.useDefault == false
        and WarbandStorageCharData.override
        and WarbandStorageCharData.override[itemID] ~= nil
end

-- Deprecated: Use WarbandStorage.FrameFactory:ApplyThemeColors instead
function WarbandStorage:SetupFrameVisuals(frame)
    if not frame then return end
    WarbandStorage.FrameFactory:ApplyThemeColors(frame, "CONTENT_BG")
end

-- Deprecated: Use WarbandStorage.FrameFactory:ApplyThemeColors instead  
function WarbandStorage:SetupDialogBackground(frame)
    if not frame then return end
    WarbandStorage.FrameFactory:SetupDialogFrame(frame)
end