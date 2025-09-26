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
-- ## Main Tabbed Settings Panel
-- ############################################################
function WarbandStorage.UI:CreateTabbedSettingsCategory()
  local padding = 20
  local spacing = 10 

  -- Ensure functions exist before calling them
  if WarbandStorage.MigrateLegacyIfNeeded then
    WarbandStorage:MigrateLegacyIfNeeded()
  end
  WarbandStorage.ProfileManager:EnsureProfile(WarbandStockistDB.defaultProfile)

  local panel = CreateFrame("Frame", "WarbandStockistOptionsPanel", UIParent, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
  panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")

  WarbandStorage.FrameFactory:SetupDialogFrame(panel)

  -- Header elements
  local title = panel:CreateFontString(nil, "ARTWORK", FONTS.SECTION)
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -padding)
  title:SetText(STRINGS.TITLE)
  title:SetTextColor(0.9, 0.8, 0.4, 1)

  local debugCheckbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
  debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -spacing)
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
  helpText:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -spacing)
  helpText:SetWidth(560)
  helpText:SetJustifyH("LEFT")
  helpText:SetText(STRINGS.HELP_TEXT)
  helpText:SetTextColor(0.7, 0.7, 0.7, 1)

  local depositToggle = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
  depositToggle:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -spacing)
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
  local block, tabs = self:CreateTabs(panel)
  block:SetPoint("TOPLEFT", depositToggle, "BOTTOMLEFT", 0, 0)
  block:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

  -- Tab content - use consistent margins
  self:CreateProfilesTabContent(tabs[1].content)
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
function WarbandStorage.UI:CreateTabs(parent)  
  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel")

  local tabButtonSize = { width = 140, height = 32 }
  local tabs = {}
  local tabNames = { "Profiles", "Assignments" }
  local firstTab = nil

  for i, name in ipairs(tabNames) do
    local tab = CreateFrame("Frame", nil, block, "BackdropTemplate")
    tab:SetSize(tabButtonSize.width, tabButtonSize.height)
    tab:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    local anchor = nil
    if(tabs[i - 1]) then
      anchor = tabs[i - 1]
      tab:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 5 , 0)
    else
      anchor = block
      tab:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0 , -25)
    end
    -- tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i - 1) * 145, -25)
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
    tab.content = CreateFrame("Frame", nil, block, "BackdropTemplate")
    tab.content:SetPoint("TOPLEFT", firstTab, "BOTTOMLEFT", 0, -8)
    tab.content:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -8, 8)
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
    tab.content:SetFrameLevel(block:GetFrameLevel() + 1)
    tab.content:Hide()
    tabs[i] = tab
  end

  return block, tabs
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
