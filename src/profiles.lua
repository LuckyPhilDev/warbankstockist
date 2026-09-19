-- Warband Stockist — Profile Management
-- Handles profile data, assignments, and legacy migration

-- ############################################################
-- ## Profile Data Management
-- ############################################################

-- Ensure WarbandStorage namespace exists
WarbandStorage = WarbandStorage or {}

-- ############################################################
-- ## Small helpers / compat
-- ############################################################
local function CharKey()
  local name, realm = UnitFullName("player")
  return string.format("%s-%s", name or UnitName("player") or "", realm or GetRealmName() or "")
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
  -- Delegate to ProfileManager for consistent ordering (ignored characters last)
  if WarbandStorage.ProfileManager and WarbandStorage.ProfileManager.GetAllCharacterKeys then
    return WarbandStorage.ProfileManager:GetAllCharacterKeys()
  end
  -- Fallback: simple alphabetical list (should rarely be used)
  local keys = {}
  for ck,_ in pairs(WarbandStockistDB.assignments or {}) do table.insert(keys, ck) end
  table.sort(keys)
  return keys
end

function WarbandStorage:IsCharacterIgnored(characterKey)
  if not characterKey then return false end
  return WarbandStockistDB.ignoredCharacters and WarbandStockistDB.ignoredCharacters[characterKey] == true
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
-- ## Per-Profile: Deposit Excess Items
-- ############################################################
-- A profile deposits excess stock back to the Warband Bank unless explicitly
-- disabled. A nil flag is treated as enabled, preserving the prior default.
function WarbandStorage:IsExcessDepositEnabled(profileName)
  if not profileName or profileName == "" then return false end
  local profile = WarbandStockistDB.profiles[profileName]
  if not profile then return false end
  return profile.enableExcessDeposit ~= false
end

function WarbandStorage:SetExcessDepositEnabled(profileName, enabled)
  if not profileName or profileName == "" then return end
  EnsureProfile(profileName)
  WarbandStockistDB.profiles[profileName].enableExcessDeposit = (enabled == true)
end

-- Per-profile "sort the Warband Bank after depositing" flag. Unlike excess
-- deposit, this defaults OFF: an explicit true is required to opt in.
function WarbandStorage:IsSortAfterDepositEnabled(profileName)
  if not profileName or profileName == "" then return false end
  local profile = WarbandStockistDB.profiles[profileName]
  if not profile then return false end
  return profile.sortAfterDeposit == true
end

function WarbandStorage:SetSortAfterDepositEnabled(profileName, enabled)
  if not profileName or profileName == "" then return end
  EnsureProfile(profileName)
  WarbandStockistDB.profiles[profileName].sortAfterDeposit = (enabled == true)
end

-- Per-profile "start the Add Item quantity box at 0" flag. Only meaningful when
-- the profile deposits excess, since a kept quantity of 0 is what sends an item
-- straight to the bank. Defaults OFF.
function WarbandStorage:IsDefaultQtyZeroEnabled(profileName)
  if not profileName or profileName == "" then return false end
  local profile = WarbandStockistDB.profiles[profileName]
  if not profile then return false end
  return profile.defaultQtyZero == true and self:IsExcessDepositEnabled(profileName)
end

function WarbandStorage:SetDefaultQtyZeroEnabled(profileName, enabled)
  if not profileName or profileName == "" then return end
  EnsureProfile(profileName)
  WarbandStockistDB.profiles[profileName].defaultQtyZero = (enabled == true)
end

-- Per-profile "warn in chat at login when bags are short" flag. Defaults OFF.
function WarbandStorage:IsLowStockWarningEnabled(profileName)
  if not profileName or profileName == "" then return false end
  local profile = WarbandStockistDB.profiles[profileName]
  return profile ~= nil and profile.lowStockWarning == true
end

function WarbandStorage:SetLowStockWarningEnabled(profileName, enabled)
  if not profileName or profileName == "" then return end
  EnsureProfile(profileName)
  WarbandStockistDB.profiles[profileName].lowStockWarning = (enabled == true)
end

