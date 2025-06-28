WarbandStorage = WarbandStorage or {}
WarbandStorageCharData = WarbandStorageCharData or {}

-- Font Style Constants
local FONT_LABEL       = "GameFontNormalSmall"
local FONT_SECTION     = "GameFontHighlightLarge"
local FONT_INLINE_HINT = "GameFontHighlightSmall"

-- String Constants
local SETTINGS_NAME               = "Warband Stockist"
local STR_TITLE                   = "Warbank Stockist Settings"
local STR_DEBUG_LABEL             = "Enable Debug Logging"
local STR_DEBUG_TOOLTIP           = "When enabled, detailed debug messages will be printed to chat."
local STR_HELP_TEXT               = "This addon monitors your stock list and automatically withdraws items from your warband bank to keep your bags topped up. You can maintain a global list or a character-specific override."
local STR_MODE_LABEL              = "List Mode:"
local STR_MODE_GLOBAL             = "Use Global List"
local STR_MODE_GLOBAL_TOOLTIP     = "Use a shared stock list across all characters."
local STR_MODE_CHARACTER          = "Use Character-Specific List"
local STR_MODE_CHAR_TOOLTIP       = "Use a character-specific stock list that overrides the global one."
local STR_SECTION_STOCK           = "Add Item"
local STR_LABEL_ITEM_ID           = "Item ID:"
local STR_LABEL_ITEM_ID_TOOLTIP   = "Enter the numeric ID of the item you want to track."
local STR_LABEL_QTY               = "Desired quantity:"
local STR_LABEL_QTY_TOOLTIP       = "Enter the quantity to keep stocked."
local STR_BUTTON_ADD              = "Add"
local STR_BUTTON_ADD_TOOLTIP      = "Adds the specified item and quantity to the current stock list."
local STR_BUTTON_CLEAR            = "Clear List"
local STR_BUTTON_CLEAR_TOOLTIP    = "Removes all items from the current stock list mode."
local STR_SECTION_TRACKED         = "Tracked Items"
local STR_BUTTON_REMOVE           = "Remove"
local STR_BUTTON_RESET            = "Reset"
local STR_ENABLE_EXCESS_DEPOSIT   = "Enable Auto Deposit"
local STR_ENABLE_EXCESS_DEPOSIT_TOOLTIP = "If enabled, items in excess of configured stock will be deposited into the warband bank when it is open."

local itemNameCache = {}

local function GetCachedItemName(itemID)
    if not itemID then return nil end
    if itemNameCache[itemID] then return itemNameCache[itemID] end

    local name = C_Item.GetItemInfo(itemID)
    if name then
        itemNameCache[itemID] = name
    else
        -- If item info isn't ready yet, queue for retry
        C_Timer.After(0.1, function() RefreshItemList() end)
    end
    return name
end

-- Helper to get editable table based on mode
local function GetEditableStock()
    return WarbandStorageCharData.useDefault == false and WarbandStorageCharData.override or WarbandStorageData.default
end

-- Mode Toggle Buttons
local function CreateModeToggle(parent, anchor)
    local toggleLabel = parent:CreateFontString(nil, "OVERLAY", FONT_LABEL)
    toggleLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -15)
    toggleLabel:SetText(STR_MODE_LABEL)

    local globalBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    globalBtn:SetText(STR_MODE_GLOBAL)
    local globalTextWidth = globalBtn:GetFontString():GetStringWidth()
    globalBtn:SetWidth(globalTextWidth + 20)
    globalBtn:SetPoint("LEFT", toggleLabel, "RIGHT", 10, 0)
    globalBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(STR_MODE_GLOBAL_TOOLTIP, 1, 1, 1); GameTooltip:Show() end)
    globalBtn:SetScript("OnLeave", GameTooltip_Hide)

    local charBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    charBtn:SetText(STR_MODE_CHARACTER)
    local charTextWidth = charBtn:GetFontString():GetStringWidth()
    charBtn:SetWidth(charTextWidth + 20)
    charBtn:SetPoint("LEFT", globalBtn, "RIGHT", 4, 0)
    charBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(STR_MODE_CHAR_TOOLTIP, 1, 1, 1); GameTooltip:Show() end)
    charBtn:SetScript("OnLeave", GameTooltip_Hide)

    local function UpdateButtons()
        local useDefault = WarbandStorageCharData.useDefault ~= false
        globalBtn:SetEnabled(not useDefault)
        charBtn:SetEnabled(useDefault)
    end

    globalBtn:SetScript("OnClick", function()
        WarbandStorageCharData.useDefault = true
        UpdateButtons()
        RefreshItemList()
    end)
    charBtn:SetScript("OnClick", function()
        WarbandStorageCharData.useDefault = false
        UpdateButtons()
        RefreshItemList()
    end)

    return toggleLabel, globalBtn, charBtn, UpdateButtons
