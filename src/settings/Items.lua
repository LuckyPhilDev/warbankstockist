WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local ROW_HEIGHT = 28
local CONTROL_HEIGHT = 24

local itemList          -- Fill scroll child holding the rows
local emptyLabel
local rowPool = {}

WarbandStorage.itemFilter = WarbandStorage.itemFilter or ""

local function BuildRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.05)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)

    -- Textures take no mouse input of their own, so the tooltip hangs off a
    -- frame sized to the icon.
    row.iconHit = CreateFrame("Frame", nil, row)
    row.iconHit:SetAllPoints(row.icon)
    row.iconHit:SetScript("OnEnter", function(self)
        if not row.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(row.itemID)
        GameTooltip:Show()
    end)
    row.iconHit:SetScript("OnLeave", GameTooltip_Hide)

    row.removeBtn = LuckyUI.CreateButton(row, S.tracked.remove, 70, 22, "danger")
    row.removeBtn:SetPoint("RIGHT", -6, 0)
    row.removeBtn:SetScript("OnClick", function()
        WarbandStorage.ProfileManager:RemoveItemFromProfile(row.itemID, Settings.EditedProfileName())
    end)

    row.qtyBox = Settings.NumberBox(row, 50)
    row.qtyBox:SetPoint("RIGHT", row.removeBtn, "LEFT", -8, 0)
    row.qtyBox:SetScript("OnEnterPressed", function(self)
        local qty = tonumber(self:GetText())
        if qty then
            WarbandStorage.ProfileManager:AddItemToProfile(row.itemID, qty, Settings.EditedProfileName())
        end
        self:ClearFocus()
    end)
    row.qtyBox:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(row.count or 0))
        self:ClearFocus()
    end)

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFont(R_FONT, 12, "")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.label:SetPoint("RIGHT", row.qtyBox, "LEFT", -8, 0)
    row.label:SetJustifyH("LEFT")

    return row
end

local function UpdateRow(row, striped, itemID, count)
    row.itemID = itemID
    row.count = count
    row.stripe:SetShown(striped)

    row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    row.icon:SetDesaturated((count or 0) == 0)
    row.qtyBox:SetText(tostring(count or 0))

    local name = WarbandStorage.Utils:GetItemName(itemID) or ("Item " .. tostring(itemID))
    local stocked = (count or 0) > 0
    row.label:SetText(name .. " |cff6b6250(" .. tostring(itemID) .. ")|r")
    if stocked then
        row.label:SetTextColor(R.text[1], R.text[2], R.text[3])
    else
        row.label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    end
end

local function AcquireRow(index)
    local perfStart = WarbandStorage.Perf:Now()
    local row = rowPool[index]
    if not row then
        row = BuildRow(itemList)
        rowPool[index] = row
        WarbandStorage.Perf:Count("itemRow:built")
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", itemList, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", itemList, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row:Show()
    WarbandStorage.Perf:Add("itemRow:acquire", perfStart)
    return row
end

-- Global because the profile and item modules call it after any change to the
-- edited profile's stock.
function RefreshItemList()
    if not itemList then return end
    local perfStart = WarbandStorage.Perf:Now()

    local stock = WarbandStorage:GetEditedProfile().items
    local filter = WarbandStorage.itemFilter ~= "" and WarbandStorage.itemFilter:lower() or nil

    -- Sorted rather than taken straight from the table, so a refresh does not
    -- reshuffle the list under the cursor.
    local matches, scanned = {}, 0
    for itemID, count in pairs(stock) do
        scanned = scanned + 1
        local name = WarbandStorage.Utils:GetItemName(itemID) or ""
        if not filter or (name .. " " .. itemID):lower():find(filter, 1, true) then
            table.insert(matches, { itemID = itemID, count = count, sortKey = name:lower() })
        end
    end
    table.sort(matches, function(a, b)
        if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
        return a.itemID < b.itemID
    end)

    local shown = #matches
    for index, match in ipairs(matches) do
        UpdateRow(AcquireRow(index), index % 2 == 0, match.itemID, match.count)
    end

    for i = shown + 1, #rowPool do rowPool[i]:Hide() end

    emptyLabel:SetText(scanned == 0 and S.tracked.empty or S.tracked.noMatches)
    emptyLabel:SetShown(shown == 0)
    -- The scroll frame clips its child, so the empty-state line needs the
    -- height an absent row would have taken.
    itemList:SetHeight(shown > 0 and shown * ROW_HEIGHT or 40)

    WarbandStorage.Perf:Count("RefreshItemList:itemsScanned", scanned)
    WarbandStorage.Perf:Count("RefreshItemList:rowsShown", shown)
    WarbandStorage.Perf:Add("RefreshItemList", perfStart)
