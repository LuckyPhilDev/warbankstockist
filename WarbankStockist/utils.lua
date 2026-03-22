WarbandStorageData = WarbandStorageData or {}

local THEME_COLORS = WarbandStorage.Theme.COLORS

-- Debug print via LuckyLog
local _wbsLog = LuckyLog:New("|cff00ccff[WBS]:|r", function()
    return WarbandStockistDB and WarbandStockistDB.debugEnabled
end)

function WarbandStorage:DebugPrint(msg)
    _wbsLog(tostring(msg))
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