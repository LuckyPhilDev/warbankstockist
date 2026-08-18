WarbandStorageData = WarbandStorageData or {}

-- Debug print: single logger lives in common-utils; this is the short form.
function WarbandStorage:DebugPrint(msg)
    WarbandStorage.Utils:DebugPrint(msg)
end

function WarbandStorage:IsItemOverridden(itemID)
    return WarbandStorageCharData.useDefault == false
        and WarbandStorageCharData.override
        and WarbandStorageCharData.override[itemID] ~= nil
end