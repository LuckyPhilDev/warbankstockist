WarbandStorage = WarbandStorage or {}
WarbandStorage.Minimap = {}

local ICON = "Interface\\Icons\\achievement_guildperk_mobilebanking"
local PREFIX = "|cff7fd5ff[Warband Stockist]|r "

-- Flip dev/debug logging. Announced with a plain print (not DebugPrint) so the
-- user still sees confirmation when turning it off.
local function ToggleDevMode()
    WarbandStockistDB = WarbandStockistDB or {}
    local enabled = not (WarbandStockistDB.debugEnabled == true)
    WarbandStockistDB.debugEnabled = enabled
    print(PREFIX .. "Dev mode " .. (enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r") .. ".")
end

function WarbandStorage.Minimap:Init(db)
    if self.button then return end
    if not LuckyMinimap or not db then return end

    self.button = LuckyMinimap:Create({
        name    = "WarbandStockistMinimapButton",
        icon    = ICON,
        dbKey   = "minimap",
        db      = db,
        defaultAngle = 235,
        onClick = function(_, mouseBtn)
            if mouseBtn == "MiddleButton" then
                ToggleDevMode()
            elseif mouseBtn == "LeftButton" or mouseBtn == "RightButton" then
                WarbandStorage:OpenSettings()
            end
        end,
        tooltip = function(tt)
            tt:AddLine("|cffffd100Warband Stockist|r")
            tt:AddLine(" ")
            tt:AddLine("Click: Open settings", 0.91, 0.86, 0.78)
            tt:AddLine("Middle-click: Toggle dev mode", 0.91, 0.86, 0.78)
            tt:AddLine("Drag: Move button", 0.54, 0.49, 0.42)
        end,
    })
end
