WarbandStorageData = WarbandStorageData or {}

-- Simple debug print with formatting
function WarbandStorage:DebugPrint(msg)
    if WarbandStorageData and WarbandStorageData.debugEnabled then
        print("|cff00ccff[WBS]:|r " .. tostring(msg))
    end
end

function WarbandStorage:IsItemOverridden(itemID)
    return WarbandStorageCharData.useDefault == false
        and WarbandStorageCharData.override
        and WarbandStorageCharData.override[itemID] ~= nil
end