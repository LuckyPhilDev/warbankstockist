-- Debug print: single logger lives in common-utils; this is the short form.
function WarbandStorage:DebugPrint(msg)
    WarbandStorage.Utils:DebugPrint(msg)
end
