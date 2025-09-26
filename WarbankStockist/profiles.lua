-- Warband Stockist — Profile Management
-- Handles profile data, assignments, and legacy migration

-- ############################################################
-- ## Profile Data Management
-- ############################################################

-- Ensure WarbandStorage namespace exists
WarbandStorage = WarbandStorage or {}

-- Track which profile is currently being edited in the Profiles tab (independent from assignment)
WarbandStockistDB = WarbandStockistDB or {}
WarbandStockistDB.lastEditedProfile = WarbandStockistDB.lastEditedProfile or nil

-- ############################################################
-- ## Small helpers / compat
-- ############################################################
local function CharKey()
  local name, realm = UnitFullName("player")
  return string.format("%s-%s", name or UnitName("player") or "", realm or GetRealmName() or "")
end

local function DebugPrint(msg)
  if WarbandStockistDB.debugEnabled then
    print("|cff7fd5ff[Warband Stockist]|r " .. tostring(msg))
  end
end

local function EnsureProfile(name)
  if not name or name == "" then name = WarbandStockistDB.defaultProfile end
  WarbandStockistDB.profiles[name] = WarbandStockistDB.profiles[name] or { items = {} }
  return name, WarbandStockistDB.profiles[name]
end

local function ActiveProfileName()
  local assigned = WarbandStockistDB.assignments[CharKey()]
  return assigned or WarbandStockistDB.defaultProfile
end

local function ActiveProfile()
  local pname = ActiveProfileName()
  EnsureProfile(pname)
  return WarbandStockistDB.profiles[pname], pname
end

-- Note: Public API like DebugPrint/GetDesiredStock/IsItemOverridden are defined in other modules.

-- ############################################################
-- ## Profile Management Functions
-- ############################################################
function WarbandStorage:EnsureProfile(name)
  return EnsureProfile(name)
end

function WarbandStorage:GetActiveProfile()
  return ActiveProfile()
end

function WarbandStorage:GetActiveProfileName()
  return ActiveProfileName()
end

function WarbandStorage:GetCharacterKey()
  return CharKey()
end

function WarbandStorage:GetAllProfileNames()
  local names = {}
  for n,_ in pairs(WarbandStockistDB.profiles) do table.insert(names, n) end
  table.sort(names)
  return names
end

function WarbandStorage:GetAllCharacterKeys()
  local keys = {}
  for ck,_ in pairs(WarbandStockistDB.assignments) do table.insert(keys, ck) end
  -- ensure current char shows even if not assigned
  local me = CharKey()
  local found
  for _,k in ipairs(keys) do if k == me then found = true break end end
  if not found then table.insert(keys, me) end
  table.sort(keys)
  return keys
end

function WarbandStorage:SetActiveProfileForChar(profileName)
  EnsureProfile(profileName)
  WarbandStockistDB.assignments[CharKey()] = profileName
  
  -- Refresh UI if functions are available
  if RefreshItemList then RefreshItemList() end
  if WarbandStorage.RefreshProfileDropdown then WarbandStorage.RefreshProfileDropdown() end
  if RefreshAssignmentsList then RefreshAssignmentsList() end
end

-- ############################################################
-- ## Edited Profile (Profiles Tab) — Independent of Assignment
-- ############################################################
function WarbandStorage:GetEditedProfileName()
  local name = WarbandStockistDB.lastEditedProfile
  if not name or name == "" or not WarbandStockistDB.profiles[name] then
    return ActiveProfileName()
  end
  return name
end

function WarbandStorage:SetEditedProfileName(name)
  if not name or name == "" then return end
  EnsureProfile(name)
  WarbandStockistDB.lastEditedProfile = name
  -- Do not change character assignment here; only refresh editor UI
  if WarbandStorage.RefreshProfileDropdown then WarbandStorage.RefreshProfileDropdown() end
  if RefreshItemList then RefreshItemList() end
end

function WarbandStorage:GetEditedProfile()
  local pname = self:GetEditedProfileName()
  EnsureProfile(pname)
  return WarbandStockistDB.profiles[pname], pname
end

-- ############################################################
-- ## Legacy migration (from global/character list mode)
-- ############################################################
local didMigrate
function WarbandStorage:MigrateLegacyIfNeeded()
  if didMigrate then return end
  didMigrate = true

  -- Old globals if present
  if type(WarbandStorageData) == "table" then
    if type(WarbandStorageData.default) == "table" and next(WarbandStorageData.default) then
      local profName = "Global (Migrated)"
      EnsureProfile(profName)
      wipe(WarbandStockistDB.profiles[profName].items)
      for k,v in pairs(WarbandStorageData.default) do
        WarbandStockistDB.profiles[profName].items[tonumber(k)] = tonumber(v) or 0
      end
      -- Make it the default only if user had been using defaults
      if WarbandStorageCharData.useDefault ~= false then
        WarbandStockistDB.defaultProfile = profName
      end
    end
  end

  -- Character-specific override -> its own profile, assigned to this character
  if type(WarbandStorageCharData) == "table" and WarbandStorageCharData.useDefault == false then
    if type(WarbandStorageCharData.override) == "table" and next(WarbandStorageCharData.override) then
      local cname = CharKey()
      local profName = cname .. " (Migrated)"
      EnsureProfile(profName)
      wipe(WarbandStockistDB.profiles[profName].items)
      for k,v in pairs(WarbandStorageCharData.override) do
        WarbandStockistDB.profiles[profName].items[tonumber(k)] = tonumber(v) or 0
      end
      WarbandStockistDB.assignments[cname] = profName
    end
  end
end

-- ############################################################
-- ## Item name cache - DEPRECATED
-- ## Use WarbandStorage.Utils:GetItemName instead
-- ############################################################
function WarbandStorage:GetCachedItemName(itemID)
  -- Deprecated: redirect to new utility function
  return WarbandStorage.Utils:GetItemName(itemID)
end
