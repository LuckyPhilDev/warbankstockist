-- Warband Stockist — Character Data Management
-- Handles storing and retrieving character-specific information like class

-- Ensure namespace
WarbandStorage = WarbandStorage or {}

-- Store character class information for proper display colors
function WarbandStorage:StoreCharacterClass()
  local name, realm = UnitFullName("player")
  local charKey = string.format("%s-%s", name or UnitName("player") or "", realm or GetRealmName() or "")
  local _, class = UnitClass("player")
  if class then
    WarbandStockistDB = WarbandStockistDB or {}
    WarbandStockistDB.characterClasses = WarbandStockistDB.characterClasses or {}
    WarbandStockistDB.characterClasses[charKey] = class
    if WarbandStockistDB.debugEnabled then
      print("|cff7fd5ff[Warband Stockist]|r Stored class " .. class .. " for character " .. charKey)
    end
  end
end

-- Call this on login to store character class
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    -- Small delay to ensure all systems are loaded
    C_Timer.After(1, function()
      if WarbandStorage.StoreCharacterClass then
        WarbandStorage:StoreCharacterClass()
      end
    end)
  end
end)
