WarbandStorage = WarbandStorage or {}
WarbandStorage.Minimap = {}

local ICON = "Interface\\Icons\\achievement_guildperk_mobilebanking"

function WarbandStorage.Minimap:Init(db)
    if self.button then return end
    if not LuckyMinimap or not db then return end

    self.button = LuckyMinimap:Create({
        name    = "WarbandStockistMinimapButton",
        icon    = ICON,
        dbKey   = "minimap",
        db      = db,
        onClick = function(_, mouseBtn)
            if mouseBtn == "LeftButton" or mouseBtn == "RightButton" then
                WarbandStorage:OpenSettings()
            end
        end,
        tooltip = function(tt)
            tt:AddLine("|cffffd100Warband Stockist|r")
            tt:AddLine(" ")
            tt:AddLine("Click: Open settings", 0.91, 0.86, 0.78)
            tt:AddLine("Shift+drag: Move button", 0.54, 0.49, 0.42)
        end,
    })
end
