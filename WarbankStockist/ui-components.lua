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
-- ## Input Row Component (Add/Clear)
-- ############################################################
function WarbandStorage.UI:CreateInputRow(parent, anchor)
  local bg = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", 540, 85)
  bg:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)

  local totalHeight = 0

  local inputSectionTitle = bg:CreateFontString(nil, "OVERLAY", FONTS.SECTION)
  inputSectionTitle:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -12)
  inputSectionTitle:SetText(STRINGS.SECTION_ADD_ITEM)
  inputSectionTitle:SetTextColor(0.9, 0.8, 0.4, 1)
  totalHeight = totalHeight + 22

  local itemLabel = bg:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
  itemLabel:SetText(STRINGS.LABEL_ITEM_ID)
  itemLabel:SetPoint("TOPLEFT", inputSectionTitle, "BOTTOMLEFT", 0, -10)
  itemLabel:SetTextColor(0.8, 0.8, 0.8, 1)
  totalHeight = totalHeight + 20

  local itemInput = CreateFrame("EditBox", nil, bg, "InputBoxTemplate")
  itemInput:SetSize(100, 22)
  itemInput:SetAutoFocus(false)
  itemInput:SetNumeric(true)
  itemInput:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -4)

  -- Drag-and-drop item link
  itemInput:SetScript("OnReceiveDrag", function(self)
    local type, itemID, link = GetCursorInfo()
    if type == "item" then
      local extractedID = tonumber((link and link:match("item:(%d+)")) or itemID)
      if extractedID then 
        self:SetText(tostring(extractedID))
        ClearCursor() 
      end
    end
  end)
  itemInput:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.LABEL_ITEM_ID_TOOLTIP, 1,1,1)
    GameTooltip:Show() 
  end)
  itemInput:SetScript("OnLeave", GameTooltip_Hide)

  local qtyLabel = bg:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
  qtyLabel:SetText(STRINGS.LABEL_QTY)
  qtyLabel:SetPoint("TOPLEFT", itemLabel, "TOPRIGHT", 130, 0)
  qtyLabel:SetTextColor(0.8, 0.8, 0.8, 1)

  local qtyInput = CreateFrame("EditBox", nil, bg, "InputBoxTemplate")
  qtyInput:SetSize(60, 22)
  qtyInput:SetAutoFocus(false)
  qtyInput:SetNumeric(true)
  qtyInput:SetPoint("TOPLEFT", qtyLabel, "BOTTOMLEFT", 0, -4)
  qtyInput:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.LABEL_QTY_TOOLTIP, 1,1,1)
    GameTooltip:Show() 
  end)
  qtyInput:SetScript("OnLeave", GameTooltip_Hide)

  local addButton = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
  addButton:SetSize(50, 22)
  addButton:SetText(STRINGS.BUTTON_ADD)
  addButton:SetPoint("TOPLEFT", qtyInput, "TOPRIGHT", 15, 0)
  addButton:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.BUTTON_ADD_TOOLTIP, 1,1,1)
    GameTooltip:Show() 
  end)
  addButton:SetScript("OnLeave", GameTooltip_Hide)

  local clearButton = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
  clearButton:SetSize(90, 22)
  clearButton:SetText(STRINGS.BUTTON_CLEAR)
  clearButton:SetPoint("TOPLEFT", addButton, "TOPRIGHT", 15, 0)
  clearButton:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.BUTTON_CLEAR_TOOLTIP, 1,1,1)
    GameTooltip:Show() 
  end)
  clearButton:SetScript("OnLeave", GameTooltip_Hide)

  -- Chat link insertion support
  hooksecurefunc("ChatEdit_InsertLink", function(link)
    if itemInput:HasFocus() then
      local itemID = tonumber((link and link:match("item:(%d+)")))
      if itemID then 
        itemInput:SetText(tostring(itemID))
        itemInput:ClearFocus() 
      end
    end
  end)

  -- Button click handlers
  addButton:SetScript("OnClick", function()
    local itemID = tonumber(itemInput:GetText())
    local qty = tonumber(qtyInput:GetText())
    if WarbandStorage.Utils:ValidateItemInput(itemID, qty) then
      WarbandStorage.ProfileManager:AddItemToProfile(itemID, qty)
      itemInput:SetText("")
      qtyInput:SetText("")
      WarbandStorage.ProfileManager:RefreshUI()
    else
      WarbandStorage:DebugPrint("Invalid item ID or quantity.")
    end
  end)

  clearButton:SetScript("OnClick", function()
    WarbandStorage.ProfileManager:ClearProfileItems()
  end)

  return itemInput, qtyInput, bg
end

-- ############################################################
-- ## Tracked Items Header Component
-- ############################################################
function WarbandStorage.UI:CreateTrackedItemsHeader(parent, anchor)
  local header = CreateFrame("Frame", nil, parent)
  header:SetSize(570, 28)
  header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)

  -- Add header background
  local headerBg = header:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints()
  headerBg:SetColorTexture(0.2, 0.2, 0.25, 0.6)

  local itemHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  itemHeader:SetText("Item")
  itemHeader:SetPoint("LEFT", header, "LEFT", 30, 0)
  itemHeader:SetTextColor(0.9, 0.8, 0.4, 1)

  local qtyHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  qtyHeader:SetText("Qty")
  qtyHeader:SetPoint("LEFT", itemHeader, "RIGHT", 270, 0)
  qtyHeader:SetTextColor(0.9, 0.8, 0.4, 1)

  return header
end

-- ############################################################
-- ## Scroll Container Component
-- ############################################################
function WarbandStorage.UI:CreateScrollContainer(parent, anchor, width, height)
  local scrollContainer = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "scrollContainer", width, height)
  scrollContainer:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
  
  local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 8, -8)
  scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -8, 8)
  
  local scrollChild = CreateFrame("Frame")
  scrollChild:SetSize(width - 40, 1)
  scrollFrame:SetScrollChild(scrollChild)
  
  local scrollBar = scrollFrame.ScrollBar
  scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -16, -18)
  scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -16, 18)
  scrollBar:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
  scrollBar:Show()

  return scrollContainer, scrollFrame, scrollChild
end
