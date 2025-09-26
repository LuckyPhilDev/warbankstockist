-- Warband Stockist — UI Components
-- Reusable UI components like dropdowns, input rows, headers, etc.

-- Ensure namespace
WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

-- Get theme references
local THEME_COLORS = WarbandStorage.Theme.COLORS
local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- ############################################################
-- ## Base Components
-- ############################################################

-- Create section header
function CreateSectionHeader(parent, text)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetText(text or "")
  header:SetTextColor(0.9, 0.8, 0.4, 1)
  return header
end

-- Create subheading Text header
function CreateSubheadingText(parent, text)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetText(text or "")
  label:SetTextColor(0.9, 0.8, 0.4, 1)
  return label
end

-- Create default Text header
function CreateDefaultText(parent, text)
  local label = parent:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
  label:SetText(text or "")
  label:SetTextColor(0.8, 0.8, 0.8, 1)
  return label
end

function CreateButton(parent, text, width, height)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 75, height or 22)
  button:SetText(text or "")
  return button
end

function CreateNumericEditText(parent, hoverText, width, height)
  local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  input:SetSize(width or 100, height or 22)
  input:SetAutoFocus(false)
  input:SetNumeric(true)
  if (hoverText) then
    input:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:SetText(hoverText, 1, 1, 1)
      GameTooltip:Show()
    end)
    input:SetScript("OnLeave", GameTooltip_Hide)
  end
  return input
end

-- Create styled button
function CreateStyledButton(parent, width, height, text)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 100, height or 22)
  if text then button:SetText(text) end
  return button
end

-- ############################################################
-- ## Dropdown Component
-- ############################################################
function WarbandStorage.UI:CreateDropdown(parent, width)
  local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dd, width or 160)
  UIDropDownMenu_SetText(dd, "")
  
  function dd:Refresh()
    UIDropDownMenu_Initialize(self, function(frame, level)
      local info = UIDropDownMenu_CreateInfo()
      for _,name in ipairs(WarbandStorage:GetAllProfileNames()) do
        info.text = name
        info.func = function()
          WarbandStorage:SetActiveProfileForChar(name)
          UIDropDownMenu_SetText(dd, name)
        end
        info.checked = (name == WarbandStorage:GetActiveProfileName())
        UIDropDownMenu_AddButton(info, level)
      end
    end)
    UIDropDownMenu_SetText(self, WarbandStorage:GetActiveProfileName())
  end
  
  dd:Refresh()
  return dd
end

-- ############################################################
-- ## Scroll Container Component
-- ############################################################
function WarbandStorage.UI:CreateScrollContainer(parent)
  local width = 610 -- parent:GetWidth() - 20
  -- local scrollContainer = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "scrollContainer", width, height)
  -- scrollContainer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 40, -40)
  -- scrollContainer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 40, 0)
  
  local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
  
  local scrollChild = CreateFrame("Frame")
  scrollChild:SetSize(width, 1)
  scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 8, 0)
  scrollChild:SetPoint("RIGHT", scrollFrame, "RIGHT", 8, 0)
  scrollFrame:SetScrollChild(scrollChild)
  
  local scrollBar = scrollFrame.ScrollBar
  local scrollBarXOffset = -20
  local scrollBarVerticalOffset =  18
  scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", scrollBarXOffset, -scrollBarVerticalOffset)
  scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", scrollBarXOffset, -8)
  scrollBar:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
  scrollBar:Show()

  return  scrollFrame, scrollChild
end
