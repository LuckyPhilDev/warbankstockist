-- Warband Stockist — Frame Factory
-- Consolidated frame creation and styling utilities

-- Ensure namespace
WarbandStorage = WarbandStorage or {}
WarbandStorage.FrameFactory = WarbandStorage.FrameFactory or {}

local FrameFactory = WarbandStorage.FrameFactory
local FONTS = WarbandStorage.Theme.FONTS

-- ############################################################
-- ## Frame Creation Utilities
-- ############################################################

-- Standard backdrop configurations
local BACKDROP_CONFIGS = {
  dialog = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
  },

  panel = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  },

  content = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  }
}

-- Apply theme colors safely
local function ApplyThemeColors(frame, colorType, borderType)
  if not frame then return end

  -- Safely access theme colors
  local colors = WarbandStorage and WarbandStorage.Theme and WarbandStorage.Theme.COLORS
  if not colors then
    -- Fallback colors if theme not loaded
    colors = {
      BACKGROUND = { 0.1, 0.1, 0.1, 0.9 },
      CONTENT_BG = { 0.05, 0.05, 0.05, 0.8 },
      BORDER = { 0.4, 0.4, 0.4, 1.0 }
    }
  end

  local bgColor = colors[colorType] or colors["CONTENT_BG"]
  local borderColor = colors[borderType or "BORDER"] or colors["BORDER"]

  if bgColor and #bgColor >= 4 then
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
  end

  if borderColor and #borderColor >= 4 then
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
  end
end

-- Create a styled frame with backdrop
function FrameFactory:CreateStyledFrame(parent, frameType, width, height, colorType)
  frameType = frameType or "panel"
  colorType = colorType or "CONTENT_BG"

  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")

  if width and height then
    frame:SetSize(width, height)
  end

  local backdrop = BACKDROP_CONFIGS[frameType]
  if backdrop then
    frame:SetBackdrop(backdrop)
    ApplyThemeColors(frame, colorType)
  end

  return frame
end

-- Create dialog frame (main panels)
function FrameFactory:CreateDialogFrame(parent, name, width, height)
  local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
  frame:SetSize(width or 620, height or 520)
  frame:SetBackdrop(BACKDROP_CONFIGS.dialog)
  ApplyThemeColors(frame, "BACKGROUND")
  return frame
end

-- Apply theme colors and backdrop to existing frame
function FrameFactory:SetupDialogFrame(frame)
  if not frame then return end

  frame:SetBackdrop(BACKDROP_CONFIGS.dialog)
  ApplyThemeColors(frame, "BACKGROUND")
end

-- Create content panel
function FrameFactory:CreateContentPanel(parent, width, height)
  return self:CreateStyledFrame(parent, "content", width, height, "CONTENT_BG")
end

-- Apply theme colors to existing frame (public method)
function FrameFactory:ApplyThemeColors(frame, colorType, borderType)
  ApplyThemeColors(frame, colorType, borderType)
end

-- Create tab frame
function FrameFactory:CreateTabFrame(parent, width, height, isActive)
  local tab = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  tab:SetSize(width or 140, height or 32)
  tab:SetBackdrop(BACKDROP_CONFIGS.panel)
  tab:EnableMouse(true)

  -- Apply initial colors based on state
  local colorType = isActive and "TAB_ACTIVE" or "TAB_INACTIVE"
  ApplyThemeColors(tab, colorType)

  return tab
end

-- ############################################################
-- ## Common Event Handlers
-- ############################################################

-- Standard tab hover effects
function FrameFactory:SetupTabHoverEffects(tab)
  local colors = WarbandStorage.Theme and WarbandStorage.Theme.COLORS
  if not colors then return end

  tab:SetScript("OnEnter", function(self)
    if not self.isSelected then
      ApplyThemeColors(self, "TAB_HOVER")
    end
  end)

  tab:SetScript("OnLeave", function(self)
    if not self.isSelected then
      ApplyThemeColors(self, "TAB_INACTIVE")
    end
  end)
end

-- Standard tooltip setup
function FrameFactory:SetupTooltip(frame, text, anchor)
  frame:SetScript("OnEnter", function(self)
    if text then
      GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
      GameTooltip:SetText(text, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)

  frame:SetScript("OnLeave", function()
    GameTooltip_Hide()
  end)
end
