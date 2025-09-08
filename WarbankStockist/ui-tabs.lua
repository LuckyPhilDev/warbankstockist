-- Warband Stockist — Tab System & Lists
-- Contains the main UI tabs, item lists, and assignment lists

-- Ensure namespace
WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

-- Get theme references
local THEME_COLORS = WarbandStorage.Theme.COLORS
local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- Storage for UI elements
WarbandStorage.assignRows = WarbandStorage.assignRows or {}
WarbandStorage.assignParent = WarbandStorage.assignParent or nil
WarbandStorage.scrollItems = WarbandStorage.scrollItems or {}
WarbandStorage.scrollParent = WarbandStorage.scrollParent or nil
WarbandStorage.activeProfileDrop = nil

-- ############################################################
-- ## Item List Management
-- ############################################################
function RefreshItemList()
  local profile = WarbandStorage:GetActiveProfile()
  local stock = profile.items
  for _, row in ipairs(WarbandStorage.scrollItems or {}) do row:Hide() end
  WarbandStorage.scrollItems = {}

  local y = -4
  local index = 0
  for itemID, count in pairs(stock) do
    local row = CreateFrame("Frame", nil, WarbandStorage.scrollParent)
    row:SetSize(530, 28)
    row:SetPoint("TOPLEFT", WarbandStorage.scrollParent, "TOPLEFT", 0, y)

    if index % 2 == 1 then
      local bg = row:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.15, 0.15, 0.2, 0.4)
    end

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    local itemIcon = select(5, GetItemInfoInstant(itemID))
    if itemIcon then 
      icon:SetTexture(itemIcon) 
      -- Add border to icon
      local border = row:CreateTexture(nil, "OVERLAY")
      border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
      border:SetSize(26, 26)
      border:SetPoint("CENTER", icon, "CENTER")
      border:SetVertexColor(0.6, 0.6, 0.6, 1)
    end
    icon:SetDesaturated(count == 0)
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function() 
      GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(itemID)
      GameTooltip:Show() 
    end)
    icon:SetScript("OnLeave", GameTooltip_Hide)

    local label = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
    label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    label:SetWidth(250)
    label:SetJustifyH("LEFT")

    local itemName = WarbandStorage.Utils:GetItemName(itemID)
    local itemText = ("%s (ID: %d)"):format(itemName, itemID)
    if count == 0 then
      label:SetText("|cff666666" .. itemText .. "|r")
    else
      label:SetText("|cffcccccc" .. itemText .. "|r")
    end

    local qtyBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    qtyBox:SetSize(50, 22)
    qtyBox:SetPoint("LEFT", label, "RIGHT", 15, 0)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetText(tostring(count))
    qtyBox:SetScript("OnEnterPressed", function(self)
      local val = tonumber(self:GetText())
      if val ~= nil then 
        WarbandStorage.ProfileManager:AddItemToProfile(itemID, val)
      end
      self:ClearFocus()
    end)
    qtyBox:SetScript("OnEscapePressed", function(self) 
      self:SetText(tostring(count))
      self:ClearFocus() 
    end)

    local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeBtn:SetSize(70, 20)
    removeBtn:SetText(STRINGS.BUTTON_REMOVE)
    removeBtn:SetPoint("LEFT", qtyBox, "RIGHT", 15, 0)
    removeBtn:SetScript("OnClick", function()
      WarbandStorage.ProfileManager:RemoveItemFromProfile(itemID)
    end)

    table.insert(WarbandStorage.scrollItems, row)
    y = y - 28
    index = index + 1
  end

  WarbandStorage.scrollParent:SetHeight(-y + 10)
end