end

-- Input Row
local function CreateInputRow(parent, anchor)
    -- Add shaded background frame
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetSize(540, 75)
    bg:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    bg:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    bg:SetBackdropColor(0.1, 0.1, 0.1, 0.4) -- subtle gray with transparency

    local inputSectionTitle = bg:CreateFontString(nil, "OVERLAY", FONT_SECTION)
    inputSectionTitle:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -8)
    inputSectionTitle:SetText(STR_SECTION_STOCK)

    local itemLabel = bg:CreateFontString(nil, "OVERLAY", FONT_LABEL)
    itemLabel:SetText(STR_LABEL_ITEM_ID)
    itemLabel:SetPoint("TOPLEFT", inputSectionTitle, "BOTTOMLEFT", 0, -8)

    local itemInput = CreateFrame("EditBox", nil, bg, "InputBoxTemplate")
    itemInput:SetSize(100, 20)
    itemInput:SetAutoFocus(false)
    itemInput:SetNumeric(true)
    itemInput:SetPoint("TOPLEFT", itemLabel, "BOTTOMLEFT", 0, -2)

    -- Drag-and-drop support for item links
    globalItemInput = itemInput -- expose to global so handlers can access
    itemInput:SetScript("OnReceiveDrag", function(self)
        local type, itemID, link = GetCursorInfo()
        if type == "item" then
            local extractedID = tonumber(link:match("item:(%d+)") or itemID)
            if extractedID then
                self:SetText(extractedID)
                ClearCursor()
            end
        end
    end)

    itemInput:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText(STR_LABEL_ITEM_ID_TOOLTIP, 1, 1, 1);
        GameTooltip:Show()
        end
    )
    itemInput:SetScript("OnLeave", GameTooltip_Hide)

    local qtyLabel = bg:CreateFontString(nil, "OVERLAY", FONT_LABEL)
    qtyLabel:SetText(STR_LABEL_QTY)
    qtyLabel:SetPoint("TOPLEFT", itemLabel, "TOPRIGHT", 120, 0)

    local qtyInput = CreateFrame("EditBox", nil, bg, "InputBoxTemplate")
    qtyInput:SetSize(50, 20)
    qtyInput:SetAutoFocus(false)
    qtyInput:SetNumeric(true)
    qtyInput:SetPoint("TOPLEFT", qtyLabel, "BOTTOMLEFT", 0, -2)
    qtyInput:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(STR_LABEL_QTY_TOOLTIP, 1, 1, 1); GameTooltip:Show() end)
    qtyInput:SetScript("OnLeave", GameTooltip_Hide)

    local addButton = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    addButton:SetSize(40, 20)
    addButton:SetText(STR_BUTTON_ADD)
    addButton:SetPoint("TOPLEFT", qtyInput, "TOPRIGHT", 10, 0)
    addButton:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(STR_BUTTON_ADD_TOOLTIP, 1, 1, 1); GameTooltip:Show() end)
    addButton:SetScript("OnLeave", GameTooltip_Hide)

    local clearButton = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    clearButton:SetSize(80, 20)
    clearButton:SetText(STR_BUTTON_CLEAR)
    clearButton:SetPoint("TOPLEFT", addButton, "TOPRIGHT", 10, 0)
    clearButton:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(STR_BUTTON_CLEAR_TOOLTIP, 1, 1, 1); GameTooltip:Show() end)
    clearButton:SetScript("OnLeave", GameTooltip_Hide)

    -- Link behavior
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if itemInput:HasFocus() then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                itemInput:SetText(itemID)
                itemInput:ClearFocus()
            end
        end
    end)

    -- Actions
    addButton:SetScript("OnClick", function()
        local itemID = tonumber(itemInput:GetText())
        local qty = tonumber(qtyInput:GetText())
        if itemID and qty and qty > 0 then
            GetEditableStock()[itemID] = qty
            itemInput:SetText("")
            qtyInput:SetText("")
            RefreshItemList()
        else
            WarbandStorage:DebugPrint("Invalid item ID or quantity.")
        end
    end)

    clearButton:SetScript("OnClick", function()
        if WarbandStorageCharData.useDefault == false then
            wipe(WarbandStorageCharData.override)
        else
            wipe(WarbandStorageData.default)
        end
        RefreshItemList()
    end)

    return itemInput, qtyInput, bg
