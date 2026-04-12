-- Warband Stockist — Configuration (Simplified)
-- This file now only contains the core SavedVariables setup
-- UI functionality has been moved to separate files for better organization

-- ############################################################
-- ## SavedVariables layout (account-wide)
-- ##   WarbandStockistDB = {
-- ##     debugEnabled = boolean,
-- ##     defaultProfile = "Default",
-- ##     profiles = {
-- ##       [profileName] = { items = { [itemID] = qty, ... } },
-- ##     },
-- ##     assignments = { ["Realm-Character"] = profileName },
-- ##   }
-- ############################################################

WarbandStorage = WarbandStorage or {}

-- New SavedVariables root (account-wide). Make sure your TOC lists this name.
WarbandStockistDB = WarbandStockistDB or {
  debugEnabled = false,
  defaultProfile = "Default",
  profiles = {},
  assignments = {},
  characterClasses = {}, -- Store character class info for proper coloring
  -- Development helpers (safe to leave false in release)
  devOpenOnLogin = false,
}

-- Per-character scratch (kept for any other modules that still read it)
WarbandStorageCharData = WarbandStorageCharData or {}

-- Note: The rest of the configuration UI has been moved to:
-- - profiles.lua: Profile management and data handling
-- - ui-theme.lua: Theme colors, fonts, and string constants
-- - ui-components.lua: Reusable UI components
-- - ui-tabs.lua: Tab system and list management  
-- - settings-panel.lua: Main settings panel creation
