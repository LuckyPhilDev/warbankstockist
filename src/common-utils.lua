-- Warband Stockist — Common Utilities
-- Shared utility functions for validation, text formatting, and common operations

WarbandStorage = WarbandStorage or {}
WarbandStorage.Utils = WarbandStorage.Utils or {}

local Utils = WarbandStorage.Utils

-- ############################################################
-- ## Validation Utilities
-- ############################################################

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

-- Optional second arg excludeName allows an existing profile with that name (for rename flow)
-- Returns: boolean isValid, string trimmedName (when valid)
function Utils:ValidateProfileName(name, excludeName)
  -- Helper to show an error in the UI (fallback to print)
  local function showError(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
      UIErrorsFrame:AddMessage(msg, 1, 0.2, 0.2)
    else
      print(tostring(msg))
    end
  end

  if type(name) ~= "string" then
    showError("Please enter a profile name.")
    return false
  end

  -- Trim whitespace
  local trimmed = name:match("^%s*(.-)%s*$") or ""
  if trimmed == "" then
    showError("Profile name cannot be empty.")
    return false
  end

  -- Enforce a reasonable length (dialogs use maxLetters = 40)
  if #trimmed > 40 then
    showError("Profile name is too long (max 40 characters).")
    return false
  end

  -- Disallow control characters
  if trimmed:find("[%z\1-\31]") then
    showError("Profile name contains invalid characters.")
    return false
  end

  -- Disallow reserved default profile name except when not changing it
  local reserved = (WarbandStockistDB and WarbandStockistDB.defaultProfile) or "Default"
  if trimmed == reserved then
    -- Only allowed if we're effectively not changing the name (excludeName matches exactly)
    if not excludeName or excludeName ~= reserved then
      showError(("The profile name '%s' is reserved."):format(reserved))
      return false
    end
  end

  -- Require uniqueness against existing profiles (except excluded name)
  if WarbandStockistDB and WarbandStockistDB.profiles and WarbandStockistDB.profiles[trimmed] then
    if not excludeName or trimmed ~= excludeName then
      showError(("A profile named '%s' already exists."):format(trimmed))
      return false
    end
  end

  return true, trimmed
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

-- Debug print via LuckyLog
local _utilsLog = LuckyLog:New("|cff7fd5ff[Warband Stockist]|r", function()
  return WarbandStockistDB and WarbandStockistDB.debugEnabled
end)

function Utils:DebugPrint(message)
  _utilsLog(tostring(message))
end

-- ############################################################
-- ## Character Utilities  
-- ############################################################

-- Get current character key
function Utils:GetCharacterKey()
  return LuckyUtils.CharacterKey()
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

-- ############################################################
-- ## Perf Tracking (dev)
-- ############################################################

local Perf = { stats = {} }
WarbandStorage.Perf = Perf

local function stat(label)
  local s = Perf.stats[label]
  if not s then
    s = { label = label, calls = 0, ms = 0, peak = 0 }
    Perf.stats[label] = s
  end
  return s
end

function Perf:Now()
  return debugprofilestop()
end

function Perf:Add(label, startedAt)
  local elapsed = debugprofilestop() - startedAt
  local s = stat(label)
  s.calls = s.calls + 1
  s.ms = s.ms + elapsed
  if elapsed > s.peak then s.peak = elapsed end
end

function Perf:Count(label, n)
  local s = stat(label)
  s.calls = s.calls + (n or 1)
end

function Perf:Reset()
  wipe(self.stats)
end

function Perf:Dump(header)
  local ordered = {}
  for _, s in pairs(self.stats) do table.insert(ordered, s) end
  table.sort(ordered, function(a, b)
    if a.ms == b.ms then return a.label < b.label end
    return a.ms > b.ms
  end)

  print("|cff7fd5ff[Warband Stockist]|r perf: " .. (header or "summary"))
  for _, s in ipairs(ordered) do
    if s.ms > 0 then
      print(string.format("  %-26s %6d calls %9.2f ms  peak %7.2f ms", s.label, s.calls, s.ms, s.peak))
    else
      print(string.format("  %-26s %6d", s.label, s.calls))
    end
  end
end

-- ############################################################
-- ## Item Utilities
-- ############################################################

-- On a cold cache every tracked item resolves its name asynchronously, and each
-- one landing used to rebuild the whole list. Coalesce them into one rebuild on
-- the next frame so a profile of N items costs one refresh, not N.
local refreshQueued = false
local function QueueItemListRefresh()
  if refreshQueued or not RefreshItemList then return end
  refreshQueued = true
  C_Timer.After(0, function()
    refreshQueued = false
    WarbandStorage.Perf:Count("GetItemName:coalescedRefresh")
    RefreshItemList()
  end)
end

-- Resolve an item name through LuckyItem's shared session cache. Returns nil
-- while the name is still loading; the coalesced refresh repaints the list
-- once it lands.
function Utils:GetItemName(itemID)
  if not itemID then return nil end

  local cached = LuckyItem:GetCached(itemID)
  if cached then return cached.name end

  WarbandStorage.Perf:Count("GetItemName:miss")
  LuckyItem:Get(itemID, function(info)
    if info and info.name then QueueItemListRefresh() end
  end)
  return nil
end
