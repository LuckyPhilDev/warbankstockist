WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

local FONTS = WarbandStorage.Theme.FONTS
local S = WarbandStorage.Strings

-- ############################################################
-- ## Profiles Tab Content
-- ############################################################
function WarbandStorage.UI:CreateProfilesTabContent(parent)
  local sectionSpacing = -4
  local width = 560
  
  local profileBlock = self:ProfileControls(parent, width)
  profileBlock:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  profileBlock:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)

  local itemInput = self:InputSection(parent, width, 52)
  itemInput:SetPoint("TOPLEFT", profileBlock, "BOTTOMLEFT", 0, sectionSpacing)
  itemInput:SetPoint("TOPRIGHT", profileBlock, "BOTTOMRIGHT", 0, sectionSpacing)
  
  local trackedBlock, columnHeader = self:CreateTrackedItemsHeader(parent, width, 35)
  trackedBlock:SetPoint("TOPLEFT", itemInput, "BOTTOMLEFT", 0, sectionSpacing)
  trackedBlock:SetPoint("TOPRIGHT", itemInput, "BOTTOMRIGHT", 0, sectionSpacing)

  -- Create scroll container for tracked items - list starts just below the column header bar
  local scrollContainer, scrollChild = self:CreateScrollContainer(parent)
  scrollContainer:ClearAllPoints()
  scrollContainer:SetPoint("TOPLEFT", columnHeader, "BOTTOMLEFT", -10, -4)
  scrollContainer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 10)
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
  local buttonWidth = 80
  local clusterHeight = buttonHeight * 2 + buttonSpacing

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", width, 100)
  block:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  block:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
  block:SetBackdropColor(0.1, 0.1, 0.1, 0.9)

  --   "Profiles"
  local sectionTitle = CreateSectionHeader(block, S.profiles.section)
  sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, -vertPadding)

  --   "Active profile:"
  local activeLabel = CreateDefaultText(block, S.profiles.label)
  activeLabel:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -vertSpacing)

  --   Profile dropdown
  local dropdown = self:CreateDropdown(block, 180)
  dropdown:SetPoint("LEFT", activeLabel, "RIGHT", -12, 0)
  WarbandStorage.activeProfileDrop = dropdown

  -- CRUD buttons, a 2x2 cluster beside the dropdown
  local newBtn = CreateButton(block, S.profiles.new, buttonWidth, buttonHeight)
  newBtn:SetPoint("BOTTOMLEFT", dropdown, "RIGHT", 0, 2)

  local renameBtn = CreateButton(block, S.profiles.rename, buttonWidth, buttonHeight)
  renameBtn:SetPoint("LEFT", newBtn, "RIGHT", buttonSpacing, 0)

  local dupBtn = CreateButton(block, S.profiles.duplicate, buttonWidth, buttonHeight)
  dupBtn:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -buttonSpacing)

  local delBtn = CreateButton(block, S.profiles.delete, buttonWidth, buttonHeight)
  delBtn:SetPoint("LEFT", dupBtn, "RIGHT", buttonSpacing, 0)

  -- Per-profile "Deposit Excess Items" toggle
  local depositToggle = CreateFrame("CheckButton", nil, block, "ChatConfigCheckButtonTemplate")
  -- Cleared of the cluster, which is centred on the dropdown row
  depositToggle:SetPoint("TOPLEFT", activeLabel, "BOTTOMLEFT", 0, -(clusterHeight / 2 - 6 + vertSpacing))
  depositToggle.Text:SetFontObject(FONTS.LABEL)
  depositToggle.Text:SetText(S.deposit.excess)
  depositToggle.Text:SetTextColor(0.8, 0.8, 0.8, 1)
  depositToggle:SetScript("OnClick", function(self)
    local pname = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
    WarbandStorage:SetExcessDepositEnabled(pname, self:GetChecked())
    WarbandStorage.RefreshExcessDepositToggle()
  end)
  depositToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(S.deposit.excessTooltip, 1, 1, 1)
    GameTooltip:Show()
  end)
  depositToggle:SetScript("OnLeave", GameTooltip_Hide)
  WarbandStorage.excessDepositToggle = depositToggle

  -- Per-profile "Sort Bank After Deposit" toggle, sharing the deposit row
  local sortToggle = CreateFrame("CheckButton", nil, block, "ChatConfigCheckButtonTemplate")
  sortToggle:SetPoint("LEFT", depositToggle, "LEFT", 440, 0)
  sortToggle.Text:SetFontObject(FONTS.LABEL)
  sortToggle.Text:SetText(S.deposit.sortAfter)
  sortToggle.Text:SetTextColor(0.8, 0.8, 0.8, 1)
  sortToggle:SetScript("OnClick", function(self)
    local pname = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
    WarbandStorage:SetSortAfterDepositEnabled(pname, self:GetChecked())
  end)
  sortToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(S.deposit.sortAfterTooltip, 1, 1, 1)
    GameTooltip:Show()
  end)
  sortToggle:SetScript("OnLeave", GameTooltip_Hide)
  WarbandStorage.sortAfterDepositToggle = sortToggle

  -- Per-profile "Default Qty to 0" toggle, only usable while excess deposit is on
  local defaultQtyToggle = CreateFrame("CheckButton", nil, block, "ChatConfigCheckButtonTemplate")
  defaultQtyToggle:SetPoint("LEFT", depositToggle, "LEFT", 220, 0)
  defaultQtyToggle.Text:SetFontObject(FONTS.LABEL)
  defaultQtyToggle.Text:SetText(S.deposit.defaultQtyZero)
  defaultQtyToggle:SetScript("OnClick", function(self)
    local pname = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
    WarbandStorage:SetDefaultQtyZeroEnabled(pname, self:GetChecked())
    if WarbandStorage.ResetItemInputQty then WarbandStorage.ResetItemInputQty() end
  end)
  defaultQtyToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(S.deposit.defaultQtyZeroTooltip, 1, 1, 1)
    GameTooltip:Show()
  end)
  defaultQtyToggle:SetScript("OnLeave", GameTooltip_Hide)
  WarbandStorage.defaultQtyZeroToggle = defaultQtyToggle

  -- Sync both per-profile toggles to whichever profile is being edited
  function WarbandStorage.RefreshExcessDepositToggle()
    local pname = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
    if WarbandStorage.excessDepositToggle then
      WarbandStorage.excessDepositToggle:SetChecked(WarbandStorage:IsExcessDepositEnabled(pname))
    end
    if WarbandStorage.sortAfterDepositToggle then
      WarbandStorage.sortAfterDepositToggle:SetChecked(WarbandStorage:IsSortAfterDepositEnabled(pname))
    end
    if WarbandStorage.defaultQtyZeroToggle then
      local depositing = WarbandStorage:IsExcessDepositEnabled(pname)
      WarbandStorage.defaultQtyZeroToggle:SetChecked(WarbandStorage:IsDefaultQtyZeroEnabled(pname))
      WarbandStorage.defaultQtyZeroToggle:SetEnabled(depositing)
      local shade = depositing and 0.8 or 0.4
      WarbandStorage.defaultQtyZeroToggle.Text:SetTextColor(shade, shade, shade, 1)
    end
    if WarbandStorage.ResetItemInputQty then WarbandStorage.ResetItemInputQty() end
  end
  WarbandStorage.RefreshExcessDepositToggle()

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
  local function GetPopupEditText(frame)
    local eb = frame and (frame.editBox or frame.EditBox or (frame.GetName and _G[frame:GetName() .. "EditBox"]))
    return eb and eb:GetText() or nil
  end

  -- New profile
  StaticPopupDialogs["WBSTOCKIST_NEW_PROFILE"] = {
    text = S.profiles.newPrompt,
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
      local eb = self.editBox or self.EditBox or (self.GetName and _G[self:GetName() .. "EditBox"])
      if eb then eb:SetText(""); eb:SetFocus() end
    end,
    EditBoxOnEnterPressed = function(editBox)
      local parent = editBox and editBox:GetParent()
      if parent and parent.button1 then parent.button1:Click() end
    end,
    OnAccept = function(self)
      local name = GetPopupEditText(self)
      local ok, cleaned = WarbandStorage.Utils:ValidateProfileName(name)
      if ok then
        -- Create profile without changing assignments; select it for editing in the Profiles tab
        if WarbandStorage.ProfileManager.CreateProfile then
          WarbandStorage.ProfileManager:CreateProfile(cleaned)
        end
        if WarbandStorage.SetEditedProfileName then
          WarbandStorage:SetEditedProfileName(cleaned)
        end
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }

  -- Rename profile
  StaticPopupDialogs["WBSTOCKIST_RENAME_PROFILE"] = {
    text = S.profiles.renamePrompt,
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
      local eb = self.editBox or self.EditBox or (self.GetName and _G[self:GetName() .. "EditBox"])
      if eb then
        local base = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
        eb:SetText(base); eb:HighlightText(); eb:SetFocus()
      end
    end,
    EditBoxOnEnterPressed = function(editBox)
      local parent = editBox and editBox:GetParent()
      if parent and parent.button1 then parent.button1:Click() end
    end,
    OnAccept = function(self)
      local newName = GetPopupEditText(self)
      local oldName = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
      local ok, cleaned = WarbandStorage.Utils:ValidateProfileName(newName, oldName)
      if ok and cleaned ~= oldName then
        WarbandStorage.ProfileManager:RenameProfile(oldName, cleaned)
        if WarbandStorage.SetEditedProfileName then
          WarbandStorage:SetEditedProfileName(cleaned)
        else
          WarbandStorage:SetActiveProfileForChar(cleaned)
        end
        if WarbandStorage.RefreshProfileDropdown then WarbandStorage.RefreshProfileDropdown() end
        if WarbandStorage.ProfileManager.RefreshUI then WarbandStorage.ProfileManager:RefreshUI() end
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }

  -- Confirm clearing all tracked items
  StaticPopupDialogs["WBSTOCKIST_CLEAR_PROFILE_ITEMS"] = StaticPopupDialogs["WBSTOCKIST_CLEAR_PROFILE_ITEMS"] or {
    text = S.profiles.clearPrompt,
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function()
      local pname = WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName() or WarbandStorage:GetActiveProfileName()
      WarbandStorage.ProfileManager:ClearProfileItems(pname)
      if WarbandStorage.ProfileManager.RefreshUI then WarbandStorage.ProfileManager:RefreshUI() end
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
    local curName
    if WarbandStorage.GetEditedProfile then
      _, curName = WarbandStorage:GetEditedProfile()
    else
      _, curName = WarbandStorage:GetActiveProfile()
    end
    StaticPopupDialogs["WBSTOCKIST_DELETE_PROFILE"] = {
      text = S.profiles.deletePrompt,
      button1 = OKAY,
      button2 = CANCEL,
      OnAccept = function()
        -- Use manager to delete and refresh UI consistently
        if WarbandStorage.ProfileManager and WarbandStorage.ProfileManager.DeleteProfile then
          WarbandStorage.ProfileManager:DeleteProfile(curName)
        else
          WarbandStockistDB.profiles[curName] = nil
          for ck, pn in pairs(WarbandStockistDB.assignments) do
            if pn == curName then
              WarbandStockistDB.assignments[ck] = nil
            end
          end
          if WarbandStorage.RefreshProfileDropdown then WarbandStorage.RefreshProfileDropdown() end
          if RefreshAssignmentsList then RefreshAssignmentsList() end
        end
        -- After deletion, select a remaining profile for editing, if any
        local names = WarbandStorage.GetAllProfileNames and WarbandStorage:GetAllProfileNames() or {}
        local nextName = names[1]
        if WarbandStorage.SetEditedProfileName and nextName then
          WarbandStorage:SetEditedProfileName(nextName)
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
  local vertPadding, horzPadding = 5, 10
  local editSpacing = 10
  local fieldSpacing = 130

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", width, height)

  local inputSectionTitle = CreateSectionHeader(block, S.addItem.section)
  inputSectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, -vertPadding)

  local itemLabel = CreateDefaultText(block, S.addItem.itemIdLabel)
  itemLabel:SetPoint("TOPLEFT", inputSectionTitle, "BOTTOMLEFT", 0, -10)

  local itemInput = CreateNumericEditText(block, S.addItem.itemIdTooltip, 100, 22)
  itemInput:SetPoint("LEFT", itemLabel, "RIGHT", editSpacing, 0)
  local function CaptureCursorItem(self)
    local cursorType, itemID, link = GetCursorInfo()
    if cursorType ~= "item" then return end
    local extractedID = tonumber((link and link:match("item:(%d+)")) or itemID)
    if extractedID then
      self:SetText(tostring(extractedID))
      ClearCursor()
    end
  end

  itemInput:SetScript("OnReceiveDrag", CaptureCursorItem)
  itemInput:SetScript("OnMouseDown", CaptureCursorItem)


  local qtyLabel = CreateDefaultText(block, S.addItem.qtyLabel)
  qtyLabel:SetPoint("LEFT", itemLabel, "RIGHT", fieldSpacing, 0)

  local qtyInput = CreateNumericEditText(block, S.addItem.qtyTooltip, 60, 22)
  qtyInput:SetPoint("LEFT", qtyLabel, "RIGHT", editSpacing, 0)

  function WarbandStorage.ResetItemInputQty()
    local pname = (WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName()) or WarbandStorage:GetActiveProfileName()
    qtyInput:SetText(WarbandStorage:IsDefaultQtyZeroEnabled(pname) and "0" or "")
  end
  WarbandStorage.ResetItemInputQty()

  -- Filling in an item ID re-seeds a qty the user cleared, so the one-click
  -- deposit-only flow survives an edit. Never overwrites a typed quantity.
  itemInput:SetScript("OnTextChanged", function(self)
    if self:GetText() == "" or qtyInput:GetText() ~= "" then return end
    WarbandStorage.ResetItemInputQty()
  end)

  local addButton = CreateButton(block, S.addItem.add, 50, 22)
  addButton:SetPoint("LEFT", qtyInput, "RIGHT", 15, 0)
  addButton:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(S.addItem.addTooltip, 1, 1, 1)
    GameTooltip:Show() 
  end)
  addButton:SetScript("OnLeave", GameTooltip_Hide)

  local clearButton = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
  clearButton:SetSize(90, 22)
  clearButton:SetText(S.addItem.clear)
  clearButton:SetPoint("TOPLEFT", addButton, "TOPRIGHT", 15, 0)
  clearButton:SetScript("OnEnter", function(self) 
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText(S.addItem.clearTooltip, 1,1,1)
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
      WarbandStorage.ResetItemInputQty()
      WarbandStorage.ProfileManager:RefreshUI()
    else
      WarbandStorage:DebugPrint("Invalid item ID or quantity.")
    end
  end)

  clearButton:SetScript("OnClick", function()
    local pname = WarbandStorage.GetEditedProfileName and WarbandStorage:GetEditedProfileName() or WarbandStorage:GetActiveProfileName()
    StaticPopup_Show("WBSTOCKIST_CLEAR_PROFILE_ITEMS", pname)
  end)

  return block
end


-- ############################################################
-- ## Tracked Items Header Component
-- ############################################################
function WarbandStorage.UI:CreateTrackedItemsHeader(parent, width, height)
  local vertPadding, horzPadding = 3, 10
  local sectionSpacing = 4

  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", width, height)

  local sectionTitle = CreateSectionHeader(block, S.tracked.section)
  sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", horzPadding, -vertPadding)

  -- Filter box: narrows the tracked items list by name or item ID.
  local searchBox = LuckyUI.CreateSearchBox(block, {
    width = 180,
    height = 22,
    placeholder = S.tracked.filterPlaceholder,
    onChange = function(query)
      WarbandStorage.itemFilter = query or ""
      if RefreshItemList then RefreshItemList() end
    end,
  })
  searchBox:SetPoint("TOPRIGHT", block, "TOPRIGHT", -horzPadding, -3)
  WarbandStorage.itemSearchBox = searchBox

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

  return block, header
end