-- ############################################################
-- ## Character Assignments List
-- ############################################################
function RefreshAssignmentsList()
  if not WarbandStorage.assignParent then return end
  for _, row in ipairs(WarbandStorage.assignRows or {}) do row:Hide() end
  WarbandStorage.assignRows = {}

  local y = -8  -- Start with more padding from top
  local index = 0
  for _, ck in ipairs(WarbandStorage:GetAllCharacterKeys()) do
    local row = CreateFrame("Frame", nil, WarbandStorage.assignParent)
    row:SetSize(520, 32)  -- Slightly taller rows for better spacing
    row:SetPoint("TOPLEFT", WarbandStorage.assignParent, "TOPLEFT", 12, y)  -- More left padding
    
    -- Add alternating row background with rounded corners effect
    if index % 2 == 1 then
      local bg = row:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.15, 0.15, 0.2, 0.4)
    end

    local nameFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
    nameFS:SetPoint("LEFT", row, "LEFT", 12, 0)  -- More left padding for text
    nameFS:SetWidth(220)  -- Slightly wider for character names
    nameFS:SetJustifyH("LEFT")

    local display = WarbandStorage.Utils:FormatCharacterName(ck)
    nameFS:SetText(display)

    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 150)
    local function RefreshDD()
      UIDropDownMenu_Initialize(dd, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, pname in ipairs(WarbandStorage:GetAllProfileNames()) do
          info.text = pname
          info.func = function()
            WarbandStorage:EnsureProfile(pname)
            WarbandStockistDB.assignments[ck] = pname
            UIDropDownMenu_SetText(dd, pname)
            if ck == WarbandStorage:GetCharacterKey() then
              RefreshItemList()
              if WarbandStorage.activeProfileDrop then
                UIDropDownMenu_SetText(WarbandStorage.activeProfileDrop, pname)
                if WarbandStorage.activeProfileDrop.Refresh then 
                  WarbandStorage.activeProfileDrop:Refresh() 
                end
              end
            end
          end
          info.checked = (pname == (WarbandStockistDB.assignments[ck] or WarbandStockistDB.defaultProfile))
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      UIDropDownMenu_SetText(dd, WarbandStockistDB.assignments[ck] or WarbandStockistDB.defaultProfile)
    end
    dd.Refresh = RefreshDD; RefreshDD()
    dd:SetPoint("LEFT", nameFS, "RIGHT", 20, 0)  -- More space between name and dropdown

    local unBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    unBtn:SetSize(80, 24)  -- Slightly larger button
    unBtn:SetText(STRINGS.UNASSIGN)
    unBtn:SetPoint("LEFT", dd, "RIGHT", 15, 0)  -- More space between dropdown and button
    unBtn:SetScript("OnClick", function()
      WarbandStockistDB.assignments[ck] = nil
      RefreshDD()
      if ck == WarbandStorage:GetCharacterKey() then RefreshItemList() end
    end)

    table.insert(WarbandStorage.assignRows, row)
    y = y - 36  -- Match the new row height (32) plus some spacing
    index = index + 1
  end

  WarbandStorage.assignParent:SetHeight(-y + 20)  -- More bottom padding
end

-- ############################################################
-- ## Profile Dropdown Refresh
-- ############################################################
function WarbandStorage.RefreshProfileDropdown()
  if WarbandStorage.activeProfileDrop and WarbandStorage.activeProfileDrop.Refresh then
    WarbandStorage.activeProfileDrop:Refresh()
  end
end

-- ############################################################
-- ## Assignments Tab Content
-- ############################################################
function WarbandStorage.UI:CreateAssignmentsSection(parent, anchor)
  -- Create section title properly positioned within the parent
  local title = parent:CreateFontString(nil, "OVERLAY", FONTS.SECTION)
  title:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -15)
  title:SetText(STRINGS.SECTION_ASSIGNMENTS)
  title:SetTextColor(0.9, 0.8, 0.4, 1)

  -- Create scroll container for assignments positioned below title
  local scrollContainer, scrollFrame, scrollChild = self:CreateScrollContainer(parent, title, 560, 280)
  scrollContainer:ClearAllPoints()
  scrollContainer:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 10, -10)
  scrollChild:SetSize(520, 1)
  WarbandStorage.assignParent = scrollChild

  RefreshAssignmentsList()
  return scrollContainer
end

-- ############################################################
-- ## Profiles Tab Content
-- ############################################################
function WarbandStorage.UI:CreateProfilesTabContent(tabContent, contentWidth)
  local margin = 10
  local sectionSpacing = -15
  
  -- Profile controls at top
  local profileBlock = self:CreateProfileControls(tabContent, tabContent)
  profileBlock:SetPoint("TOPLEFT", tabContent, "TOPLEFT", margin, sectionSpacing)
  
  -- Input row for adding items - aligned with profile block
  local itemInput, qtyInput = self:CreateInputRow(tabContent, profileBlock)
  itemInput:ClearAllPoints()
  itemInput:SetPoint("TOPLEFT", profileBlock, "BOTTOMLEFT", 0, sectionSpacing)
  
  -- Tracked items section - aligned with other sections
  local sectionTitle = tabContent:CreateFontString(nil, "OVERLAY", FONTS.SECTION)
  sectionTitle:SetPoint("TOPLEFT", itemInput, "BOTTOMLEFT", 0, sectionSpacing)
  sectionTitle:SetText(STRINGS.SECTION_TRACKED)
  sectionTitle:SetTextColor(0.9, 0.8, 0.4, 1)
  
  local header = self:CreateTrackedItemsHeader(tabContent, itemInput)
  
  -- Create scroll container for tracked items - aligned properly
  local scrollContainer, scrollFrame, scrollChild = self:CreateScrollContainer(tabContent, sectionTitle, contentWidth-20, 130)
  scrollContainer:ClearAllPoints()
  scrollContainer:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, sectionSpacing)
  WarbandStorage.scrollParent = scrollChild
  
  return profileBlock
end
