-- Warband Stockist — Settings Panel
-- Main settings panel creation and profile controls

-- Ensure namespace and SavedVariables
WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

-- Ensure SavedVariables are initialized
WarbandStockistDB = WarbandStockistDB or {
  debugEnabled = false,
  defaultProfile = "Default",
  profiles = {},
  assignments = {},
  characterClasses = {}, -- Store character class info for proper coloring
}

-- Get theme references
local THEME_COLORS = WarbandStorage.Theme.COLORS
local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- ############################################################
-- ## Profile Controls
-- ############################################################
function WarbandStorage.UI:ProfileControls(parent, width)
  local vertPadding, horzPadding = 10, 10
  -- local horzPadding = 10
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
        eb:SetText(WarbandStorage:GetActiveProfileName()); eb:HighlightText(); eb:SetFocus();
      end
    end,
    OnAccept = function(self)
      local eb = PopupEditBox(self)
      local newName = eb and eb:GetText() or nil
      local oldName = WarbandStorage:GetActiveProfileName()
      if WarbandStorage.Utils:ValidateProfileName(newName) and newName ~= oldName then
        WarbandStorage.ProfileManager:RenameProfile(oldName, newName)
        WarbandStorage:SetActiveProfileForChar(newName)
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
    local curName = WarbandStorage:GetActiveProfileName()
    local copyName = curName .. " Copy"
    WarbandStorage.ProfileManager:DuplicateProfile(curName, copyName)
    WarbandStorage:SetActiveProfileForChar(copyName)
  end)

  delBtn:SetScript("OnClick", function()
    local _, curName = WarbandStorage:GetActiveProfile()
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
        WarbandStorage:SetActiveProfileForChar(WarbandStockistDB.defaultProfile)
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

  local header = CreateFrame("Frame", nil, parent)
  header:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -sectionSpacing)
  local headerBg = header:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints()
  headerBg:SetColorTexture(0.2, 0.2, 0.25, 0.6)

  local itemHeader = CreateSubheadingText(header, "Item")
  itemHeader:SetPoint("LEFT", header, "LEFT", 30, 0)

  local qtyHeader = CreateSubheadingText(header, "Qty")
  qtyHeader:SetPoint("LEFT", itemHeader, "RIGHT", 270, 0)

  header:SetSize(width, 28)

  return block
end

-- ############################################################
-- ## Main Tabbed Settings Panel
-- ############################################################
function WarbandStorage.UI:CreateTabbedSettingsCategory()
  -- Ensure functions exist before calling them
  if WarbandStorage.MigrateLegacyIfNeeded then
    WarbandStorage:MigrateLegacyIfNeeded()
  end
  WarbandStorage.ProfileManager:EnsureProfile(WarbandStockistDB.defaultProfile)

  local panel = CreateFrame("Frame", "WarbandStockistOptionsPanel", UIParent, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 150, -50)
  panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -50, 50)
  -- panel:SetSize(220, 520)

  WarbandStorage.FrameFactory:SetupDialogFrame(panel)

  local contentWidth, contentHeight = 580, 360

  -- Header elements
  local title = panel:CreateFontString(nil, "ARTWORK", FONTS.SECTION)
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
  title:SetText(STRINGS.TITLE)
  title:SetTextColor(0.9, 0.8, 0.4, 1)

  local debugCheckbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
  debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -15)
  debugCheckbox.Text:SetFontObject(FONTS.LABEL)
  debugCheckbox.Text:SetText(STRINGS.DEBUG_LABEL)
  debugCheckbox.Text:SetTextColor(0.8, 0.8, 0.8, 1)
  debugCheckbox:SetScript("OnClick", function(self)
    WarbandStockistDB.debugEnabled = self:GetChecked()
    -- Use utils.lua DebugPrint function directly
    WarbandStorage:DebugPrint("Debug logging " .. (self:GetChecked() and "enabled" or "disabled"))
  end)
  debugCheckbox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.DEBUG_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
  end)
  debugCheckbox:SetScript("OnLeave", GameTooltip_Hide)

  local helpText = panel:CreateFontString(nil, "OVERLAY", FONTS.INLINE_HINT)
  helpText:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -10)
  helpText:SetWidth(560)
  helpText:SetJustifyH("LEFT")
  helpText:SetText(STRINGS.HELP_TEXT)
  helpText:SetTextColor(0.7, 0.7, 0.7, 1)

  local depositToggle = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
  depositToggle:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -15)
  depositToggle.Text:SetFontObject(FONTS.LABEL)
  depositToggle.Text:SetText(STRINGS.ENABLE_EXCESS_DEPOSIT)
  depositToggle.Text:SetTextColor(0.8, 0.8, 0.8, 1)
  depositToggle:SetScript("OnClick", function(self)
    WarbandStorageCharData.enableExcessDeposit = self:GetChecked()
  end)
  depositToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.ENABLE_EXCESS_DEPOSIT_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
  end)
  depositToggle:SetScript("OnLeave", GameTooltip_Hide)

  -- Create tabs
  local tabs = self:CreateTabs(panel, depositToggle, contentWidth, contentHeight)

  -- Tab content - use consistent margins
  self:CreateProfilesTabContent(tabs[1].content, contentWidth)
  -- TODO alignment
  self:CreateAssignmentsSection(tabs[2].content)
  -- local assignmentsFrame =
  -- assignmentsFrame:SetAllPoints(tabs[2].content)

  -- Panel show handler
  panel:SetScript("OnShow", function()
    debugCheckbox:SetChecked(WarbandStockistDB.debugEnabled == true)
    depositToggle:SetChecked(WarbandStorageCharData.enableExcessDeposit == true)
    if WarbandStorage.RefreshProfileDropdown then
      WarbandStorage.RefreshProfileDropdown()
    end
    if RefreshAssignmentsList then
      RefreshAssignmentsList()
    end
    if RefreshItemList then
      RefreshItemList()
    end
    self:SelectTab(tabs, 1)
  end)

  WarbandStorage.SettingsCategory = Settings.RegisterCanvasLayoutCategory(panel, STRINGS.SETTINGS_NAME)
  Settings.RegisterAddOnCategory(WarbandStorage.SettingsCategory)
  -- Cache ID for reliable lookups later
  if WarbandStorage.SettingsCategory then
    local id = WarbandStorage.SettingsCategory.ID or
        (type(WarbandStorage.SettingsCategory.GetID) == "function" and WarbandStorage.SettingsCategory:GetID())
    WarbandStorage.SettingsCategoryID = id
  end
