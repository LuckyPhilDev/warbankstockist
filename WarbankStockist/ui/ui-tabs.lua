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
    
    local row = createRow(WarbandStorage.scrollParent, index % 2 == 1, itemID, count)

    local row2 = CreateFrame("Frame", nil, WarbandStorage.scrollParent)
    row:SetSize(200, 28)
    row:SetPoint("TOPLEFT", WarbandStorage.scrollParent, "TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", WarbandStorage.scrollParent, "TOPRIGHT", 0, y)
   
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
function WarbandStorage.UI:CreateAssignmentsSection(parent)
  
  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", 560, 100)
  block:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 0)

  local vPadding = -15
  -- Create section title properly positioned within the parent
  local title = block:CreateFontString(nil, "OVERLAY", FONTS.SECTION)
  title:SetPoint("TOPLEFT", block, "TOPLEFT", 10, vPadding)
  title:SetText(STRINGS.SECTION_ASSIGNMENTS)
  title:SetTextColor(0.9, 0.8, 0.4, 1)

  -- Create scroll container for assignments positioned below title
  local scrollContainer, scrollChild = self:CreateScrollContainer(block, title, 560, 280)
  scrollContainer:ClearAllPoints()
  scrollContainer:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 10, -30)
  scrollChild:SetSize(520, 1)
  WarbandStorage.assignParent = scrollChild

  RefreshAssignmentsList()
  return block
end

