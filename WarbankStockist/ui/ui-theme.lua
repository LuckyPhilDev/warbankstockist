-- Warband Stockist — UI Theme & Constants
-- Contains theming colors, fonts, and UI constants

-- ############################################################
-- ## UI/Label Constants
-- ############################################################
local FONT_LABEL       = "GameFontNormalSmall"
local FONT_SECTION     = "GameFontHighlightLarge"
local FONT_INLINE_HINT = "GameFontHighlightSmall"
local FONT_TAB         = "GameFontNormal"

-- Color constants for consistent theming
local THEME_COLORS = {
  BACKGROUND = {0.1, 0.1, 0.1, 0.9},
  TAB_ACTIVE = {0.2, 0.2, 0.3, 0.9},
  TAB_INACTIVE = {0.15, 0.15, 0.15, 0.7},
  TAB_HOVER = {0.25, 0.25, 0.35, 0.8},
  BORDER = {0.4, 0.4, 0.4, 1.0},
  CONTENT_BG = {0.05, 0.05, 0.05, 0.8},
}

-- ############################################################
-- ## String Constants
-- ############################################################
local SETTINGS_NAME                         = "A Warband Stockist"
local STR_TITLE                             = "Warband Stockist Settings"
local STR_DEBUG_LABEL                       = "Enable Debug Logging"
local STR_DEBUG_TOOLTIP                     = "When enabled, detailed debug messages will be printed to chat."
local STR_HELP_TEXT                         = "This addon keeps chosen items topped up from your Warband Bank. Create profiles (e.g. 'Raider') and assign them to characters. Each profile has its own item list."
local STR_SECTION_PROFILE                   = "Profiles"
local STR_PROFILE_LABEL                     = "Active profile:"
local STR_PROFILE_NEW                       = "New"
local STR_PROFILE_RENAME                    = "Rename"
local STR_PROFILE_DUPLICATE                 = "Duplicate"
local STR_PROFILE_DELETE                    = "Delete"
local STR_SECTION_ASSIGNMENTS               = "Character Assignments"
local STR_ASSIGN_CHARACTERS                 = "Character"
local STR_ASSIGN_PROFILES                   = "Profile"
local STR_UNASSIGN                          = "Unassign"
local STR_UNASSIGNED                        = "Unassigned"
local STR_ASSIGN_TO_CHAR                    = "Assign to Character"
local STR_SECTION_ADD_ITEM                  = "Add Item"
local STR_LABEL_ITEM_ID                     = "Item ID:"
local STR_LABEL_ITEM_ID_TOOLTIP             = "Enter the numeric ID of the item you want to track. You can also drop an item link here."
local STR_LABEL_QTY                         = "Qty:"
local STR_LABEL_QTY_TOOLTIP                 = "Enter the quantity to keep stocked."
local STR_BUTTON_ADD                        = "Add"
local STR_BUTTON_ADD_TOOLTIP                = "Adds the specified item and quantity to the profile's stock list."
local STR_BUTTON_CLEAR                      = "Clear List"
local STR_BUTTON_CLEAR_TOOLTIP              = "Removes all items from the current profile."
local STR_SECTION_TRACKED                   = "Tracked Items"
local STR_BUTTON_REMOVE                     = "Remove"
local STR_ENABLE_EXCESS_DEPOSIT             = "Deposit Excess Items"
local STR_ENABLE_EXCESS_DEPOSIT_TOOLTIP     = "If enabled, items in excess of configured stock will be deposited into the Warband Bank when it is open."

-- ############################################################
-- ## Export Theme API
-- ############################################################
WarbandStorage = WarbandStorage or {}
WarbandStorage.Theme = WarbandStorage.Theme or {}

-- Export colors
WarbandStorage.Theme.COLORS = THEME_COLORS

-- Export fonts
WarbandStorage.Theme.FONTS = {
  LABEL = FONT_LABEL,
  SECTION = FONT_SECTION,
  INLINE_HINT = FONT_INLINE_HINT,
  TAB = FONT_TAB,
}

-- Export strings
WarbandStorage.Theme.STRINGS = {
  SETTINGS_NAME = SETTINGS_NAME,
  TITLE = STR_TITLE,
  DEBUG_LABEL = STR_DEBUG_LABEL,
  DEBUG_TOOLTIP = STR_DEBUG_TOOLTIP,
  HELP_TEXT = STR_HELP_TEXT,
  SECTION_PROFILE = STR_SECTION_PROFILE,
  SECTION_ASSIGNMENTS = STR_SECTION_ASSIGNMENTS,
  ASSIGN_CHARACTERS = STR_ASSIGN_CHARACTERS,
  ASSIGN_PROFILES = STR_ASSIGN_PROFILES,
  PROFILE_LABEL = STR_PROFILE_LABEL,
  PROFILE_NEW = STR_PROFILE_NEW,
  PROFILE_RENAME = STR_PROFILE_RENAME,
  PROFILE_DUPLICATE = STR_PROFILE_DUPLICATE,
  PROFILE_DELETE = STR_PROFILE_DELETE,
  UNASSIGN = STR_UNASSIGN,
  UNASSIGNED = STR_UNASSIGNED,
  ASSIGN_TO_CHAR = STR_ASSIGN_TO_CHAR,
  SECTION_ADD_ITEM = STR_SECTION_ADD_ITEM,
  LABEL_ITEM_ID = STR_LABEL_ITEM_ID,
  LABEL_ITEM_ID_TOOLTIP = STR_LABEL_ITEM_ID_TOOLTIP,
  LABEL_QTY = STR_LABEL_QTY,
  LABEL_QTY_TOOLTIP = STR_LABEL_QTY_TOOLTIP,
  BUTTON_ADD = STR_BUTTON_ADD,
  BUTTON_ADD_TOOLTIP = STR_BUTTON_ADD_TOOLTIP,
  BUTTON_CLEAR = STR_BUTTON_CLEAR,
  BUTTON_CLEAR_TOOLTIP = STR_BUTTON_CLEAR_TOOLTIP,
  SECTION_TRACKED = STR_SECTION_TRACKED,
  BUTTON_REMOVE = STR_BUTTON_REMOVE,
  ENABLE_EXCESS_DEPOSIT = STR_ENABLE_EXCESS_DEPOSIT,
  ENABLE_EXCESS_DEPOSIT_TOOLTIP = STR_ENABLE_EXCESS_DEPOSIT_TOOLTIP,
}
