-- Warband Stockist — Gold Management Panel
-- Level-bracket and per-character-override UI.
-- Uses a single scroll frame so everything scrolls together.

WarbandStorage    = WarbandStorage    or {}
WarbandStorage.UI = WarbandStorage.UI or {}

local FONTS   = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

-- ── Layout constants ──────────────────────────────────────────
local PAD      = 12   -- outer padding
local ROW_H    = 28   -- each data row height
local SEC_GAP  = 18   -- gap between sections
local CONTENT_W = 550 -- width of the scroll child

-- Bracket column x-offsets (LEFT edge of content cell)
local BC_MIN  = 0
local BC_MAX  = 95
local BC_GOLD = 195
local BC_BTN  = 305

-- Override column x-offsets
local OC_NAME = 0
local OC_GOLD = 240
local OC_BTN  = 345

-- ── Helpers ───────────────────────────────────────────────────

local function EnsureGM()
    WarbandStockistDB = WarbandStockistDB or {}
    local gm = WarbandStockistDB.goldManagement or {}
    gm.brackets  = gm.brackets  or {}
    gm.overrides = gm.overrides or {}
    WarbandStockistDB.goldManagement = gm
    return gm
end

local function MakeEB(parent, w)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w or 80, 22)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(9)
    return eb
end

local function MakeBtn(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 80, 22)
    b:SetText(text)
    return b
end

local function MakeColBar(parent, y, cols)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(24)
    bar:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD, y)
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.18, 0.18, 0.26, 0.85)
    for _, col in ipairs(cols) do
        local fs = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(col.text)
        fs:SetTextColor(0.9, 0.8, 0.4, 1)
        fs:SetPoint("LEFT", bar, "LEFT", col.x + 6, 0)
    end
    return bar
end

local function MakeDivider(parent, y)
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetHeight(1)
    line:SetColorTexture(0.4, 0.4, 0.4, 0.5)
    line:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD * 2, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD * 2, y)
    return line
end

-- ── Dynamic row tracking ──────────────────────────────────────
-- Rows are created fresh each Refresh; old ones get hidden then GC'd.
local bracketRows  = {}
local overrideRows = {}

-- ── Main builder ──────────────────────────────────────────────