end

-- ############################################################
-- ## Tab Creation
-- ############################################################
function WarbandStorage.UI:CreateTabs(parent, anchor)
  local tabButtonSize = { width = 140, height = 32 }
  local tabs = {}
  local tabNames = { "Profiles", "Assignments" }
  local firstTab = nil

  for i, name in ipairs(tabNames) do
    local tab = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tab:SetSize(tabButtonSize.width, tabButtonSize.height)
    tab:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i - 1) * 145, -25)
    tab.label = tab:CreateFontString(nil, "OVERLAY", FONTS.TAB)
    tab.label:SetText(name)
    tab.label:SetPoint("CENTER", tab, "CENTER")
    tab:EnableMouse(true)

    -- Add hover effects
    tab:SetScript("OnEnter", function(self)
      if not self.isSelected then
        self:SetBackdropColor(THEME_COLORS.TAB_HOVER[1], THEME_COLORS.TAB_HOVER[2], THEME_COLORS.TAB_HOVER[3],
          THEME_COLORS.TAB_HOVER[4])
      end
    end)
    tab:SetScript("OnLeave", function(self)
      if not self.isSelected then
        self:SetBackdropColor(THEME_COLORS.TAB_INACTIVE[1], THEME_COLORS.TAB_INACTIVE[2], THEME_COLORS.TAB_INACTIVE[3],
          THEME_COLORS.TAB_INACTIVE[4])
      end
    end)
    tab:SetScript("OnMouseDown", function()
      for j, t in ipairs(tabs) do t.isSelected = (j == i) end
      WarbandStorage.UI:SelectTab(tabs, i)
    end)

    firstTab = firstTab or tab

    -- Content frame with better backdrop
    tab.content = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tab.content:SetPoint("TOPLEFT", firstTab, "BOTTOMLEFT", 0, -8)
    tab.content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
    tab.content:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    tab.content:SetBackdropColor(THEME_COLORS.CONTENT_BG[1], THEME_COLORS.CONTENT_BG[2], THEME_COLORS.CONTENT_BG[3],
      THEME_COLORS.CONTENT_BG[4])
    tab.content:SetBackdropBorderColor(THEME_COLORS.BORDER[1], THEME_COLORS.BORDER[2], THEME_COLORS.BORDER[3],
      THEME_COLORS.BORDER[4])
    tab.content:SetFrameLevel(parent:GetFrameLevel() + 1)
    tab.content:Hide()
    tabs[i] = tab
  end

  return tabs
end

-- ############################################################
-- ## Tab Selection
-- ############################################################
function WarbandStorage.UI:SelectTab(tabs, idx)
  for i, tab in ipairs(tabs) do
    if i == idx then
      tab:SetBackdropColor(THEME_COLORS.TAB_ACTIVE[1], THEME_COLORS.TAB_ACTIVE[2], THEME_COLORS.TAB_ACTIVE[3],
        THEME_COLORS.TAB_ACTIVE[4])
      tab:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
      tab.label:SetTextColor(1, 1, 1, 1)
      tab.content:Show()
    else
      tab:SetBackdropColor(THEME_COLORS.TAB_INACTIVE[1], THEME_COLORS.TAB_INACTIVE[2], THEME_COLORS.TAB_INACTIVE[3],
        THEME_COLORS.TAB_INACTIVE[4])
      tab:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      tab.label:SetTextColor(0.7, 0.7, 0.7, 1)
      tab.content:Hide()
    end
  end
end

-- Settings panel will be initialized later by the main addon
