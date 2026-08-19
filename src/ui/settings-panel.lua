-- Warband Stockist — Settings Panel
-- Main settings panel creation and profile controls

WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

WarbandStockistDB = WarbandStockistDB or {
  debugEnabled = false,
  defaultProfile = "Default",
  profiles = {},
  assignments = {},
  characterClasses = {}, -- Store character class info for proper coloring
}

local THEME_COLORS = WarbandStorage.Theme.COLORS
local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- ############################################################
-- ## Main Tabbed Settings Panel
-- ############################################################
function WarbandStorage.UI:CreateTabbedSettingsCategory()
  -- If already created/registered, don't create a second panel
  if WarbandStorage.SettingsCategory then
    return WarbandStorage.SettingsCategory
  end
  local padding = 20
  local spacing = 10 

  -- Ensure functions exist before calling them
  if WarbandStorage.MigrateLegacyIfNeeded then
    WarbandStorage:MigrateLegacyIfNeeded()
  end
  -- Ensure reserved default profile exists so lists/dropdowns have it
  WarbandStorage.ProfileManager:EnsureProfile(WarbandStockistDB.defaultProfile)

  local panel = CreateFrame("Frame", "WarbandStockistOptionsPanel", UIParent, "BackdropTemplate")
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
  panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")

  WarbandStorage.FrameFactory:SetupDialogFrame(panel)
  -- Important: keep our panel hidden until the Settings UI shows it
  panel:Hide()

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

  local minimapToggle = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
  minimapToggle:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -spacing)
  minimapToggle.Text:SetFontObject(FONTS.LABEL)
  minimapToggle.Text:SetText(STRINGS.SHOW_MINIMAP)
  minimapToggle.Text:SetTextColor(0.8, 0.8, 0.8, 1)
  minimapToggle:SetScript("OnClick", function(self)
    if WarbandStorage.Minimap and WarbandStorage.Minimap.button then
      WarbandStorage.Minimap.button:SetShown_Persisted(self:GetChecked())
    end
  end)
  minimapToggle:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(STRINGS.SHOW_MINIMAP_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
  end)
  minimapToggle:SetScript("OnLeave", GameTooltip_Hide)

  -- Create tabs (Profiles | Assignments | Gold)
  local block, tabs = self:CreateTabs(panel)
  block:SetPoint("TOPLEFT", minimapToggle, "BOTTOMLEFT", 0, -4)
  block:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

  -- Tab content
  self:CreateProfilesTabContent(tabs[1].content)
  self:CreateAssignmentsSection(tabs[2].content)
  self:CreateGoldTabContent(tabs[3].content)
  local refreshWarboundTab = self:CreateWarboundTabContent(tabs[4].content)


  -- Panel show handler
  panel:SetScript("OnShow", function()
    WarbandStorage.Perf:Reset()
    local perfStart = WarbandStorage.Perf:Now()
    debugCheckbox:SetChecked(WarbandStockistDB.debugEnabled == true)
    minimapToggle:SetChecked(not (WarbandStockistDB.minimap and WarbandStockistDB.minimap.hide))
    if WarbandStorage.RefreshProfileDropdown then
      WarbandStorage.RefreshProfileDropdown()
    end
    if RefreshAssignmentsList then
      RefreshAssignmentsList()
    end
    if RefreshItemList then
      RefreshItemList()
    end
    if WarbandStorage.RefreshGoldBracketList then
      WarbandStorage.RefreshGoldBracketList()
    end
    if WarbandStorage.RefreshGoldOverrideList then
      WarbandStorage.RefreshGoldOverrideList()
    end
    refreshWarboundTab()
    self:SelectTab(tabs, 1)

    WarbandStorage.Perf:Add("SettingsPanel:OnShow", perfStart)
    -- Async item loads keep refreshing the list after OnShow returns, so the
    -- report waits for that settle before dumping.
    if WarbandStockistDB.debugEnabled then
      C_Timer.After(3, function() WarbandStorage.Perf:Dump("settings load (+3s)") end)
    end
  end)

  WarbandStorage.SettingsCategory = Settings.RegisterCanvasLayoutCategory(panel, STRINGS.SETTINGS_NAME)
  Settings.RegisterAddOnCategory(WarbandStorage.SettingsCategory)
  -- Cache ID for reliable lookups later
  if WarbandStorage.SettingsCategory then
    local id = WarbandStorage.SettingsCategory.ID or
        (type(WarbandStorage.SettingsCategory.GetID) == "function" and WarbandStorage.SettingsCategory:GetID())
    WarbandStorage.SettingsCategoryID = id
  end

  -- Set default selection even before show, so UI is ready when opened
  self:SelectTab(tabs, 1)

  return WarbandStorage.SettingsCategory
