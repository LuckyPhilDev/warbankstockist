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
function WarbandStorage.UI:CreateScrollContainer(parent, anchor, width, height)
  local scrollContainer = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "scrollContainer", width, height)
  scrollContainer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 40, -40)
  -- scrollContainer:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 40, 0)
  
  local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 8, -8)
  scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -8, 8)
  
  local scrollChild = CreateFrame("Frame")
  scrollChild:SetSize(width - 40, 1)
  scrollFrame:SetScrollChild(scrollChild)
  
  local scrollBar = scrollFrame.ScrollBar
  local scrollBarXOffset = -20
  local scrollBarVerticalOffset = 18
  scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", scrollBarXOffset, -scrollBarVerticalOffset)
  scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", scrollBarXOffset, scrollBarVerticalOffset)
  scrollBar:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
  scrollBar:Show()

  return scrollContainer, scrollFrame, scrollChild
end