end

local function BuildControls(strip)
    local search = LuckyUI.CreateSearchBox(strip, {
        width = 220,
        height = CONTROL_HEIGHT,
        placeholder = S.tracked.filterPlaceholder,
        onChange = function(query)
            WarbandStorage.itemFilter = query or ""
            RefreshItemList()
        end,
    })
    search:SetPoint("TOPLEFT", 14, -4)

    local idLabel = Settings.FieldLabel(strip, S.addItem.itemIdLabel)
    idLabel:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -12)

    local idBox = Settings.NumberBox(strip, 80, S.addItem.itemIdTooltip)
    idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)

    -- Dragging an item onto the box, or shift-clicking one into it, beats
    -- looking the ID up on a website.
    local function CaptureCursorItem(self)
        local cursorType, itemID, link = GetCursorInfo()
        if cursorType ~= "item" then return end
        local id = tonumber((link and link:match("item:(%d+)")) or itemID)
        if not id then return end
        self:SetText(tostring(id))
        ClearCursor()
    end
    idBox:SetScript("OnReceiveDrag", CaptureCursorItem)
    idBox:SetScript("OnMouseDown", CaptureCursorItem)

    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link)
        if not idBox:HasFocus() then return end
        local id = tonumber(link and link:match("item:(%d+)"))
        if not id then return end
        idBox:SetText(tostring(id))
        idBox:ClearFocus()
    end)

    local qtyLabel = Settings.FieldLabel(strip, S.addItem.qtyLabel)
    qtyLabel:SetPoint("LEFT", idBox, "RIGHT", 14, 0)

    local qtyBox = Settings.NumberBox(strip, 50, S.addItem.qtyTooltip)
    qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 8, 0)

    -- A profile that only deposits wants a quantity of 0, so seed the box from
    -- the profile rather than leaving it blank.
    function WarbandStorage.ResetItemInputQty()
        local zero = WarbandStorage:IsDefaultQtyZeroEnabled(Settings.EditedProfileName())
        qtyBox:SetText(zero and "0" or "")
    end
    WarbandStorage.ResetItemInputQty()

    -- Typing an ID re-seeds a quantity the user cleared, so the one-click
    -- deposit-only flow survives an edit. Never overwrites a typed quantity.
    idBox:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" or qtyBox:GetText() ~= "" then return end
        WarbandStorage.ResetItemInputQty()
    end)

    local addBtn = LuckyUI.CreateButton(strip, S.addItem.add, 60, CONTROL_HEIGHT, "primary")
    addBtn:SetPoint("LEFT", qtyBox, "RIGHT", 14, 0)
    Settings.Tooltip(addBtn, S.addItem.addTooltip)
    addBtn:SetScript("OnClick", function()
        local itemID = tonumber(idBox:GetText())
        local qty = tonumber(qtyBox:GetText())
        if not WarbandStorage.Utils:ValidateItemInput(itemID, qty) then
            WarbandStorage:DebugPrint("Invalid item ID or quantity.")
            return
        end
        WarbandStorage.ProfileManager:AddItemToProfile(itemID, qty, Settings.EditedProfileName())
        idBox:SetText("")
        WarbandStorage.ResetItemInputQty()
        WarbandStorage.ProfileManager:RefreshUI()
    end)

    local clearBtn = LuckyUI.CreateButton(strip, S.addItem.clear, 90, CONTROL_HEIGHT, "danger")
    clearBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    Settings.Tooltip(clearBtn, S.addItem.clearTooltip)
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("WBSTOCKIST_CLEAR_PROFILE_ITEMS", Settings.EditedProfileName())
    end)
end

function Settings.AddItems(group)
    group:Section(S.tracked.section)

    BuildControls(group:Frame(70))

    itemList = group:Fill()

    emptyLabel = itemList:CreateFontString(nil, "OVERLAY")
    emptyLabel:SetFont(R_FONT, 11, "")
    emptyLabel:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    emptyLabel:SetPoint("TOPLEFT", 6, -8)

    RefreshItemList()
end
