-- Warband Stockist — Common Utilities
-- Shared utility functions for validation, text formatting, and common operations

-- Ensure namespace
WarbandStorage = WarbandStorage or {}
WarbandStorage.Utils = WarbandStorage.Utils or {}

local Utils = WarbandStorage.Utils

-- ############################################################
-- ## Validation Utilities
-- ############################################################

-- Safe function caller with existence check
function Utils:SafeCall(obj, methodName, ...)
  if obj and obj[methodName] and type(obj[methodName]) == "function" then
    return obj[methodName](obj, ...)
  end
  return nil
end

-- Check if a value exists and is not empty
function Utils:IsValidValue(value)
  return value ~= nil and value ~= ""
end

-- Validate item ID
function Utils:IsValidItemID(itemID)
  local id = tonumber(itemID)
  return id and id > 0
end

-- Validate quantity
function Utils:IsValidQuantity(quantity)
  local qty = tonumber(quantity)
  return qty and qty >= 0
end

-- Validate item input (both ID and quantity)
function Utils:ValidateItemInput(itemID, quantity)
  return self:IsValidItemID(itemID) and self:IsValidQuantity(quantity)
end

-- ############################################################
-- ## Text Utilities
-- ############################################################

-- Format character display name with class colors
function Utils:FormatCharacterName(characterKey, className)
  if not characterKey then return "" end
  
  local name, realm = characterKey:match("^(.-)%-(.-)$")
  if not name or not realm then
    return characterKey
  end
  
  -- Get class for color - try parameter first, then stored data, then current player
  local class = className
  if not class then
    if characterKey == self:GetCharacterKey() then
      -- Current character - get live class info and store it
      _, class = UnitClass("player")
      if class then
        self:StoreCharacterClass() -- Ensure it's stored
      end
    else
      -- Other character - try stored class info
      if WarbandStockistDB and WarbandStockistDB.characterClasses then
        class = WarbandStockistDB.characterClasses[characterKey]
      end
    end
  end
  
  -- Get class color
  local color = { r = 0.7, g = 0.7, b = 0.7 } -- Default gray for unknown class
  if class and RAID_CLASS_COLORS[class] then
    color = RAID_CLASS_COLORS[class]
  end
  
  return ("|cff%02x%02x%02x%s - %s|r"):format(
    color.r * 255, color.g * 255, color.b * 255, name, realm
  )
end

-- Format item display text
function Utils:FormatItemText(itemID, itemName, quantity)
  local name = itemName or ("Item " .. (itemID or "Unknown"))
  local text = ("%s (ID: %s)"):format(name, itemID or "?")
  
  if quantity == 0 then
    return "|cff666666" .. text .. "|r"
  else
    return "|cffcccccc" .. text .. "|r"
  end
end

-- Safe debug print
function Utils:DebugPrint(message)
  if WarbandStockistDB and WarbandStockistDB.debugEnabled then
    print("|cff7fd5ff[Warband Stockist]|r " .. tostring(message))
  end
end

-- ############################################################
-- ## Character Utilities  
-- ############################################################

-- Get current character key
function Utils:GetCharacterKey()
  local name, realm = UnitFullName("player")
  return string.format("%s-%s", 
    name or UnitName("player") or "", 
    realm or GetRealmName() or ""
  )
end

-- Store current character's class
function Utils:StoreCharacterClass()
  local charKey = self:GetCharacterKey()
  local _, class = UnitClass("player")
  
  if class then
    WarbandStockistDB.characterClasses = WarbandStockistDB.characterClasses or {}
    WarbandStockistDB.characterClasses[charKey] = class
    self:DebugPrint("Stored class " .. class .. " for character " .. charKey)
  end
end

-- Get stored character class
function Utils:GetCharacterClass(characterKey)
  if not WarbandStockistDB.characterClasses then return nil end
  return WarbandStockistDB.characterClasses[characterKey]
end

-- ############################################################
-- ## Item Utilities
-- ############################################################

-- Cache for item names to reduce API calls
local itemNameCache = {}

-- Get cached item name with fallback loading
function Utils:GetItemName(itemID)
  if not itemID then return nil end
  
  -- Check cache first
  if itemNameCache[itemID] then 
    return itemNameCache[itemID] 
  end
  
  -- Try to get from API
  local name = C_Item.GetItemInfo(itemID)
  if name then
    itemNameCache[itemID] = name
    return name
  end
  
  -- If not available, try to load it
  local item = Item:CreateFromItemID(itemID)
  if item then
    item:ContinueOnItemLoad(function()
      local loadedName = C_Item.GetItemInfo(itemID)
      if loadedName then
        itemNameCache[itemID] = loadedName
        -- Trigger UI refresh if we have a refresh function
        if RefreshItemList then
          RefreshItemList()
        end
      end
    end)
  end
  
  return nil
end

-- Clear item name cache
function Utils:ClearItemCache()
  wipe(itemNameCache)
end

-- ############################################################
-- ## Collection Utilities
-- ############################################################

-- Safe table wipe
function Utils:SafeWipe(tbl)
  if type(tbl) == "table" then
    wipe(tbl)
  end
end

-- Deep copy table
function Utils:DeepCopy(original)
  if type(original) ~= "table" then return original end
  
  local copy = {}
  for key, value in pairs(original) do
    copy[key] = self:DeepCopy(value)
  end
  return copy
end

-- Count table entries
function Utils:CountTable(tbl)
  if type(tbl) ~= "table" then return 0 end
  
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end
