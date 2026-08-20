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
