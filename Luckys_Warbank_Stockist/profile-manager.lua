-- Warband Stockist — Profile Manager
-- Centralized profile management operations

-- Ensure namespace
WarbandStorage = WarbandStorage or {}
WarbandStorage.ProfileManager = WarbandStorage.ProfileManager or {}

local ProfileManager = WarbandStorage.ProfileManager
local Utils = WarbandStorage.Utils

-- ############################################################
-- ## Profile Operations
-- ############################################################

-- Ensure a profile exists with given name
function ProfileManager:EnsureProfile(name)
  if not Utils:IsValidValue(name) then return nil, nil end
  
  WarbandStockistDB.profiles[name] = WarbandStockistDB.profiles[name] or { items = {} }
  return name, WarbandStockistDB.profiles[name]
end

-- Get active profile name for current character
function ProfileManager:GetActiveProfileName()
  local charKey = Utils:GetCharacterKey()
  return WarbandStockistDB.assignments[charKey]
end

-- Get active profile data
-- Optionally resolve a specific profile name; otherwise prefer the 'edited' profile if available
local function resolveProfileName(preferredName)
  if preferredName and preferredName ~= "" then return preferredName end
  if WarbandStorage and WarbandStorage.GetEditedProfileName then
    local edited = WarbandStorage:GetEditedProfileName()
    if edited and edited ~= "" then return edited end
  end
  return ProfileManager:GetActiveProfileName()
end

function ProfileManager:GetActiveProfile(profileName)
  local name = resolveProfileName(profileName)
  self:EnsureProfile(name)
  return WarbandStockistDB.profiles[name] or { items = {} }, name
end

-- Set active profile for current character
function ProfileManager:SetActiveProfileForChar(profileName)
  if not Utils:IsValidValue(profileName) then return false end
  
  self:EnsureProfile(profileName)
  local charKey = Utils:GetCharacterKey()
  WarbandStockistDB.assignments[charKey] = profileName
  
  -- Refresh UI if available
  self:RefreshUI()
  
  return true
end

-- Create new profile
function ProfileManager:CreateProfile(name)
  if not Utils:IsValidValue(name) then return false end
  local reserved = (WarbandStockistDB and WarbandStockistDB.defaultProfile) or "Default"
  if name == reserved then
    Utils:DebugPrint("The reserved default profile already exists and cannot be created manually.")
    return false
  end
  
  local _, profile = self:EnsureProfile(name)
  -- Do not change character assignments here. Creation should be side-effect free.
  self:RefreshUI()
  Utils:DebugPrint("Created new profile: " .. name)
  return true
end

-- Rename existing profile
function ProfileManager:RenameProfile(oldName, newName)
  if not Utils:IsValidValue(oldName) or not Utils:IsValidValue(newName) then 
    return false 
  end
  local reserved = (WarbandStockistDB and WarbandStockistDB.defaultProfile) or "Default"
  if newName == reserved then
    Utils:DebugPrint("Cannot rename a profile to the reserved default profile name.")
    return false
  end
  
  if oldName == newName then return true end
  
  -- Check if old profile exists
  if not WarbandStockistDB.profiles[oldName] then return false end
  
  -- Create new profile with copied data
  self:EnsureProfile(newName)
  WarbandStockistDB.profiles[newName].items = Utils:DeepCopy(WarbandStockistDB.profiles[oldName].items)
  
  -- Delete old profile
  WarbandStockistDB.profiles[oldName] = nil
  
  -- Update character assignments
  for charKey, assignedProfile in pairs(WarbandStockistDB.assignments) do
    if assignedProfile == oldName then
      WarbandStockistDB.assignments[charKey] = newName
    end
  end
  
  self:RefreshUI()
  Utils:DebugPrint("Renamed profile from '" .. oldName .. "' to '" .. newName .. "'")
  return true
end

-- Duplicate profile
function ProfileManager:DuplicateProfile(sourceName, newName)
  if not Utils:IsValidValue(sourceName) or not Utils:IsValidValue(newName) then
    return false
  end
  
  -- Check if source exists
  if not WarbandStockistDB.profiles[sourceName] then return false end
  
  -- Create new profile
  local _, newProfile = self:EnsureProfile(newName)
  if not newProfile then return false end
  Utils:SafeWipe(newProfile.items)
  
  -- Copy items from source
  for itemID, quantity in pairs(WarbandStockistDB.profiles[sourceName].items) do
    newProfile.items[itemID] = quantity
  end
  
  -- Do not change assignments on duplicate; just refresh UI
  self:RefreshUI()
  Utils:DebugPrint("Duplicated profile '" .. sourceName .. "' as '" .. newName .. "'")
  return true
end

