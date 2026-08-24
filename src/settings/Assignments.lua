-- Warband Stockist: Assignments page.
-- One row per known character, picking the profile it stocks from.

WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local ROW_HEIGHT = 40
local DIVIDER_HEIGHT = 24

local list          -- Fill scroll child holding the rows
local rowPool = {}
local divider

local function IsIgnored(characterKey)
    return WarbandStockistDB.ignoredCharacters and WarbandStockistDB.ignoredCharacters[characterKey] or false
end

local function BuildRow()
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW_HEIGHT)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.05)

    row.ignoreBtn = LuckyUI.CreateButton(row, S.assignments.ignore, 76, 22, "secondary")
    row.ignoreBtn:SetPoint("RIGHT", -6, 0)
    row.ignoreBtn:SetScript("OnClick", function()
        if IsIgnored(row.characterKey) then
            WarbandStorage.ProfileManager:UnignoreCharacter(row.characterKey)
        else
            WarbandStorage.ProfileManager:IgnoreCharacter(row.characterKey)
        end
    end)

    row.unassignBtn = LuckyUI.CreateButton(row, S.assignments.unassign, 86, 22, "secondary")
    row.unassignBtn:SetPoint("RIGHT", row.ignoreBtn, "LEFT", -6, 0)
    row.unassignBtn:SetScript("OnClick", function()
        WarbandStorage.ProfileManager:UnassignCharacter(row.characterKey)
    end)

    row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    row.dropdown:SetWidth(160)
    row.dropdown:SetPoint("RIGHT", row.unassignBtn, "LEFT", -8, 0)
    row.dropdown:SetupMenu(function(_, root)
        root:CreateRadio(S.assignments.unassigned,
            function() return WarbandStockistDB.assignments[row.characterKey] == nil end,
            function() WarbandStorage.ProfileManager:UnassignCharacter(row.characterKey) end)

        for _, name in ipairs(WarbandStorage:GetAllProfileNames()) do
            root:CreateRadio(name,
                function() return WarbandStockistDB.assignments[row.characterKey] == name end,
                function() WarbandStorage.ProfileManager:AssignProfile(row.characterKey, name) end)
        end
    end)

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

local function UpdateRow(row, characterKey, striped)
    row.characterKey = characterKey
    row.stripe:SetShown(striped)
    local name, realm, color = WarbandStorage.Utils:GetCharacterParts(characterKey)
    row.name:SetText(name)
    row.name:SetTextColor(color.r, color.g, color.b)
    row.realm:SetText(realm or "")
    row.dropdown:SetDefaultText(WarbandStockistDB.assignments[characterKey] or S.assignments.unassigned)

    local ignored = IsIgnored(characterKey)
    row.ignoreBtn:SetText(ignored and S.assignments.include or S.assignments.ignore)
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

local function ShowDivider(y)
    if not divider then
        divider = CreateFrame("Frame", nil, list)
        divider:SetHeight(DIVIDER_HEIGHT)

        local bg = divider:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(R.warn[1], R.warn[2], R.warn[3], 0.08)

        local label = divider:CreateFontString(nil, "OVERLAY")
        label:SetFont(R_FONT, 10, "")
        label:SetPoint("LEFT", 10, 0)
        label:SetText(string.upper(S.assignments.ignoredCharacters))
        label:SetTextColor(R.warn[1], R.warn[2], R.warn[3])
    end
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
    divider:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, y)
    divider:Show()
end

-- Global because the profile modules call it after any assignment change.
function RefreshAssignmentsList()
    if not list then return end
    local perfStart = WarbandStorage.Perf:Now()

    if divider then divider:Hide() end

    local y, used, striped = 0, 0, 0
    local dividerShown = false
    for _, characterKey in ipairs(WarbandStorage:GetAllCharacterKeys()) do
        if IsIgnored(characterKey) and not dividerShown then
            ShowDivider(y)
            y = y - DIVIDER_HEIGHT
            striped = 0
            dividerShown = true
        end
        used = used + 1
        striped = striped + 1
        UpdateRow(AcquireRow(used, y), characterKey, striped % 2 == 0)
        y = y - ROW_HEIGHT
    end

    for i = used + 1, #rowPool do rowPool[i]:Hide() end
    list:SetHeight(math.max(-y, 1))

    WarbandStorage.Perf:Count("RefreshAssignmentsList:rows", used)
    WarbandStorage.Perf:Add("RefreshAssignmentsList", perfStart)
end

function Settings.BuildAssignments(group)
    list = group:Fill()
    RefreshAssignmentsList()
end
