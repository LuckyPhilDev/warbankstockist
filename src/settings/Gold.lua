-- Warband Stockist: Gold page.
-- Level brackets and per-character overrides, laid out top to bottom in one
-- scrolling region so both tables move together.

WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local PAD     = 6    -- inset from the scroll region's edges
local ROW_H   = 28
local SEC_GAP = 18

-- Column offsets from the left edge of a row.
local BC_MIN, BC_MAX, BC_GOLD, BC_BTN = 0, 95, 195, 305
local OC_NAME, OC_GOLD, OC_BTN = 0, 240, 345

local function GoldConfig()
    local gm = WarbandStockistDB.goldManagement or {}
    gm.brackets = gm.brackets or {}
    gm.overrides = gm.overrides or {}
    WarbandStockistDB.goldManagement = gm
    return gm
end

local function CharacterName(characterKey)
    return WarbandStorage.Utils:FormatCharacterName(characterKey)
end

-- ############################################################
-- ## Static pieces
-- ############################################################

-- Matches the heading the rich panel puts above its own row groups: a dim
-- uppercase label hugging the content below it, with a rule filling the rest of
-- the width. Insets are smaller than the library's because the scroll region
-- this sits in is already inset.
local function SectionHeader(parent, text)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(28)

    local label = header:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 10, "")
    label:SetPoint("BOTTOMLEFT", 4, 4)
    label:SetText(string.upper(text))
    label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])

    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("LEFT", label, "RIGHT", 8, 1)
    rule:SetPoint("RIGHT", -4, 0)
    rule:SetColorTexture(R.border[1], R.border[2], R.border[3], R.border[4])

    return header
end

local function Hint(parent, text)
    local hint = parent:CreateFontString(nil, "OVERLAY")
    hint:SetFont(R_FONT, 11, "")
    hint:SetText(text)
    hint:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(3)
    return hint
end

local function ColumnBar(parent, columns)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(22)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(R.bg3[1], R.bg3[2], R.bg3[3], 1)

    for _, column in ipairs(columns) do
        local label = bar:CreateFontString(nil, "OVERLAY")
        label:SetFont(R_FONT, 10, "")
        label:SetText(string.upper(column.text))
        label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
        label:SetPoint("LEFT", column.x + 6, 0)
    end
    return bar
end

local function EmptyLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 11, "")
    label:SetText(text)
    label:SetTextColor(R.textFaint[1], R.textFaint[2], R.textFaint[3])
    label:SetJustifyH("LEFT")
    return label
end

-- Rows are rebuilt on every layout pass; the pool keeps that from creating a
-- fresh frame each time a bracket is added or removed.
local function TableRow(pool, index, parent)
    local row = pool[index]
    if row then return row end

    row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp")

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.05)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.08)

    row.cells = {}
    row.removeBtn = LuckyUI.CreateButton(row, S.gold.removeBracket, 80, 22, "danger")

    pool[index] = row
    return row
end

local function Cell(row, key, x, width)
    local cell = row.cells[key]
    if not cell then
        cell = row:CreateFontString(nil, "OVERLAY")
        cell:SetFont(R_FONT, 12, "")
        cell:SetTextColor(R.text[1], R.text[2], R.text[3])
        cell:SetPoint("LEFT", x + 6, 0)
        cell:SetJustifyH("LEFT")
        if width then cell:SetWidth(width) end
        row.cells[key] = cell
    end
    return cell
end

-- ############################################################
-- ## Page
-- ############################################################

