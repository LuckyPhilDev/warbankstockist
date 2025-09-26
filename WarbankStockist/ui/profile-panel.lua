
-- Ensure namespace and SavedVariables
WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

-- Get theme references
local THEME_COLORS = WarbandStorage.Theme.COLORS
local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- ############################################################
-- ## Profiles Tab Content
-- ############################################################
function WarbandStorage.UI:CreateProfilesTabContent(parent)
  local margin = 10
  local sectionSpacing = -15
  local width = 560
  
  -- Profile controls at top
  local profileBlock = self:ProfileControls(parent, width) 
  profileBlock:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  profileBlock:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  
  -- Input row for adding items - aligned with profile block
  local itemInput = self:InputSection(parent, width, 70)
  itemInput:SetPoint("TOPLEFT", profileBlock, "BOTTOMLEFT", 0, sectionSpacing)
  itemInput:SetPoint("TOPRIGHT", profileBlock, "BOTTOMRIGHT", 0, sectionSpacing)
  
  local header = self:CreateTrackedItemsHeader(parent, width, 45)
  header:SetPoint("TOPLEFT", itemInput, "BOTTOMLEFT", 0, sectionSpacing)
  header:SetPoint("TOPRIGHT", itemInput, "BOTTOMRIGHT", 0, sectionSpacing)
  
  -- Create scroll container for tracked items - aligned properly
  local scrollContainer, scrollChild = self:CreateScrollContainer(parent)
  scrollContainer:ClearAllPoints()
  scrollContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0) -- TODO Temporary offset, will be adjusted
  scrollContainer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 0)
  WarbandStorage.scrollParent = scrollChild
  
  return profileBlock
end



-- ############################################################
-- ## Profile Controls
-- ############################################################
function WarbandStorage.UI:ProfileControls(parent, width)
  local vertPadding, horzPadding = 10, 10
  local vertSpacing = 10
  local buttonSpacing = 5
  local buttonHeight = 22

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", width, 80)
  block:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  block:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  block:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

  --   "Profiles"
  local sectionTitle = CreateSectionHeader(block, STRINGS.SECTION_PROFILE)
  sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, -vertPadding)

  --   "Active profile:"
  local activeLabel = CreateDefaultText(block, STRINGS.PROFILE_LABEL)
  activeLabel:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -vertSpacing)

  --   Profile dropdown
  local dropdown = self:CreateDropdown(block, 180)
  dropdown:SetPoint("LEFT", activeLabel, "RIGHT", -12, 0)
  WarbandStorage.activeProfileDrop = dropdown

  -- CRUD buttons
  local newBtn = CreateButton(block, STRINGS.PROFILE_NEW, 65, buttonHeight)
  newBtn:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 0, -vertSpacing)

  local renameBtn = CreateButton(block, STRINGS.PROFILE_RENAME, 75, buttonHeight)
  renameBtn:SetPoint("LEFT", newBtn, "RIGHT", buttonSpacing, 0)

  local dupBtn = CreateButton(block, STRINGS.PROFILE_DUPLICATE, 85, buttonHeight)
  dupBtn:SetPoint("LEFT", renameBtn, "RIGHT", buttonSpacing, 0)

  local delBtn = CreateButton(block, STRINGS.PROFILE_DELETE, 75, buttonHeight)
  delBtn:SetPoint("LEFT", dupBtn, "RIGHT", buttonSpacing, 0)

  -- Profile management popup dialogs
  self:SetupProfileDialogs()
  self:SetupProfileButtons(newBtn, renameBtn, dupBtn, delBtn)

  return block, dropdown
end


