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
function WarbandStorage.UI:CreateProfileControls(parent, anchor)
  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel", 560, 100)
  block:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)

  local totalHeight = 0

--   "Profiles"
  local sectionTitle = block:CreateFontString(nil, "OVERLAY", FONTS.SECTION)
  sectionTitle:SetPoint("TOPLEFT", block, "TOPLEFT", 10, -12)
  sectionTitle:SetText(STRINGS.SECTION_PROFILE)
  sectionTitle:SetTextColor(0.9, 0.8, 0.4, 1)
  totalHeight = totalHeight + 22

--   "Active profile:"
  local label = block:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
  label:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 0, -10)
  label:SetText(STRINGS.PROFILE_LABEL)
  label:SetTextColor(0.8, 0.8, 0.8, 1)
  totalHeight = totalHeight + 20

--   Profile dropdown
  local dropdown = self:CreateDropdown(block, 180)
  dropdown:SetPoint("LEFT", label, "RIGHT", -12, -2)
  WarbandStorage.activeProfileDrop = dropdown

  totalHeight = totalHeight + 28

  -- CRUD buttons
  local newBtn = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
  newBtn:SetSize(65, 22)
  newBtn:SetText(STRINGS.PROFILE_NEW)
  newBtn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -16)

  local renameBtn = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
  renameBtn:SetSize(75, 22)
  renameBtn:SetText(STRINGS.PROFILE_RENAME)
  renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 5, 0)

  local dupBtn = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
  dupBtn:SetSize(85, 22)
  dupBtn:SetText(STRINGS.PROFILE_DUPLICATE)
  dupBtn:SetPoint("LEFT", renameBtn, "RIGHT", 5, 0)

  local delBtn = CreateFrame("Button", nil, block, "UIPanelButtonTemplate")
  delBtn:SetSize(75, 22)
  delBtn:SetText(STRINGS.PROFILE_DELETE)
  delBtn:SetPoint("LEFT", dupBtn, "RIGHT", 5, 0)

  totalHeight = totalHeight + 28
  -- Use dynamic width based on content area
  block:SetSize(560, totalHeight)

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
    return (self and (self.editBox or self.EditBox or _G[self:GetName().."EditBox"]))
  end

  StaticPopupDialogs["WBSTOCKIST_NEW_PROFILE"] = StaticPopupDialogs["WBSTOCKIST_NEW_PROFILE"] or {
    text = "Enter new profile name:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
      local eb = PopupEditBox(self); if eb then eb:SetText("") eb:SetFocus() end
    end,
    OnAccept = function(self)
      local eb = PopupEditBox(self)
      local name = eb and eb:GetText() or nil
      if WarbandStorage.Utils:ValidateProfileName(name) then
        WarbandStorage.ProfileManager:CreateProfile(name)
        WarbandStorage:SetActiveProfileForChar(name)
      end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
  }

  StaticPopupDialogs["WBSTOCKIST_RENAME_PROFILE"] = StaticPopupDialogs["WBSTOCKIST_RENAME_PROFILE"] or {
    text = "Rename profile:",
    button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 40,
    OnShow = function(self)
      local eb = PopupEditBox(self); if eb then eb:SetText(WarbandStorage:GetActiveProfileName()); eb:HighlightText(); eb:SetFocus(); end
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
    timeout = 0, whileDead = true, hideOnEscape = true,
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
      button1 = OKAY, button2 = CANCEL,
      OnAccept = function()
        WarbandStockistDB.profiles[curName] = nil
        for ck, pn in pairs(WarbandStockistDB.assignments) do if pn == curName then WarbandStockistDB.assignments[ck] = WarbandStockistDB.defaultProfile end end
        WarbandStorage.RefreshProfileDropdown()
        WarbandStorage:SetActiveProfileForChar(WarbandStockistDB.defaultProfile)
      end,
      timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopup_Show("WBSTOCKIST_DELETE_PROFILE", curName)
  end)
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
  panel:SetSize(220, 520)
  
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
    GameTooltip:SetText(STRINGS.DEBUG_TOOLTIP,1,1,1)
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
    GameTooltip:SetText(STRINGS.ENABLE_EXCESS_DEPOSIT_TOOLTIP,1,1,1)
    GameTooltip:Show() 
  end)
  depositToggle:SetScript("OnLeave", GameTooltip_Hide)

  -- Create tabs
  local tabs = self:CreateTabs(panel, depositToggle, contentWidth, contentHeight)

  -- Tab content - use consistent margins
  self:CreateProfilesTabContent(tabs[1].content, contentWidth)
  -- TODO alignment
  local assignmentsFrame = self:CreateAssignmentsSection(tabs[2].content, tabs[2].content)
  assignmentsFrame:SetAllPoints(tabs[2].content)

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
    local id = WarbandStorage.SettingsCategory.ID or (type(WarbandStorage.SettingsCategory.GetID) == "function" and WarbandStorage.SettingsCategory:GetID())
    WarbandStorage.SettingsCategoryID = id
  end