-- Delete profile
function ProfileManager:DeleteProfile(name)
  if not Utils:IsValidValue(name) then return false end
  
  -- Check if profile exists
  if not WarbandStockistDB.profiles[name] then return false end
  
  -- Delete the profile
  WarbandStockistDB.profiles[name] = nil
  -- If this was the legacy migrated global profile, prevent re-migration
  if name == "Global (Migrated)" then
    WarbandStockistDB.migratedLegacyGlobal = true
  end
  
  -- Reassign characters using this profile to Unassigned (nil)
  for charKey, assignedProfile in pairs(WarbandStockistDB.assignments) do
    if assignedProfile == name then
      WarbandStockistDB.assignments[charKey] = nil
    end
  end
  
  self:RefreshUI()
  Utils:DebugPrint("Deleted profile: " .. name)
  return true
end

-- Get all profile names
function ProfileManager:GetAllProfileNames()
  local names = {}
  for profileName in pairs(WarbandStockistDB.profiles) do
    table.insert(names, profileName)
  end
  table.sort(names)
  return names
end

-- ############################################################
-- ## Item Management
-- ############################################################

-- Add item to current profile
function ProfileManager:AddItemToProfile(itemID, quantity, profileName)
  if not Utils:IsValidItemID(itemID) or not Utils:IsValidQuantity(quantity) then
    return false
  end
  
  local profile = self:GetActiveProfile(profileName)
  profile.items[tonumber(itemID)] = tonumber(quantity)
  
  self:RefreshUI()
  Utils:DebugPrint("Added item " .. itemID .. " (qty: " .. quantity .. ") to profile")
  return true
end

-- Remove item from current profile
function ProfileManager:RemoveItemFromProfile(itemID, profileName)
  if not Utils:IsValidItemID(itemID) then return false end
  
  local profile = self:GetActiveProfile(profileName)
  profile.items[tonumber(itemID)] = nil
  
  self:RefreshUI()
  Utils:DebugPrint("Removed item " .. itemID .. " from profile")
  return true
end

-- Clear all items from current profile
function ProfileManager:ClearProfileItems(profileName)
  local profile = self:GetActiveProfile(profileName)
  Utils:SafeWipe(profile.items)
  
  self:RefreshUI()
  Utils:DebugPrint("Cleared all items from current profile")
  return true
end

-- Get desired stock for current profile
function ProfileManager:GetDesiredStock(profileName)
  local profile = self:GetActiveProfile(profileName)
  return profile.items or {}
end

-- ############################################################
-- ## Character Assignment Management
-- ############################################################

-- Get all character keys that have assignments
function ProfileManager:GetAllCharacterKeys()
  local keys = {}
  local seen = {}
  
  -- Add assigned characters
  for charKey in pairs(WarbandStockistDB.assignments or {}) do
    if charKey and not seen[charKey] then table.insert(keys, charKey); seen[charKey] = true end
  end
  
  -- Add known characters from stored classes
  if WarbandStockistDB.characterClasses then
    for charKey,_ in pairs(WarbandStockistDB.characterClasses) do
      if charKey and not seen[charKey] then table.insert(keys, charKey); seen[charKey] = true end
    end
  end
  
  -- Ensure current character is included
  local currentChar = Utils:GetCharacterKey()
  if currentChar and not seen[currentChar] then table.insert(keys, currentChar); seen[currentChar] = true end
  
  table.sort(keys, function(a, b)
    local ia = WarbandStockistDB.ignoredCharacters and WarbandStockistDB.ignoredCharacters[a]
    local ib = WarbandStockistDB.ignoredCharacters and WarbandStockistDB.ignoredCharacters[b]
    if ia and not ib then return false end
    if ib and not ia then return true end
    return a < b
  end)
  return keys
end

-- Unassign character from any profile (use default)
function ProfileManager:UnassignCharacter(characterKey)
  if not characterKey then return false end
  
  WarbandStockistDB.assignments[characterKey] = nil
  -- Keep ignored state as-is when unassigning
  self:RefreshUI()
  
  Utils:DebugPrint("Unassigned character: " .. characterKey)
  return true
end

-- Ignore a character (push to bottom, grey out)
function ProfileManager:IgnoreCharacter(characterKey)
  if not characterKey then return false end
  WarbandStockistDB.ignoredCharacters = WarbandStockistDB.ignoredCharacters or {}
  WarbandStockistDB.ignoredCharacters[characterKey] = true
  self:RefreshUI()
  return true
end

-- Clear ignore when assigning a profile
function ProfileManager:AssignProfile(characterKey, profileName)
  if not characterKey or not Utils:IsValidValue(profileName) then return false end
  self:EnsureProfile(profileName)
  WarbandStockistDB.assignments[characterKey] = profileName
  if WarbandStockistDB.ignoredCharacters then
    WarbandStockistDB.ignoredCharacters[characterKey] = nil
  end
  self:RefreshUI()
  return true
end

-- ############################################################
-- ## UI Refresh Coordination
-- ############################################################

-- Refresh all related UI components
function ProfileManager:RefreshUI()
  -- Refresh profile dropdown
  if WarbandStorage.RefreshProfileDropdown then
    WarbandStorage.RefreshProfileDropdown()
  end
  
  -- Refresh item list
  if RefreshItemList then
    RefreshItemList()
  end
  
  -- Refresh assignments list
  if RefreshAssignmentsList then
    RefreshAssignmentsList()
  end
end
