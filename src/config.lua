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
-- ##     goldManagement = {
-- ##       brackets = { { minLevel=1, maxLevel=79, gold=500 }, ... },
-- ##       overrides = { ["Name-Realm"] = goldAmount },
-- ##     },
-- ##   }
-- ############################################################

WarbandStorage = WarbandStorage or {}

-- Settings added in this version or later are badged NEW and listed on the
-- What's New page. Raise it when the highlights from a release stop being worth
-- pointing at.
WarbandStorage.WHATS_NEW_MIN_VERSION = "1.10.0"

-- New SavedVariables root (account-wide). Make sure your TOC lists this name.
WarbandStockistDB = WarbandStockistDB or {
  debugEnabled = false,
  defaultProfile = "Default",
  profiles = {},
  assignments = {},
  characterClasses = {}, -- Store character class info for proper coloring
  -- Gold management: level brackets and per-character overrides.
  -- Brackets: ordered list of { minLevel, maxLevel, gold } (whole gold pieces).
  -- Overrides: keyed by "Name-Realm", whole gold pieces; takes priority over brackets.
  -- A character with no matching bracket AND no override gets no gold management.
  goldManagement = {
    brackets = {},
    overrides = {},
  },
  -- Warbound auto-deposit: move warbound gear into the bank on open,
  -- before the profile restock runs.
  warboundDeposit = { enabled = false, armor = false, weapons = false, tokens = false },
  -- Development helpers (safe to leave false in release)
  devOpenOnLogin = false,
  minimap = {},
}

-- Per-character scratch (kept for any other modules that still read it)
WarbandStorageCharData = WarbandStorageCharData or {}
