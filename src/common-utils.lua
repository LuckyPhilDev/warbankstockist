-- Warband Stockist — Common Utilities
-- Shared utility functions for validation, text formatting, and common operations

WarbandStorage = WarbandStorage or {}
WarbandStorage.Utils = WarbandStorage.Utils or {}

local Utils = WarbandStorage.Utils
local S = WarbandStorage.Strings

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

-- Returns isValid, trimmedName. excludeName lets a rename keep its own name.
function Utils:ValidateSetName(name, excludeName)
  -- Helper to show an error in the UI (fallback to print)
  local function showError(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
      UIErrorsFrame:AddMessage(msg, 1, 0.2, 0.2)
    else
      print(tostring(msg))
    end
  end

  if type(name) ~= "string" then
    showError(S.sets.nameRequired)
    return false
  end

  local trimmed = name:match("^%s*(.-)%s*$") or ""
  if trimmed == "" then
    showError(S.sets.nameEmpty)
    return false
  end

  -- The name dialogs cap input at 40 letters.
  if #trimmed > 40 then
    showError(S.sets.nameTooLong)
    return false
  end

  if trimmed:find("[%z\1-\31]") then
    showError(S.sets.nameInvalid)
    return false
  end

  if trimmed ~= excludeName then
    for _, set in ipairs(WarbandStorage.Sets:All()) do
      if set.name == trimmed then
        showError(S.sets.nameTaken:format(trimmed))
        return false
      end
    end
  end

  return true, trimmed
end

-- ############################################################
-- ## Text Utilities
-- ############################################################

-- Split a character key into its name, realm, and class colour, for callers
-- that lay the two out themselves. A key with no realm comes back as the whole
-- key with a nil realm.
function Utils:GetCharacterParts(characterKey, className)
  local fallback = { r = 0.7, g = 0.7, b = 0.7 } -- unknown class
  if not characterKey then return "", nil, fallback end

  local name, realm = characterKey:match("^(.-)%-(.-)$")
  if not name or not realm then
    return characterKey, nil, fallback
  end

  local class = className
  if not class then
    if characterKey == self:GetCharacterKey() then
      -- Current character: read the live class and keep it for next time.
      _, class = UnitClass("player")
      if class then self:StoreCharacterClass() end
    elseif WarbandStockistDB.characterClasses then
      class = WarbandStockistDB.characterClasses[characterKey]
    end
  end

  return name, realm, (class and RAID_CLASS_COLORS[class]) or fallback
end

-- Format character display name with class colors
function Utils:FormatCharacterName(characterKey, className)
  local name, realm, color = self:GetCharacterParts(characterKey, className)
  if not realm then return name end

  return ("|cff%02x%02x%02x%s - %s|r"):format(
    color.r * 255, color.g * 255, color.b * 255, name, realm
  )
end

-- Debug print via LuckyLog
local _utilsLog = LuckyLog:New(S.addon.prefix, function()
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

-- After every page switch in the Settings window, reports each second's frame
-- rate, worst frame, and how much of it went to Lua. "ours" includes the
-- embedded Luckys_Utils copy when it is the one that won; a slow second both
-- Lua figures miss is time spent in the engine.
local ADDON_FOLDER = "Luckys_Warbank_Stockist"
local SAMPLE_SECONDS = 5

local function LastFrameMs(addon)
  if not (C_AddOnProfiler and Enum.AddOnProfilerMetric) then return 0 end
  local metric = Enum.AddOnProfilerMetric.LastTime
  if addon then return C_AddOnProfiler.GetAddOnMetric(addon, metric) or 0 end
  return C_AddOnProfiler.GetOverallMetric(metric) or 0
end

local function CategoryName(settingsPanel)
  local category = settingsPanel:GetCurrentCategory()
  return category and category:GetName() or "?"
end

local probe = CreateFrame("Frame")
probe:Hide()

local function Sample()
  local second, lastTick, secondStart = 1, debugprofilestop(), debugprofilestop()
  local frames, worst, ours, all = 0, 0, 0, 0
  probe:SetScript("OnUpdate", function()
    local now = debugprofilestop()
    frames, worst = frames + 1, math.max(worst, now - lastTick)
    ours, all = ours + LastFrameMs(ADDON_FOLDER), all + LastFrameMs()
    lastTick = now
    if now - secondStart < 1000 then return end
    print(string.format("  +%ds: %d fps, worst frame %.0f ms, ours %.1f ms, all addons %.1f ms",
      second, frames, worst, ours, all))
    second, secondStart, frames, worst, ours, all = second + 1, now, 0, 0, 0, 0
    if second > SAMPLE_SECONDS then probe:Hide() end
  end)
  probe:Show()
end

local function CountFrames(frame)
  local count = 1
  for _, child in ipairs({ frame:GetChildren() }) do count = count + CountFrames(child) end
  return count
end

function Perf:WatchSettingsSwitches(settingsPanel)
  -- SelectCategory runs this first and fires CategoryChanged last, so the gap
  -- is the whole page switch, including the old canvas being torn down.
  local switchStart, switchFrom
  hooksecurefunc(settingsPanel, "ClearActiveCategoryTutorial", function()
    switchStart, switchFrom = debugprofilestop(), CategoryName(settingsPanel)
  end)
  EventRegistry:RegisterCallback("Settings.CategoryChanged", function()
    if not (switchStart and WarbandStockistDB.debugEnabled) then return end
    print(string.format("|cff7fd5ff[Warband Stockist]|r switch \"%s\" -> \"%s\" took %.1f ms; our panel holds %d frames",
      switchFrom, CategoryName(settingsPanel), debugprofilestop() - switchStart,
      CountFrames(WarbandStorage.SettingsPanel.canvas)))
    switchStart = nil
    Sample()
  end, probe)
end

-- ############################################################
-- ## Item Utilities
-- ############################################################

-- On a cold cache every tracked item resolves its name asynchronously, and each
-- one landing used to rebuild the whole list. Coalesce them into one rebuild on
-- the next frame so a set of N items costs one refresh, not N.
local QueueItemListRefresh = LuckyUtils.Debounced(0, function()
  WarbandStorage.Perf:Count("GetItemName:coalescedRefresh")
  WarbandStorage.Settings.Refresh()
end)

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