-- ############################################################
-- ## Profile Dialog Setup
-- ############################################################
function WarbandStorage.UI:SetupProfileDialogs()
  -- Helper to read the popup edit box across game versions
  local function PopupEditBox(self)
    return (self and (self.editBox or self.EditBox or _G[self:GetName() .. "EditBox"]))
  end

  StaticPopupDialogs["WBSTOCKIST_NEW_PROFILE"] = StaticPopupDialogs["WBSTOCKIST_NEW_PROFILE"] or {
    text = "Enter new profile name:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
      local eb = PopupEditBox(self); if eb then
        eb:SetText("")
        eb:SetFocus()
      end
    end,
    OnAccept = function(self)
      local eb = PopupEditBox(self)
      local name = eb and eb:GetText() or nil
      if WarbandStorage.Utils:ValidateProfileName(name) then
        WarbandStorage.ProfileManager:CreateProfile(name)
        WarbandStorage:SetActiveProfileForChar(name)
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }

  StaticPopupDialogs["WBSTOCKIST_RENAME_PROFILE"] = StaticPopupDialogs["WBSTOCKIST_RENAME_PROFILE"] or {
    text = "Rename profile:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
      local eb = PopupEditBox(self); if eb then
        local base = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
        eb:SetText(base); eb:HighlightText(); eb:SetFocus();
      end
    end,
    OnAccept = function(self)
      local eb = PopupEditBox(self)
      local newName = eb and eb:GetText() or nil
      local oldName = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
      if WarbandStorage.Utils:ValidateProfileName(newName) and newName ~= oldName then
        WarbandStorage.ProfileManager:RenameProfile(oldName, newName)
        if WarbandStorage.SetEditedProfileName then
          WarbandStorage:SetEditedProfileName(newName)
        else
          WarbandStorage:SetActiveProfileForChar(newName)
        end
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
end

-- ############################################################
-- ## Profile Button Setup
-- ############################################################
function WarbandStorage.UI:SetupProfileButtons(newBtn, renameBtn, dupBtn, delBtn)
  newBtn:SetScript("OnClick", function()
    StaticPopup_Show("WBSTOCKIST_NEW_PROFILE")
  end)

  renameBtn:SetScript("OnClick", function()
    StaticPopup_Show("WBSTOCKIST_RENAME_PROFILE")
  end)

  dupBtn:SetScript("OnClick", function()
    local curName = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
    local copyName = curName .. " Copy"
    WarbandStorage.ProfileManager:DuplicateProfile(curName, copyName)
    if WarbandStorage.SetEditedProfileName then
      WarbandStorage:SetEditedProfileName(copyName)
    else
      WarbandStorage:SetActiveProfileForChar(copyName)
    end
  end)

  delBtn:SetScript("OnClick", function()
    local curProfile, curName
    if WarbandStorage.GetEditedProfile then
      curProfile, curName = WarbandStorage:GetEditedProfile()
    else
      curProfile, curName = WarbandStorage:GetActiveProfile()
    end
    if curName == WarbandStockistDB.defaultProfile then
      UIErrorsFrame:AddMessage("Cannot delete the default profile.", 1, 0.2, 0.2)
      return
    end
    StaticPopupDialogs["WBSTOCKIST_DELETE_PROFILE"] = {
      text = "Delete profile '%s'? This cannot be undone.",
      button1 = OKAY,
      button2 = CANCEL,
      OnAccept = function()
        WarbandStockistDB.profiles[curName] = nil
        for ck, pn in pairs(WarbandStockistDB.assignments) do
          if pn == curName then
            WarbandStockistDB.assignments[ck] =
                WarbandStockistDB.defaultProfile
          end
        end
        WarbandStorage.RefreshProfileDropdown()
        if WarbandStorage.SetEditedProfileName then
          WarbandStorage:SetEditedProfileName(WarbandStockistDB.defaultProfile)
        else
          WarbandStorage:SetActiveProfileForChar(WarbandStockistDB.defaultProfile)
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("WBSTOCKIST_DELETE_PROFILE", curName)
  end)
end

-- ############################################################
-- ## Input Row Component (Add/Clear)
-- ############################################################
function WarbandStorage.UI:InputSection(parent, width, height)
  local vertPadding, horzPadding = 10, 10
  local editSpacing = 10
  local fieldSpacing = 130

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", width, height)

  local inputSectionTitle = CreateSectionHeader(block, STRINGS.SECTION_ADD_ITEM)
  inputSectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, -vertPadding)

  local itemLabel = CreateDefaultText(block, STRINGS.LABEL_ITEM_ID)
  itemLabel:SetPoint("TOPLEFT", inputSectionTitle, "BOTTOMLEFT", 0, -10)

  local itemInput = CreateNumericEditText(block, STRINGS.LABEL_ITEM_ID_TOOLTIP, 100, 22)
  itemInput:SetPoint("LEFT", itemLabel, "RIGHT", editSpacing, 0)
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
  
  local qtyLabel = CreateDefaultText(block, STRINGS.LABEL_QTY)
  qtyLabel:SetPoint("LEFT", itemLabel, "RIGHT", fieldSpacing, 0)

  local qtyInput = CreateNumericEditText(block, STRINGS.LABEL_QTY_TOOLTIP, 60, 22)
  qtyInput:SetPoint("LEFT", qtyLabel, "RIGHT", editSpacing, 0)

  local addButton = CreateButton(block, STRINGS.BUTTON_ADD, 50, 22)
  addButton:SetPoint("LEFT", qtyInput, "RIGHT", 15, 0)
  addButton:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(STRINGS.BUTTON_ADD_TOOLTIP, 1, 1, 1)
    GameTooltip:Show() 
  end)
  addButton:SetScript("OnLeave", GameTooltip_Hide)

  local clearButton = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
  clearButton:SetSize(90, 22)
  clearButton:SetText(STRINGS.BUTTON_CLEAR)
  clearButton:SetPoint("TOPLEFT", addButton, "TOPRIGHT", 15, 0)
  clearButton:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
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
      local pname = WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName() or WarbandStorage:GetActiveProfileName()
      WarbandStorage.ProfileManager:AddItemToProfile(itemID, qty, pname)
      itemInput:SetText("")
      qtyInput:SetText("")
      WarbandStorage.ProfileManager:RefreshUI()
    else
      WarbandStorage:DebugPrint("Invalid item ID or quantity.")
    end
  end)

  clearButton:SetScript("OnClick", function()
    local pname = WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName() or WarbandStorage:GetActiveProfileName()
    WarbandStorage.ProfileManager:ClearProfileItems(pname)
  end)

  return block
end


-- ############################################################
-- ## Tracked Items Header Component
-- ############################################################
function WarbandStorage.UI:CreateTrackedItemsHeader(parent, width, height)
  local vertPadding, horzPadding = 10, 10
  local sectionSpacing = 10

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", width, height)

  -- Tracked items section - aligned with other sections
  local sectionTitle = CreateSectionHeader(block, STRINGS.SECTION_TRACKED)
  sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, vertPadding)
  -- sectionTitle:SetPoint("TOPRIGHT", block, "TOPRIGHT", -horzPadding, vertPadding)

  local header = CreateFrame("Frame", nil, parent)
  header:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -sectionSpacing)
  header:SetPoint("RIGHT", block, "RIGHT", -horzPadding, 0)
  local headerBg = header:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints()
  headerBg:SetColorTexture(0.2, 0.2, 0.25, 0.6)

  local itemHeader = CreateSubheadingText(header, "Item")
  itemHeader:SetPoint("LEFT", header, "LEFT", 30, 0)

  local qtyHeader = CreateSubheadingText(header, "Qty")
  qtyHeader:SetPoint("LEFT", itemHeader, "RIGHT", 390, 0)

  header:SetSize(width, 28)

  return block
end