end

-- ############################################################
-- ## Tab Creation
-- ############################################################
function WarbandStorage.UI:CreateTabs(panel, anchor, contentWidth, contentHeight)
  local tabs = {}
  local tabNames = {"Profiles", "Assignments"}
  
  for i, name in ipairs(tabNames) do
    local tab = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    tab:SetSize(140, 32)
    tab:SetBackdrop({ 
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i-1)*145, -25)
    tab.label = tab:CreateFontString(nil, "OVERLAY", FONTS.TAB)
    tab.label:SetText(name)
    tab.label:SetPoint("CENTER", tab, "CENTER")
    tab:EnableMouse(true)
    
    -- Add hover effects
    tab:SetScript("OnEnter", function(self)
      if not self.isSelected then
        self:SetBackdropColor(THEME_COLORS.TAB_HOVER[1], THEME_COLORS.TAB_HOVER[2], THEME_COLORS.TAB_HOVER[3], THEME_COLORS.TAB_HOVER[4])
      end
    end)
    tab:SetScript("OnLeave", function(self)
      if not self.isSelected then
        self:SetBackdropColor(THEME_COLORS.TAB_INACTIVE[1], THEME_COLORS.TAB_INACTIVE[2], THEME_COLORS.TAB_INACTIVE[3], THEME_COLORS.TAB_INACTIVE[4])
      end
    end)
    tab:SetScript("OnMouseDown", function() 
      for j,t in ipairs(tabs) do t.isSelected = (j == i) end
      WarbandStorage.UI:SelectTab(tabs, i) 
    end)
    
    -- Content frame with better backdrop
    tab.content = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    tab.content:SetSize(contentWidth, contentHeight)
    tab.content:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -8)
    tab.content:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    tab.content:SetBackdropColor(THEME_COLORS.CONTENT_BG[1], THEME_COLORS.CONTENT_BG[2], THEME_COLORS.CONTENT_BG[3], THEME_COLORS.CONTENT_BG[4])
    tab.content:SetBackdropBorderColor(THEME_COLORS.BORDER[1], THEME_COLORS.BORDER[2], THEME_COLORS.BORDER[3], THEME_COLORS.BORDER[4])
    tab.content:SetFrameLevel(panel:GetFrameLevel() + 1)
    tab.content:Hide()
    tabs[i] = tab
  end
  
  return tabs
end

-- ############################################################
-- ## Tab Selection
-- ############################################################
function WarbandStorage.UI:SelectTab(tabs, idx)
  for i,tab in ipairs(tabs) do
    if i == idx then
      tab:SetBackdropColor(THEME_COLORS.TAB_ACTIVE[1], THEME_COLORS.TAB_ACTIVE[2], THEME_COLORS.TAB_ACTIVE[3], THEME_COLORS.TAB_ACTIVE[4])
      tab:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
      tab.label:SetTextColor(1, 1, 1, 1)
      tab.content:Show()
    else
      tab:SetBackdropColor(THEME_COLORS.TAB_INACTIVE[1], THEME_COLORS.TAB_INACTIVE[2], THEME_COLORS.TAB_INACTIVE[3], THEME_COLORS.TAB_INACTIVE[4])
      tab:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      tab.label:SetTextColor(0.7, 0.7, 0.7, 1)
      tab.content:Hide()
    end
  end
end

-- Settings panel will be initialized later by the main addon