end

function RefreshItemList()
    local stock = WarbandStorage:GetDesiredStock()
    for _, row in ipairs(WarbandStorage.scrollItems or {}) do row:Hide() end
    WarbandStorage.scrollItems = {}

    local y = -4
    local index = 0

    for itemID, count in pairs(stock) do
        local row = CreateFrame("Frame", nil, WarbandStorage.scrollParent)
        row:SetSize(530, 24)
        row:SetPoint("TOPLEFT", WarbandStorage.scrollParent, "TOPLEFT", 0, y)

        -- Alternating background
        if index % 2 == 1 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.2, 0.2, 0.2, 0.3)
        end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT")
        local itemIcon = select(5, GetItemInfoInstant(itemID))
        if itemIcon then icon:SetTexture(itemIcon) end
        icon:SetDesaturated(count == 0)

        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function() GameTooltip:SetOwner(icon, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(itemID); GameTooltip:Show() end)
        icon:SetScript("OnLeave", GameTooltip_Hide)

        local label = row:CreateFontString(nil, "OVERLAY", FONT_LABEL)
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        label:SetWidth(240)
        label:SetJustifyH("LEFT")

        local tag = WarbandStorageCharData.useDefault == false and (WarbandStorage:IsItemOverridden(itemID) and " |cff00ff00[Custom]|r" or " |cffaaaaaa[Default]|r") or ""
        local itemName = GetCachedItemName(itemID) or ("Item " .. itemID)
        local itemText = ("%s (ID: %d)%s"):format(itemName, itemID, tag)
        label:SetText(count == 0 and ("|cff888888" .. itemText .. "|r") or itemText)

        local qtyBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
        qtyBox:SetSize(40, 20)
        qtyBox:SetPoint("LEFT", label, "RIGHT", 10, 0)
        qtyBox:SetAutoFocus(false)
        qtyBox:SetNumeric(true)
        qtyBox:SetText(count)

        qtyBox:SetScript("OnEnterPressed", function(self)
            local val = tonumber(self:GetText())
            if val ~= nil then GetEditableStock()[itemID] = val end
            self:ClearFocus(); RefreshItemList()
        end)
        qtyBox:SetScript("OnEscapePressed", function(self) self:SetText(count); self:ClearFocus() end)

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 18)
        removeBtn:SetText(STR_BUTTON_REMOVE)
        removeBtn:SetPoint("LEFT", qtyBox, "RIGHT", 10, 0)
        removeBtn:SetScript("OnClick", function()
            GetEditableStock()[itemID] = nil
            RefreshItemList()
        end)

        table.insert(WarbandStorage.scrollItems, row)
        y = y - 24
        index = index + 1
    end

    WarbandStorage.scrollParent:SetHeight(-y + 10)
end