function WarbandStorage.UI:CreateGoldTabContent(parent)

    -- One scroll frame fills the tab content
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     2,  -2)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 2)

    -- Scroll child parented to the scroll frame (critical!)
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(CONTENT_W)
    content:SetHeight(1)   -- grows after layout
    sf:SetScrollChild(content)

    -- Reposition the scroll bar thumb area
    local sb = sf.ScrollBar
    if sb then
        sb:ClearAllPoints()
        sb:SetPoint("TOPRIGHT",    sf, "TOPRIGHT",     0, -16)
        sb:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT",  0,  16)
    end

    -- ── Static: Bracket section header & hints ────────────────
    local bTitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    bTitle:SetText(STRINGS.SECTION_GOLD_BRACKETS)
    bTitle:SetTextColor(0.9, 0.8, 0.4, 1)
    bTitle:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, -PAD)

    local bHint = content:CreateFontString(nil, "OVERLAY", FONTS.INLINE_HINT)
    bHint:SetText(STRINGS.GOLD_BRACKET_HINT)
    bHint:SetTextColor(0.65, 0.65, 0.65, 1)
    bHint:SetWidth(CONTENT_W - PAD * 2)
    bHint:SetJustifyH("LEFT")
    bHint:SetPoint("TOPLEFT", bTitle, "BOTTOMLEFT", 0, -4)

    local bColBar = MakeColBar(content, 0, {  -- y set in layout
        { text = STRINGS.GOLD_BRACKET_COL_MIN,  x = BC_MIN  },
        { text = STRINGS.GOLD_BRACKET_COL_MAX,  x = BC_MAX  },
        { text = STRINGS.GOLD_BRACKET_COL_GOLD, x = BC_GOLD },
    })
    bColBar:Hide()  -- shown after layout

    -- ── Static: Bracket add-row ───────────────────────────────
    local bAddTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bAddTitle:SetText("Create / Adjust Bracket:")
    bAddTitle:SetTextColor(0.9, 0.8, 0.4, 1)

    local bAddRow = CreateFrame("Frame", nil, content)
    bAddRow:SetHeight(ROW_H + 2)

    local bAddMinEB  = MakeEB(bAddRow, 80)
    local bAddMaxEB  = MakeEB(bAddRow, 80)
    local bAddGoldEB = MakeEB(bAddRow, 90)
    local bAddBtn    = MakeBtn(bAddRow, STRINGS.GOLD_BRACKET_ADD, 105)
    bAddMinEB :SetPoint("LEFT", bAddRow, "LEFT", BC_MIN  + 2, 0)
    bAddMaxEB :SetPoint("LEFT", bAddRow, "LEFT", BC_MAX  + 2, 0)
    bAddGoldEB:SetPoint("LEFT", bAddRow, "LEFT", BC_GOLD + 2, 0)
    bAddBtn   :SetPoint("LEFT", bAddRow, "LEFT", BC_BTN,      0)

    bAddMinEB:SetScript("OnTabPressed", function() bAddMaxEB:SetFocus() end)
    bAddMaxEB:SetScript("OnTabPressed", function() bAddGoldEB:SetFocus() end)
    bAddGoldEB:SetScript("OnTabPressed", function() bAddMinEB:SetFocus() end)

    -- ── Static: Override section header & hints ───────────────
    local oTitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    oTitle:SetText(STRINGS.SECTION_GOLD_OVERRIDES)
    oTitle:SetTextColor(0.9, 0.8, 0.4, 1)

    local oHint = content:CreateFontString(nil, "OVERLAY", FONTS.INLINE_HINT)
    oHint:SetText(STRINGS.GOLD_OVERRIDE_HINT)
    oHint:SetTextColor(0.65, 0.65, 0.65, 1)
    oHint:SetWidth(CONTENT_W - PAD * 2)
    oHint:SetJustifyH("LEFT")

    local oColBar = MakeColBar(content, 0, {
        { text = STRINGS.GOLD_OVERRIDE_COL_CHAR, x = OC_NAME },
        { text = STRINGS.GOLD_OVERRIDE_COL_GOLD, x = OC_GOLD },
    })
    oColBar:Hide()

    -- ── Static: Override add-row ──────────────────────────────
    local oAddTitle = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    oAddTitle:SetText("Create / Adjust Override:")
    oAddTitle:SetTextColor(0.9, 0.8, 0.4, 1)

    local oAddRow = CreateFrame("Frame", nil, content)
    oAddRow:SetHeight(ROW_H + 2)

    local selectedCharKey = nil

    local oCharDD = CreateFrame("Frame", nil, oAddRow, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(oCharDD, 175)
    oCharDD:SetPoint("LEFT", oAddRow, "LEFT", -10, 0)

    local oGoldEB  = MakeEB(oAddRow, 90)
    local oAddBtn  = MakeBtn(oAddRow, STRINGS.GOLD_OVERRIDE_ADD, 105)
    oGoldEB :SetPoint("LEFT", oAddRow, "LEFT", OC_GOLD + 2, 0)
    oAddBtn :SetPoint("LEFT", oAddRow, "LEFT", OC_BTN,      0)

    oGoldEB:SetScript("OnTabPressed", function(s) s:ClearFocus() end)

    local divider = MakeDivider(content, 0)
    divider:Hide()

    -- ── Layout: positions all static elements and rebuilds rows ─

    local function LayoutAll()
        local gm = EnsureGM()
        local y  = -PAD

        -- Section 1 title
        bTitle:ClearAllPoints()
        bTitle:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
        y = y - 22

        bHint:ClearAllPoints()
        bHint:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
        y = y - 28

        -- Column bar
        bColBar:ClearAllPoints()
        bColBar:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD, y)
        bColBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
        bColBar:Show()
        y = y - 26

        -- Bracket rows
        for _, r in ipairs(bracketRows) do r:Hide() end
        bracketRows = {}

        for i, bracket in ipairs(gm.brackets) do
            local row = CreateFrame("Button", nil, content)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD, y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
            row:RegisterForClicks("LeftButtonUp")

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            if i % 2 == 1 then
                bg:SetColorTexture(0.12, 0.12, 0.18, 0.5)
            end

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)

            row:SetScript("OnClick", function()
                bAddMinEB:SetText(tostring(bracket.minLevel or ""))
                bAddMaxEB:SetText(tostring(bracket.maxLevel or ""))
                bAddGoldEB:SetText(tostring(bracket.gold or ""))
                bAddMinEB:SetFocus()
            end)

            local idx = i  -- capture

            local minFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
            minFS:SetPoint("LEFT", row, "LEFT", BC_MIN + 6, 0)
            minFS:SetText(tostring(bracket.minLevel or ""))

            local maxFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
            maxFS:SetPoint("LEFT", row, "LEFT", BC_MAX + 6, 0)
            maxFS:SetText(tostring(bracket.maxLevel or ""))

            local goldFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
            goldFS:SetPoint("LEFT", row, "LEFT", BC_GOLD + 6, 0)
            goldFS:SetText(tostring(bracket.gold or ""))

            local rmBtn = MakeBtn(row, STRINGS.GOLD_BRACKET_REMOVE, 80)
            rmBtn:SetPoint("LEFT", row, "LEFT", BC_BTN, 0)
            rmBtn:SetScript("OnClick", function()
                table.remove(gm.brackets, idx)
                LayoutAll()
            end)

            table.insert(bracketRows, row)
            y = y - ROW_H
        end

        -- Empty state hint
        if #gm.brackets == 0 then
            local empty = content:CreateFontString(nil, "OVERLAY", FONTS.INLINE_HINT)
            empty:SetText("No brackets defined. Add one below.")
            empty:SetTextColor(0.45, 0.45, 0.45, 1)
            empty:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + 8, y)
            table.insert(bracketRows, empty)  -- track for cleanup
            y = y - ROW_H
        end

        bAddTitle:ClearAllPoints()
        bAddTitle:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y - 4)
        y = y - 24

        -- Add-bracket row
        bAddRow:ClearAllPoints()
        bAddRow:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD, y)
        bAddRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
        y = y - ROW_H - 12

        -- Divider
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD * 2, y)
        divider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD * 2, y)
        divider:Show()
        y = y - SEC_GAP

        -- Section 2 title
        oTitle:ClearAllPoints()
        oTitle:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
        y = y - 22

        oHint:ClearAllPoints()
        oHint:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y)
        y = y - 28

        oColBar:ClearAllPoints()
        oColBar:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD, y)
        oColBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
        oColBar:Show()
        y = y - 26

        -- Override rows
        for _, r in ipairs(overrideRows) do r:Hide() end
        overrideRows = {}

        local keys = {}
        for k in pairs(gm.overrides) do table.insert(keys, k) end
        table.sort(keys)

        for i, ck in ipairs(keys) do
            local row = CreateFrame("Button", nil, content)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD, y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
            row:RegisterForClicks("LeftButtonUp")

            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            if i % 2 == 1 then
                bg:SetColorTexture(0.12, 0.12, 0.18, 0.5)
            end

            local hl = row:CreateTexture(nil, "HIGHLIGHT")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0.06)

            local capturedKey = ck
            row:SetScript("OnClick", function()
                selectedCharKey = capturedKey
                local disp = (WarbandStorage.Utils and WarbandStorage.Utils.FormatCharacterName)
                    and WarbandStorage.Utils:FormatCharacterName(capturedKey) or capturedKey
                UIDropDownMenu_SetText(oCharDD, disp)
                oGoldEB:SetText(tostring(gm.overrides[capturedKey] or ""))
                oGoldEB:SetFocus()
            end)

            local nameFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
            nameFS:SetPoint("LEFT", row, "LEFT", OC_NAME + 4, 0)
            nameFS:SetWidth(230)
            nameFS:SetJustifyH("LEFT")
            local display = (WarbandStorage.Utils and WarbandStorage.Utils.FormatCharacterName)
                and WarbandStorage.Utils:FormatCharacterName(ck) or ck
            nameFS:SetText(display)

            local capturedKey = ck

            local goldFS = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
            goldFS:SetPoint("LEFT", row, "LEFT", OC_GOLD + 6, 0)
            goldFS:SetText(tostring(gm.overrides[ck] or ""))

            local rmBtn = MakeBtn(row, STRINGS.GOLD_OVERRIDE_REMOVE, 80)
            rmBtn:SetPoint("LEFT", row, "LEFT", OC_BTN, 0)
            rmBtn:SetScript("OnClick", function()
                gm.overrides[capturedKey] = nil
                LayoutAll()
            end)

            table.insert(overrideRows, row)
            y = y - ROW_H
        end

        if #keys == 0 then
            local empty = content:CreateFontString(nil, "OVERLAY", FONTS.INLINE_HINT)
            empty:SetText("No character overrides set. Add one below.")
            empty:SetTextColor(0.45, 0.45, 0.45, 1)
            empty:SetPoint("TOPLEFT", content, "TOPLEFT", PAD + 8, y)
            table.insert(overrideRows, empty)
            y = y - ROW_H
        end

        oAddTitle:ClearAllPoints()
        oAddTitle:SetPoint("TOPLEFT", content, "TOPLEFT", PAD, y - 4)
        y = y - 24

        -- Add-override row
        oAddRow:ClearAllPoints()
        oAddRow:SetPoint("TOPLEFT",  content, "TOPLEFT",  PAD, y)
        oAddRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD, y)
        y = y - ROW_H - PAD

        -- Final height
        content:SetHeight(math.abs(y) + PAD)
    end

    -- ── Bracket Add button wiring ─────────────────────────────
    -- When a new bracket overlaps existing ones we:
    --   • trim the left remnant  [existLo .. newLo-1]  (keeps existing gold)
    --   • trim the right remnant [newHi+1 .. existHi]   (keeps existing gold)
    --   • remove any bracket fully covered by the new range
    --   • insert the new bracket
    --   • re-sort everything by minLevel
    bAddBtn:SetScript("OnClick", function()
        local lo   = tonumber(bAddMinEB:GetText())
        local hi   = tonumber(bAddMaxEB:GetText())
        local gold = tonumber(bAddGoldEB:GetText())
        if not (lo and hi and gold and lo >= 1 and hi >= lo and gold > 0) then
            print("|cff7fd5ff[Warband Stockist]|r Enter valid Min (≥1), Max (≥Min), Gold (>0).")
            return
        end

        local gm = EnsureGM()
        local kept    = {}  -- existing brackets that survive (possibly trimmed)
        local inserts = {}  -- new fragments to add

        for _, b in ipairs(gm.brackets) do
            local bLo = b.minLevel or 0
            local bHi = b.maxLevel or 0
            local bG  = b.gold     or 0

            local overlaps = (lo <= bHi) and (hi >= bLo)
            if not overlaps then
                -- No overlap — keep unchanged
                table.insert(kept, b)
            else
                -- Left remnant: exists when the existing bracket starts before the new one
                if bLo < lo then
                    table.insert(inserts, { minLevel = bLo, maxLevel = lo - 1, gold = bG })
                end
                -- Right remnant: exists when the existing bracket ends after the new one
                if bHi > hi then
                    table.insert(inserts, { minLevel = hi + 1, maxLevel = bHi, gold = bG })
                end
                -- (any bracket fully covered by [lo,hi] disappears — no remnants)
            end
        end

        -- Rebuild: surviving originals + remnant fragments + the new bracket
        gm.brackets = kept
        for _, b in ipairs(inserts) do
            table.insert(gm.brackets, b)
        end
        table.insert(gm.brackets, { minLevel = lo, maxLevel = hi, gold = gold })

        table.sort(gm.brackets, function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end)

        bAddMinEB:SetText("")
        bAddMaxEB:SetText("")
        bAddGoldEB:SetText("")
        LayoutAll()
    end)

    -- ── Override char dropdown wiring ─────────────────────────
    local function RefreshCharDD()
        UIDropDownMenu_Initialize(oCharDD, function(_, level)
            local seen = {}
            local keys = {}
            for ck in pairs(WarbandStockistDB._seenCharacters or {}) do
                if not seen[ck] then seen[ck] = true; table.insert(keys, ck) end
            end
            for ck in pairs(WarbandStockistDB.assignments or {}) do
                if not seen[ck] then seen[ck] = true; table.insert(keys, ck) end
            end
            table.sort(keys)
            for _, ck in ipairs(keys) do
                local info = UIDropDownMenu_CreateInfo()
                local disp = (WarbandStorage.Utils and WarbandStorage.Utils.FormatCharacterName)
                    and WarbandStorage.Utils:FormatCharacterName(ck) or ck
                info.text    = disp
                info.value   = ck
                info.checked = (ck == selectedCharKey)
                info.func    = function()
                    selectedCharKey = ck
                    UIDropDownMenu_SetText(oCharDD, disp)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        UIDropDownMenu_SetText(oCharDD,
            selectedCharKey
            and ((WarbandStorage.Utils and WarbandStorage.Utils.FormatCharacterName)
                 and WarbandStorage.Utils:FormatCharacterName(selectedCharKey) or selectedCharKey)
            or "Select character…")
    end
    RefreshCharDD()

    oAddBtn:SetScript("OnClick", function()
        local ck   = selectedCharKey
        local gold = tonumber(oGoldEB:GetText())
        if ck and gold and gold > 0 then
            EnsureGM().overrides[ck] = gold
            oGoldEB:SetText("")
            selectedCharKey = nil
            RefreshCharDD()
            LayoutAll()
        else
            print("|cff7fd5ff[Warband Stockist]|r Select a character and enter a gold amount > 0.")
        end
    end)

    -- ── Expose refresh so external callers (OnShow etc.) can call them ─
    WarbandStorage.RefreshGoldBracketList  = LayoutAll
    WarbandStorage.RefreshGoldOverrideList = function() RefreshCharDD(); LayoutAll() end

    -- Initial layout
    LayoutAll()
end
