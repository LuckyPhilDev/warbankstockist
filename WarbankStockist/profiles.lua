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
-- Persistent flags to ensure legacy migration runs only once
WarbandStockistDB.migratedLegacyGlobal = WarbandStockistDB.migratedLegacyGlobal or false
WarbandStockistDB.migratedLegacyChar = WarbandStockistDB.migratedLegacyChar or {}

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
  if not name or name == "" then return nil, nil end
  WarbandStockistDB.profiles[name] = WarbandStockistDB.profiles[name] or { items = {} }
  return name, WarbandStockistDB.profiles[name]
end

local function ActiveProfileName()
  -- No default fallback: unassigned by default
  return WarbandStockistDB.assignments[CharKey()]
end

local function ActiveProfile()
  local pname = ActiveProfileName()
  if not pname or pname == "" then
    return { items = {} }, nil
  end
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
  local seen = {}
  -- Add assigned characters
  for ck,_ in pairs(WarbandStockistDB.assignments or {}) do
    if ck and not seen[ck] then table.insert(keys, ck); seen[ck] = true end
  end
  -- Add any known characters from stored classes (seen across sessions)
  if WarbandStockistDB.characterClasses then
    for ck,_ in pairs(WarbandStockistDB.characterClasses) do
      if ck and not seen[ck] then table.insert(keys, ck); seen[ck] = true end
    end
  end
  -- Ensure current character is always present
  local me = CharKey()
  if me and not seen[me] then table.insert(keys, me); seen[me] = true end
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
  if not pname or pname == "" then
    return { items = {} }, nil
  end
  EnsureProfile(pname)
  return WarbandStockistDB.profiles[pname], pname
end

-- ############################################################
-- ## Legacy migration (from global/character list mode)
-- ############################################################
function WarbandStorage:MigrateLegacyIfNeeded()
  -- Run at most once per session, and only if not already persisted
  if self._didMigrateOnce then return end
  self._didMigrateOnce = true

  -- Defensive initialization in case saved vars aren’t fully populated yet
  WarbandStockistDB = WarbandStockistDB or {}
  WarbandStockistDB.profiles = WarbandStockistDB.profiles or {}
  WarbandStockistDB.assignments = WarbandStockistDB.assignments or {}
  WarbandStockistDB.migratedLegacyGlobal = (WarbandStockistDB.migratedLegacyGlobal == true) and true or false
  WarbandStockistDB.migratedLegacyChar = WarbandStockistDB.migratedLegacyChar or {}

  -- Old globals if present
  if not WarbandStockistDB.migratedLegacyGlobal and type(WarbandStorageData) == "table" then
    -- If the migrated profile already exists from a prior run, mark as migrated to prevent re-creation
    if WarbandStockistDB.profiles and WarbandStockistDB.profiles["Global (Migrated)"] then
      WarbandStockistDB.migratedLegacyGlobal = true
    end
    if type(WarbandStorageData.default) == "table" and next(WarbandStorageData.default) then
      local profName = "Global (Migrated)"
      EnsureProfile(profName)
      wipe(WarbandStockistDB.profiles[profName].items)
      for k,v in pairs(WarbandStorageData.default) do
        WarbandStockistDB.profiles[profName].items[tonumber(k)] = tonumber(v) or 0
      end
      -- Do not force any default profile; leave characters Unassigned by default
      WarbandStockistDB.migratedLegacyGlobal = true
      DebugPrint("Migrated legacy global defaults into profile '" .. profName .. "'.")
    end
  end

  -- Character-specific override -> its own profile, assigned to this character
  local cname = CharKey()
  if not WarbandStockistDB.migratedLegacyChar[cname]
     and type(WarbandStorageCharData) == "table"
     and WarbandStorageCharData.useDefault == false then
    if type(WarbandStorageCharData.override) == "table" and next(WarbandStorageCharData.override) then
      local profName = cname .. " (Migrated)"
      EnsureProfile(profName)
      wipe(WarbandStockistDB.profiles[profName].items)
      for k,v in pairs(WarbandStorageCharData.override) do
        WarbandStockistDB.profiles[profName].items[tonumber(k)] = tonumber(v) or 0
      end
      WarbandStockistDB.assignments[cname] = profName
      WarbandStockistDB.migratedLegacyChar[cname] = true
      DebugPrint("Migrated legacy character override into profile '" .. profName .. "' for " .. cname .. ".")
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