function Settings.BuildGold(group)
    local content = group:Fill()

    local bracketRows, overrideRows = {}, {}
    local selectedCharacter
    local LayoutAll

    local bracketHeader = SectionHeader(content, S.gold.bracketsSection)
    local bracketHint = Hint(content, S.gold.bracketHint)
    local bracketBar = ColumnBar(content, {
        { text = S.gold.colMinLevel, x = BC_MIN },
        { text = S.gold.colMaxLevel, x = BC_MAX },
        { text = S.gold.colGold,     x = BC_GOLD },
    })
    local bracketEmpty = EmptyLabel(content, S.gold.noBrackets)
    local bracketAddHeader = SectionHeader(content, S.gold.createBracket)

    local bracketAdd = CreateFrame("Frame", nil, content)
    bracketAdd:SetHeight(ROW_H)
    local minBox  = Settings.NumberBox(bracketAdd, 80)
    local maxBox  = Settings.NumberBox(bracketAdd, 80)
    local goldBox = Settings.NumberBox(bracketAdd, 90)
    local addBracketBtn = LuckyUI.CreateButton(bracketAdd, S.gold.addBracket, 105, 24, "primary")
    minBox:SetPoint("LEFT", BC_MIN + 2, 0)
    maxBox:SetPoint("LEFT", BC_MAX + 2, 0)
    goldBox:SetPoint("LEFT", BC_GOLD + 2, 0)
    addBracketBtn:SetPoint("LEFT", BC_BTN, 0)

    minBox:SetScript("OnTabPressed", function() maxBox:SetFocus() end)
    maxBox:SetScript("OnTabPressed", function() goldBox:SetFocus() end)
    goldBox:SetScript("OnTabPressed", function() minBox:SetFocus() end)

    local rule = content:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetColorTexture(R.border2[1], R.border2[2], R.border2[3], R.border2[4])

    local overrideHeader = SectionHeader(content, S.gold.overridesSection)
    local overrideHint = Hint(content, S.gold.overrideHint)
    local overrideBar = ColumnBar(content, {
        { text = S.gold.colCharacter, x = OC_NAME },
        { text = S.gold.colGold,      x = OC_GOLD },
    })
    local overrideEmpty = EmptyLabel(content, S.gold.noOverrides)
    local overrideAddHeader = SectionHeader(content, S.gold.createOverride)

    local overrideAdd = CreateFrame("Frame", nil, content)
    overrideAdd:SetHeight(ROW_H)

    local characterDrop = CreateFrame("DropdownButton", nil, overrideAdd, "WowStyle1DropdownTemplate")
    characterDrop:SetWidth(225)
    characterDrop:SetPoint("LEFT", OC_NAME, 0)
    characterDrop:SetupMenu(function(_, root)
        for _, characterKey in ipairs(WarbandStorage:GetAllCharacterKeys()) do
            root:CreateRadio(CharacterName(characterKey),
                function() return selectedCharacter == characterKey end,
                function()
                    selectedCharacter = characterKey
                    characterDrop:SetDefaultText(CharacterName(characterKey))
                end)
        end
    end)
    characterDrop:SetDefaultText(S.gold.selectCharacter)

    local overrideGoldBox = Settings.NumberBox(overrideAdd, 90)
    overrideGoldBox:SetPoint("LEFT", OC_GOLD + 2, 0)
    overrideGoldBox:SetScript("OnTabPressed", overrideGoldBox.ClearFocus)

    local addOverrideBtn = LuckyUI.CreateButton(overrideAdd, S.gold.addOverride, 105, 24, "primary")
    addOverrideBtn:SetPoint("LEFT", OC_BTN, 0)

    -- ── Layout ────────────────────────────────────────────────

    local y = 0

    local function place(region, height, inset)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", content, "TOPLEFT", inset or PAD, y)
        region:SetPoint("TOPRIGHT", content, "TOPRIGHT", -(inset or PAD), y)
        y = y - height
    end

    local function gap(height)
        y = y - height
    end

    local function placeHint(hint)
        hint:SetWidth(math.max(content:GetWidth() - PAD * 2, 200))
        place(hint, hint:GetStringHeight() + 8)
    end

    -- Draws one table: column bar, a row per entry, or the empty-state line.
    local function placeTable(bar, rows, entries, emptyLine, fillRow)
        place(bar, bar:GetHeight() + 2)

        for _, row in ipairs(rows) do row:Hide() end
        for index, entry in ipairs(entries) do
            local row = TableRow(rows, index, content)
            row.stripe:SetShown(index % 2 == 0)
            row.removeBtn:ClearAllPoints()
            fillRow(row, index, entry)
            row:Show()
            place(row, ROW_H)
        end

        emptyLine:SetShown(#entries == 0)
        if #entries == 0 then place(emptyLine, ROW_H, PAD + 8) end
    end

    LayoutAll = function()
        local gm = GoldConfig()
        y = -PAD

        place(bracketHeader, bracketHeader:GetHeight())
        placeHint(bracketHint)

        placeTable(bracketBar, bracketRows, gm.brackets, bracketEmpty, function(row, index, bracket)
            Cell(row, "min", BC_MIN):SetText(tostring(bracket.minLevel or ""))
            Cell(row, "max", BC_MAX):SetText(tostring(bracket.maxLevel or ""))
            Cell(row, "gold", BC_GOLD):SetText(tostring(bracket.gold or ""))
            row.removeBtn:SetPoint("LEFT", BC_BTN, 0)
            row.removeBtn:SetScript("OnClick", function()
                table.remove(gm.brackets, index)
                LayoutAll()
            end)
            -- Clicking a row loads it into the add fields, which is how an
            -- existing bracket gets adjusted.
            row:SetScript("OnClick", function()
                minBox:SetText(tostring(bracket.minLevel or ""))
                maxBox:SetText(tostring(bracket.maxLevel or ""))
                goldBox:SetText(tostring(bracket.gold or ""))
                minBox:SetFocus()
            end)
        end)

        place(bracketAddHeader, bracketAddHeader:GetHeight())
        place(bracketAdd, ROW_H)

        gap(SEC_GAP)
        place(rule, 1, PAD * 2)
        gap(SEC_GAP)

        place(overrideHeader, overrideHeader:GetHeight())
        placeHint(overrideHint)

        local characterKeys = {}
        for characterKey in pairs(gm.overrides) do table.insert(characterKeys, characterKey) end
        table.sort(characterKeys)

        placeTable(overrideBar, overrideRows, characterKeys, overrideEmpty, function(row, _, characterKey)
            Cell(row, "name", OC_NAME, 230):SetText(CharacterName(characterKey))
            Cell(row, "gold", OC_GOLD):SetText(tostring(gm.overrides[characterKey] or ""))
            row.removeBtn:SetText(S.gold.removeOverride)
            row.removeBtn:SetPoint("LEFT", OC_BTN, 0)
            row.removeBtn:SetScript("OnClick", function()
                gm.overrides[characterKey] = nil
                LayoutAll()
            end)
            row:SetScript("OnClick", function()
                selectedCharacter = characterKey
                characterDrop:SetDefaultText(CharacterName(characterKey))
                overrideGoldBox:SetText(tostring(gm.overrides[characterKey] or ""))
                overrideGoldBox:SetFocus()
            end)
        end)

        place(overrideAddHeader, overrideAddHeader:GetHeight())
        place(overrideAdd, ROW_H)

        content:SetHeight(-y + PAD)
    end

    -- ── Wiring ────────────────────────────────────────────────

    -- A new bracket wins any overlap: existing brackets keep the parts of their
    -- range it does not cover, and any bracket it covers entirely disappears.
    addBracketBtn:SetScript("OnClick", function()
        local low = tonumber(minBox:GetText())
        local high = tonumber(maxBox:GetText())
        local gold = tonumber(goldBox:GetText())
        if not (low and high and gold and low >= 1 and high >= low and gold > 0) then
            print(S.addon.prefix .. " " .. S.gold.invalidBracket)
            return
        end

        local gm = GoldConfig()
        local kept = {}
        for _, bracket in ipairs(gm.brackets) do
            local bracketLow = bracket.minLevel or 0
            local bracketHigh = bracket.maxLevel or 0
            if low > bracketHigh or high < bracketLow then
                table.insert(kept, bracket)
            else
                if bracketLow < low then
                    table.insert(kept, { minLevel = bracketLow, maxLevel = low - 1, gold = bracket.gold })
                end
                if bracketHigh > high then
                    table.insert(kept, { minLevel = high + 1, maxLevel = bracketHigh, gold = bracket.gold })
                end
            end
        end
        table.insert(kept, { minLevel = low, maxLevel = high, gold = gold })
        table.sort(kept, function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end)
        gm.brackets = kept

        minBox:SetText("")
        maxBox:SetText("")
        goldBox:SetText("")
        LayoutAll()
    end)

    addOverrideBtn:SetScript("OnClick", function()
        local gold = tonumber(overrideGoldBox:GetText())
        if not (selectedCharacter and gold and gold > 0) then
            print(S.addon.prefix .. " " .. S.gold.invalidOverride)
            return
        end
        GoldConfig().overrides[selectedCharacter] = gold
        overrideGoldBox:SetText("")
        selectedCharacter = nil
        characterDrop:SetDefaultText(S.gold.selectCharacter)
        LayoutAll()
    end)

    -- The hints wrap, so their height is only right once the scroll region has
    -- its real width. Height changes are ignored: laying out sets the height,
    -- which would otherwise call straight back in here.
    local lastWidth
    content:HookScript("OnSizeChanged", function(_, width)
        if width == lastWidth then return end
        lastWidth = width
        LayoutAll()
    end)

    WarbandStorage.RefreshGoldLists = LayoutAll
    LayoutAll()
end
