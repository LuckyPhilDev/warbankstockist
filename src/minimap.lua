WarbandStorage = WarbandStorage or {}
WarbandStorage.Minimap = {}

local ICON = LuckyMedia("promo-warbank-stockist.tga")
local S = WarbandStorage.Strings
local PREFIX = S.addon.prefix .. " "

-- Flip dev/debug logging. Announced with a plain print (not DebugPrint) so the
-- user still sees confirmation when turning it off.
local function ToggleDevMode()
    WarbandStockistDB = WarbandStockistDB or {}
    local enabled = WarbandStockistDB.debugEnabled ~= true
    WarbandStockistDB.debugEnabled = enabled
    print(PREFIX .. S.minimap.devMode:format(enabled and S.minimap.devModeOn or S.minimap.devModeOff))
end

function WarbandStorage.Minimap:Init(db)
    if self.button then return end
    if not LuckyMinimap or not db then return end

    self.button = LuckyMinimap:Create({
        name    = "WarbandStockistMinimapButton",
        tocname = "Luckys_Warbank_Stockist",
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
            tt:AddLine(S.minimap.tooltipTitle)
            tt:AddLine(" ")
            tt:AddLine(S.minimap.click, 0.91, 0.86, 0.78)
            tt:AddLine(S.minimap.middleClick, 0.91, 0.86, 0.78)
            tt:AddLine(S.minimap.drag, 0.54, 0.49, 0.42)
        end,
    })
end
