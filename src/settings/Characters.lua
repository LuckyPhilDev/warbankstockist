WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local Sets = WarbandStorage.Sets
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local ROW_HEIGHT = 40
local HEADING_HEIGHT = 24
local SET_LINE_HEIGHT = 20
local CARD_INSET = 6        -- the card sits in from the rows, so it reads as its own thing
local CARD_HEADER = 46      -- heading and hint above the first set name
local CARD_PADDING = 4      -- on top of the slack each set line already carries
local CARD_GAP = 14

local list          -- Fill scroll child holding the rows
local rowPool = {}
local setLinePool = {}
local headings = {} -- by label
local everyCard

-- One untick drops a set out of the top section and back onto the rows of the
-- characters that still have it, so the rows never hide a partial set.
local function IsOnEveryone(set)
    return set.everyCharacter and next(set.skip) == nil
end

-- everyone: the sets listed in the top section, left out here.
local function SetsSummary(characterKey, everyone)
    local names = {}
    for _, set in ipairs(Sets:All()) do
        if not everyone[set] and Sets:IsMember(set, characterKey) then names[#names + 1] = set.name end
    end
    if #names > 0 then return table.concat(names, ", ") end
    return next(everyone) and S.characters.noOtherSets or S.characters.noSets
end

-- Checkboxes keep the menu open, so several sets can be ticked in one go.
local function BuildSetsMenu(row, root)
    local characterKey = row.characterKey
    for _, set in ipairs(Sets:All()) do
        local label = set.everyCharacter and (set.name .. " " .. S.characters.everySuffix) or set.name
        root:CreateCheckbox(label,
            function() return Sets:IsMember(set, characterKey) end,
            function() Sets:SetMember(set.id, characterKey, not Sets:IsMember(set, characterKey)) end)
    end
end

local function BuildRow()
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_HEIGHT)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.05)

    row.ignoreBtn = LuckyUI.CreateButton(row, S.characters.ignore, 76, 22, "secondary")
    row.ignoreBtn:SetPoint("RIGHT", -6, 0)
    row.ignoreBtn:SetScript("OnClick", function()
        Sets:SetIgnored(row.characterKey, not Sets:IsIgnored(row.characterKey))
    end)

    row.priorityLabel = Settings.FieldLabel(row, S.characters.priority)
    row.priorityLabel:SetPoint("RIGHT", row.ignoreBtn, "LEFT", -12, 0)

    row.priority = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.priority:SetSize(20, 20)
    row.priority:SetPoint("RIGHT", row.priorityLabel, "LEFT", -2, 0)
    Settings.Tooltip(row.priority, S.characters.priorityDesc)
    row.priority:SetScript("OnClick", function(box)
        Sets:SetPriority(row.characterKey, box:GetChecked())
    end)

    row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.dropdown:SetWidth(200)
    row.dropdown:SetPoint("RIGHT", row.priority, "LEFT", -10, 0)
    row.dropdown:SetupMenu(function(_, root) BuildSetsMenu(row, root) end)

    -- Name and realm on separate lines: a realm on the same line pushed long
    -- names into a wrap, and repeating it in the class colour on every row read
    -- as noise rather than as the character's name.
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetFont(R_FONT, 12, "")
    row.name:SetPoint("TOPLEFT", 10, -6)
    row.name:SetPoint("TOPRIGHT", row.dropdown, "TOPLEFT", -8, -6)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.realm = row:CreateFontString(nil, "OVERLAY")
    row.realm:SetFont(R_FONT, 10, "")
    row.realm:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.realm:SetPoint("TOPRIGHT", row.name, "BOTTOMRIGHT", 0, -3)
    row.realm:SetJustifyH("LEFT")
    row.realm:SetWordWrap(false)
    row.realm:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])

    return row
end

local function UpdateRow(row, characterKey, striped, everyone)
    row.characterKey = characterKey
    row.stripe:SetShown(striped)
    local name, realm, color = WarbandStorage.Utils:GetCharacterParts(characterKey)
    row.name:SetText(name)
    row.name:SetTextColor(color.r, color.g, color.b)
    row.realm:SetText(realm or "")
    -- Joined here rather than from the menu's selections, which would carry
    -- the Every Character suffix into the closed dropdown.
    row.dropdown:OverrideText(SetsSummary(characterKey, everyone))
    row.priority:SetChecked(Sets:IsPriority(characterKey))

    local ignored = Sets:IsIgnored(characterKey)
    row.ignoreBtn:SetText(ignored and S.characters.include or S.characters.ignore)
    row:SetAlpha(ignored and 0.5 or 1)
end