--  Create the tracked items header row (outside the scroll frame)
local function CreateTrackedItemsHeader(parent, anchor)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(550, 24)
    header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)

    -- Item Header Label
    local itemHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemHeader:SetText("Item")
    itemHeader:SetPoint("LEFT", header, "LEFT", 26, 0)

    -- Qty Header Label
    local qtyHeader = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyHeader:SetText("Qty")
    qtyHeader:SetPoint("LEFT", itemHeader, "RIGHT", 260, 0)

    return header
end


-- Settings Panel
local function CreateSettingsCategory()
    local panel = CreateFrame("Frame", "WarbankStockistOptionsPanel", UIParent)
    panel:SetSize(600, 400)

    local title = panel:CreateFontString(nil, "ARTWORK", FONT_SECTION)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    title:SetText(STR_TITLE)

    local debugCheckbox = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
    debugCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    debugCheckbox.Text:SetFontObject(FONT_LABEL)
    debugCheckbox.Text:SetText(STR_DEBUG_LABEL)
    debugCheckbox:SetScript("OnClick", function(self)
        WarbandStorageData.debugEnabled = self:GetChecked()
        WarbandStorage:DebugPrint("Debug logging " .. (self:GetChecked() and "enabled" or "disabled"))
    end)
    debugCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(STR_DEBUG_TOOLTIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    debugCheckbox:SetScript("OnLeave", GameTooltip_Hide)

    local helpText = panel:CreateFontString(nil, "OVERLAY", FONT_INLINE_HINT)
    helpText:SetPoint("TOPLEFT", debugCheckbox, "BOTTOMLEFT", 0, -6)
    helpText:SetWidth(540)
    helpText:SetJustifyH("LEFT")
    helpText:SetText(STR_HELP_TEXT)

    local depositToggle = CreateFrame("CheckButton", nil, panel, "ChatConfigCheckButtonTemplate")
    depositToggle:SetPoint("TOPLEFT", helpText, "BOTTOMLEFT", 0, -30)
    depositToggle.Text:SetFontObject(FONT_LABEL)
    depositToggle.Text:SetText(STR_ENABLE_EXCESS_DEPOSIT)
    depositToggle:SetScript("OnClick", function(self)
        WarbandStorageCharData.enableExcessDeposit = self:GetChecked()
    end)

    -- Tooltip
    depositToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(STR_ENABLE_EXCESS_DEPOSIT_TOOLTIP, 1, 1, 1)
        GameTooltip:Show()
    end)
    depositToggle:SetScript("OnLeave", GameTooltip_Hide)

    local toggleLabel, globalBtn, charBtn, UpdateModeButtons = CreateModeToggle(panel, depositToggle)
    local itemInput, qtyInput = CreateInputRow(panel, toggleLabel)

    local sectionTitle = panel:CreateFontString(nil, "OVERLAY", FONT_SECTION)
    sectionTitle:SetPoint("TOPLEFT", itemInput, "BOTTOMLEFT", 0, -18)
    sectionTitle:SetText(STR_SECTION_TRACKED)

    --  In your CreateSettingsCategory function (or equivalent)
    -- After declaring sectionTitle:
    local header = CreateTrackedItemsHeader(panel, sectionTitle)

    -- Add a ScrollFrame for the Tracked Items
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(550, 280)
    scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetSize(530, 1) -- Will grow with content
    scrollFrame:SetScrollChild(scrollChild)
    WarbandStorage.scrollParent = scrollChild

    -- Ensure scrollbar skin is visible
    local scrollBar = scrollFrame.ScrollBar
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", -16, -18)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", -16, 18)
    scrollBar:SetFrameLevel(scrollFrame:GetFrameLevel() + 1)
    scrollBar:Show()

    panel:SetScript("OnShow", function()
        debugCheckbox:SetChecked(WarbandStorageData.debugEnabled == true)
        depositToggle:SetChecked(WarbandStorageCharData.enableExcessDeposit == true)
        UpdateModeButtons()
        RefreshItemList()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, SETTINGS_NAME)
    Settings.RegisterAddOnCategory(category)
end

CreateSettingsCategory()
