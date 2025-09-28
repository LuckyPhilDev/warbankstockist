local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- ############################################################
-- ## Assignments Tab Content
-- ############################################################
function WarbandStorage.UI:CreateAssignmentsSection(parent)
  local vertPadding, horzPadding = 10, 10

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", 560, 80)
  block:SetPoint("TOPLEFT", parent, "TOPLEFT")
  block:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")
  block:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
  
  local header = self:CreateAssignmentsHeader(block)
  header:SetPoint("TOPLEFT", block, "TOPLEFT")
  header:SetPoint("RIGHT", block, "RIGHT")

  -- Create scroll container for assignments positioned below title
  local scrollContainer, scrollChild = self:CreateScrollContainer(block)
  scrollContainer:ClearAllPoints()
  scrollContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -30)
  scrollContainer:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -10, 0)
  -- scrollChild:SetSize(520, 1)
  WarbandStorage.assignParent = scrollChild

  RefreshAssignmentsList()
  return block
end

-- ############################################################
-- ## Tracked Items Header Component
-- ############################################################
function WarbandStorage.UI:CreateAssignmentsHeader(parent)
  local vertPadding, horzPadding = 10, 10
  local sectionSpacing = 10

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel",300,35)

  local sectionTitle = CreateSectionHeader(block, STRINGS.SECTION_ASSIGNMENTS)
  sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, -vertPadding)

  -- Tracked items section - aligned with other sections
  -- local sectionTitle = CreateSectionHeader(block, STRINGS.STR_SECTION_ASSIGNMENTS)
  -- sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, vertPadding)
  -- sectionTitle:SetPoint("TOPRIGHT", block, "TOPRIGHT", -horzPadding, vertPadding)

  local header = CreateFrame("Frame", nil, parent)
  header:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -sectionSpacing)
  header:SetPoint("RIGHT", block, "RIGHT", -horzPadding, 0)
  local headerBg = header:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints()
  headerBg:SetColorTexture(0.2, 0.2, 0.25, 0.6)

  local itemHeader = CreateSubheadingText(header, STRINGS.ASSIGN_CHARACTERS)
  itemHeader:SetPoint("LEFT", header, "LEFT", 30, 0)

  local qtyHeader = CreateSubheadingText(header, STRINGS.ASSIGN_PROFILES)
  qtyHeader:SetPoint("LEFT", itemHeader, "RIGHT", 180, 0)

  header:SetSize(500, 28)

  return block
end

-- ############################################################
-- ## Character Assignments List
-- ############################################################
function RefreshAssignmentsList()
  if not WarbandStorage.assignParent then return end
  for _, row in ipairs(WarbandStorage.assignRows or {}) do row:Hide() end
  WarbandStorage.assignRows = {}

  local y = -8 -- Start with more padding from top
  local index = 0
  for _, ck in ipairs(WarbandStorage:GetAllCharacterKeys()) do
    local row = CreateFrame("Frame", nil, WarbandStorage.assignParent)
    row:SetSize(560, 32)                                              
    row:SetPoint("TOPLEFT", WarbandStorage.assignParent, "TOPLEFT", 0, y) 


  local nameFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
    nameFS:SetPoint("LEFT", row, "LEFT", 12, 0) -- More left padding for text
    nameFS:SetWidth(220)                        -- Slightly wider for character names
    nameFS:SetJustifyH("LEFT")

    local display = WarbandStorage.Utils:FormatCharacterName(ck)
    nameFS:SetText(display)

    -- Ignore button
    local igBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    igBtn:SetSize(70, 24)
    igBtn:SetText(STRINGS.IGNORE)
    igBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    igBtn:SetScript("OnClick", function()
      WarbandStorage.ProfileManager:IgnoreCharacter(ck)
    end)

    local unBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    unBtn:SetSize(80, 24)
    unBtn:SetText(STRINGS.UNASSIGN)
    unBtn:SetPoint("RIGHT", igBtn, "LEFT", -5, 0)
    unBtn:SetScript("OnClick", function()
      WarbandStorage.ProfileManager:UnassignCharacter(ck)
      RefreshDD()
    end)


    local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 150)
    local function RefreshDD()
      UIDropDownMenu_Initialize(dd, function(frame, level)
        -- Unassigned option
        do
          local info = UIDropDownMenu_CreateInfo()
          info.text = STRINGS.UNASSIGNED
          info.func = function()
            WarbandStorage.ProfileManager:UnassignCharacter(ck)
            UIDropDownMenu_SetText(dd, STRINGS.UNASSIGNED)
          end
          info.checked = (WarbandStockistDB.assignments[ck] == nil)
          UIDropDownMenu_AddButton(info, level)
        end

        -- All profile options
        for _, pname in ipairs(WarbandStorage:GetAllProfileNames()) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = pname
          info.func = function()
            WarbandStorage.ProfileManager:AssignProfile(ck, pname)
            UIDropDownMenu_SetText(dd, pname)
          end
          info.checked = (pname == WarbandStockistDB.assignments[ck])
          UIDropDownMenu_AddButton(info, level)
        end
      end)
      local assigned = WarbandStockistDB.assignments[ck]
      if assigned == nil then
        UIDropDownMenu_SetText(dd, STRINGS.UNASSIGNED)
      else
        UIDropDownMenu_SetText(dd, assigned)
      end
    end
    dd.Refresh = RefreshDD; RefreshDD()
    dd:SetPoint("RIGHT", unBtn, "LEFT", 10, 0) 


    -- Grey out ignored rows
    if WarbandStockistDB.ignoredCharacters and WarbandStockistDB.ignoredCharacters[ck] then
      if row:GetRegions() then
        -- overlay tint for greyed-out effect
        local overlay = row:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints()
        overlay:SetColorTexture(0.1, 0.1, 0.1, 0.5)
      end
      nameFS:SetTextColor(0.6, 0.6, 0.6, 1)
    end
    row:SetPoint("TOPLEFT", WarbandStorage.assignParent, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", WarbandStorage.assignParent, "TOPRIGHT", -20, y)

    -- Add alternating row background with rounded corners effect
    if index % 2 == 1 then
      local bg = row:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.15, 0.15, 0.2, 0.4)
    end

    table.insert(WarbandStorage.assignRows, row)
    y = y - 36 -- Match the new row height (32) plus some spacing
    index = index + 1
  end

  WarbandStorage.assignParent:SetHeight(-y + 20) -- More bottom padding
end

-- ############################################################
-- ## Profile Dropdown Refresh
-- ############################################################
function WarbandStorage.RefreshProfileDropdown()
  if WarbandStorage.activeProfileDrop and WarbandStorage.activeProfileDrop.Refresh then
    WarbandStorage.activeProfileDrop:Refresh()
  end
end