local function AcquireRow(index, y)
    local row = rowPool[index]
    if not row then
        row = BuildRow()
        rowPool[index] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, y)
    row:Show()
    return row
end

-- Returns the y below the heading.
local function ShowHeading(text, color, y)
    local heading = headings[text]
    if not heading then
        heading = CreateFrame("Frame", nil, list)
        heading:SetHeight(HEADING_HEIGHT)

        local bg = heading:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(color[1], color[2], color[3], 0.08)

        local label = heading:CreateFontString(nil, "OVERLAY")
        label:SetFont(R_FONT, 10, "")
        label:SetPoint("LEFT", 10, 0)
        label:SetText(string.upper(text))
        label:SetTextColor(color[1], color[2], color[3])
        headings[text] = heading
    end
    heading:ClearAllPoints()
    heading:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
    heading:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, y)
    heading:Show()
    return y - HEADING_HEIGHT
end

local function EveryCard()
    if everyCard then return everyCard end

    everyCard = CreateFrame("Frame", nil, list, "BackdropTemplate")
    everyCard:SetPoint("TOPLEFT", list, "TOPLEFT", CARD_INSET, 0)
    everyCard:SetPoint("TOPRIGHT", list, "TOPRIGHT", -CARD_INSET, 0)
    everyCard:SetBackdrop(LuckyUI.Backdrop)
    everyCard:SetBackdropColor(R.accent[1], R.accent[2], R.accent[3], 0.07)
    everyCard:SetBackdropBorderColor(R.accent[1], R.accent[2], R.accent[3], 0.35)

    local heading = everyCard:CreateFontString(nil, "OVERLAY")
    heading:SetFont(R_FONT, 10, "")
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetText(string.upper(S.characters.everyHeading))
    heading:SetTextColor(R.accent[1], R.accent[2], R.accent[3])

    local hint = everyCard:CreateFontString(nil, "OVERLAY")
    hint:SetFont(R_FONT, 11, "")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    hint:SetText(S.characters.everyHint)
    hint:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])

    return everyCard
end

-- Returns the y below the line, in the card's own coordinates.
local function ShowSetLine(index, name, y)
    local line = setLinePool[index]
    if not line then
        line = everyCard:CreateFontString(nil, "OVERLAY")
        line:SetFont(R_FONT, 12, "")
        line:SetTextColor(R.text[1], R.text[2], R.text[3])
        setLinePool[index] = line
    end
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", everyCard, "TOPLEFT", 20, y)
    line:SetText(name)
    line:Show()
    return y - SET_LINE_HEIGHT
end

-- Returns the lookup of sets on the card, and the y the rows start at.
local function ShowEveryoneSets()
    local everyone, names = {}, {}
    for _, set in ipairs(Sets:All()) do
        if IsOnEveryone(set) then
            everyone[set] = true
            names[#names + 1] = set.name
        end
    end

    if #names == 0 then
        if everyCard then everyCard:Hide() end
        return everyone, 0
    end

    local card = EveryCard()
    local y = -CARD_HEADER
    for i, name in ipairs(names) do y = ShowSetLine(i, name, y) end
    for i = #names + 1, #setLinePool do setLinePool[i]:Hide() end

    card:SetHeight(-y + CARD_PADDING)
    card:Show()
    return everyone, -card:GetHeight() - CARD_GAP
end

local function RefreshCharacters()
    local perfStart = WarbandStorage.Perf:Now()
    for _, heading in pairs(headings) do heading:Hide() end

    local everyone, y = ShowEveryoneSets()
    if next(everyone) then y = ShowHeading(S.characters.charactersHeading, R.textDim, y) end

    local used, striped = 0, 0
    local ignoredShown = false
    for _, characterKey in ipairs(Sets:AllCharacterKeys()) do
        if Sets:IsIgnored(characterKey) and not ignoredShown then
            y = ShowHeading(S.characters.ignoredCharacters, R.warn, y)
            striped = 0
            ignoredShown = true
        end
        used = used + 1
        striped = striped + 1
        UpdateRow(AcquireRow(used, y), characterKey, striped % 2 == 0, everyone)
        y = y - ROW_HEIGHT
    end

    for i = used + 1, #rowPool do rowPool[i]:Hide() end
    list:SetHeight(math.max(-y, 1))

    WarbandStorage.Perf:Count("RefreshCharacters:rows", used)
    WarbandStorage.Perf:Add("RefreshCharacters", perfStart)
end

function Settings.BuildCharacters(group)
    list = group:Fill()
    Settings.OnRefresh(RefreshCharacters)
    RefreshCharacters()
end