end

-- ############################################################
-- ## Tab Creation
-- ############################################################
function WarbandStorage.UI:CreateTabs(parent)  
  local block = WarbandStorage.FrameFactory:CreateStyledFrame(parent, "contentPanel")

  local tabButtonSize = { width = 140, height = 32 }
  local tabs = {}
  local tabNames = { "Profiles", "Assignments", STRINGS.GOLD_TAB_NAME, "Warbound" }
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
    local anchor
    if(tabs[i - 1]) then
      anchor = tabs[i - 1]
      tab:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 5 , 0)
    else
      anchor = block
      tab:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0 , -4)
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
-- ## Warbound Tab
-- ############################################################
-- Returns a refresh function that syncs checkbox state from the DB, so the
-- panel picks up changes made outside it (e.g. settings migrated over from
-- Lucky's Grab-bag at the bank).
function WarbandStorage.UI:CreateWarboundTabContent(content)
  local padding, spacing = 16, 8

  local function Config()
    WarbandStockistDB.warboundDeposit = WarbandStockistDB.warboundDeposit or {}
    return WarbandStockistDB.warboundDeposit
  end

  local checkboxes = {}
  local refresh

  local function AddCheckbox(key, label, tooltip, anchor, indent)
    local cb = CreateFrame("CheckButton", nil, content, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 0, -spacing)
    cb.Text:SetFontObject(FONTS.LABEL)
    cb.Text:SetText(label)
    cb.Text:SetTextColor(0.8, 0.8, 0.8, 1)
    cb:SetScript("OnClick", function(self)
      Config()[key] = self:GetChecked() and true or false
      refresh()
    end)
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    checkboxes[key] = cb
    return cb
  end

  local anchorFrame = CreateFrame("Frame", nil, content)
  anchorFrame:SetPoint("TOPLEFT", content, "TOPLEFT", padding, -padding + spacing)
  anchorFrame:SetSize(1, 1)

  local master = AddCheckbox("enabled", "Auto-Deposit Warbound Items",
    "When you open the bank, deposits warbound gear from your bags into the Warband Bank before restocking your profile.",
    anchorFrame)
  local armor = AddCheckbox("armor", "Warbound Armor", "Auto-deposit warbound armor.", master, 24)
  local weapons = AddCheckbox("weapons", "Warbound Weapons", "Auto-deposit warbound weapons.", armor)
  local tokens = AddCheckbox("tokens", "Warbound Tokens", "Auto-deposit warbound tier tokens.", weapons)

  local hint = content:CreateFontString(nil, "OVERLAY", FONTS.INLINE_HINT)
  hint:SetPoint("TOPLEFT", tokens, "BOTTOMLEFT", -24, -spacing)
  hint:SetWidth(560)
  hint:SetJustifyH("LEFT")
  hint:SetText("Items with a stock amount in the active profile are never deposited by this; the restock keeps them in your bags.")
  hint:SetTextColor(0.7, 0.7, 0.7, 1)

  refresh = function()
    local cfg = Config()
    for key, cb in pairs(checkboxes) do
      cb:SetChecked(cfg[key] == true)
    end
    local enabled = cfg.enabled == true
    for _, cb in ipairs({ armor, weapons, tokens }) do
      cb:SetEnabled(enabled)
      cb.Text:SetTextColor(0.8, 0.8, 0.8, enabled and 1 or 0.4)
    end
  end
  refresh()

  return refresh
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
      tab.isSelected = true
    else
      tab:SetBackdropColor(THEME_COLORS.TAB_INACTIVE[1], THEME_COLORS.TAB_INACTIVE[2], THEME_COLORS.TAB_INACTIVE[3],
        THEME_COLORS.TAB_INACTIVE[4])
      tab:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
      tab.label:SetTextColor(0.7, 0.7, 0.7, 1)
      tab.content:Hide()
      tab.isSelected = false
    end
  end
end

-- Settings panel will be initialized later by the main addon
