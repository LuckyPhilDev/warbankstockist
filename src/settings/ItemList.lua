WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local ROW_HEIGHT = 28
local CONTROL_HEIGHT = 24
local DIM = ("|cff%02x%02x%02x"):format(math.floor(R.textDim[1] * 255), math.floor(R.textDim[2] * 255), math.floor(R.textDim[3] * 255))

local ItemList = {}
ItemList.__index = ItemList

local function Resolve(value)
    if type(value) == "function" then return value() end
    return value
end

local function ItemIDFromLink(link)
    return tonumber(link and link:match("item:(%d+)"))
end

-- Blizzard bakes the rank into some item names and not others, so the name is
-- stripped of it and every ranked item gets the game's own icon back.
-- Markup cannot be desaturated, so a greyed icon is tinted dark instead.
local function QualityIcon(itemID, greyed)
    local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID) or C_TradeSkillUI.GetItemCraftedQualityInfo(itemID)
    if not info then return "" end
    local tint = greyed and 90 or 255
    return CreateAtlasMarkup(info.iconChat, 17, 15, 1, 0, tint, tint, tint) .. " "
end

local function ToggleButton(row, icon, title, text)
    local button = LuckyUI.CreateIconButton(row, {
        icon = icon,
        size = 18,
        tooltip = function(tooltip)
            tooltip:SetText(title, 1, 0.82, 0)
            tooltip:AddLine(text, 1, 1, 1, true)
        end,
    })
    button:SetPoint("RIGHT", -10, 0)
    return button
end

function ItemList:BuildRow()
    local opts = self.opts
    local row = CreateFrame("Frame", nil, self.scroll)
    row:SetHeight(ROW_HEIGHT)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(R.accent[1], R.accent[2], R.accent[3], 0.05)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)

    -- A square of the rarity colour a pixel wider than the icon on each side,
    -- drawn beneath it so only the rim shows.
    row.rarityBorder = row:CreateTexture(nil, "BORDER")
    row.rarityBorder:SetPoint("TOPLEFT", row.icon, -1, 1)
    row.rarityBorder:SetPoint("BOTTOMRIGHT", row.icon, 1, -1)

    -- Textures take no mouse input of their own, so the tooltip hangs off a
    -- frame sized to the icon.
    row.iconHit = CreateFrame("Frame", nil, row)
    row.iconHit:SetAllPoints(row.icon)
    row.iconHit:SetScript("OnEnter", function(hit)
        GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(row.itemID)
        GameTooltip:Show()
    end)
    row.iconHit:SetScript("OnLeave", GameTooltip_Hide)

    row.removeBtn = LuckyUI.CreateButton(row, S.items.remove, 70, 22, "danger")
    row.removeBtn:SetPoint("RIGHT", -6, 0)
    row.removeBtn:SetScript("OnClick", function() opts.remove(row.itemID) end)

    -- Two buttons rather than one that swaps its art, so each keeps the
    -- library's tinting.
    row.excludeBtn = ToggleButton(row, "x", S.items.exclude, S.items.excludeTooltip)
    row.excludeBtn:SetScript("OnClick", function() opts.setExcluded(row.itemID, true) end)
    row.includeBtn = ToggleButton(row, "plus", S.items.include, S.items.includeTooltip)
    row.includeBtn:SetScript("OnClick", function() opts.setExcluded(row.itemID, false) end)

    row.qtyBox = Settings.NumberBox(row, 50)
    row.qtyBox:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        local qty = tonumber(box:GetText())
        if qty then opts.setQty(row.itemID, qty) end
    end)
    row.qtyBox:SetScript("OnEscapePressed", function(box)
        box:SetText(tostring(row.qty or 0))
        box:ClearFocus()
    end)

    row.qtyLabel = Settings.FieldLabel(row, opts.qtyLabel)
    row.qtyLabel:SetPoint("RIGHT", row.qtyBox, "LEFT", -6, 0)

    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetFont(R_FONT, 12, "")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    return row
end

function ItemList:AcquireRow(index)
    local row = self.rows[index]
    if not row then
        row = self:BuildRow()
        self.rows[index] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.scroll, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", self.scroll, "TOPRIGHT", 0, -(index - 1) * ROW_HEIGHT)
    row:Show()
    return row
end

function ItemList:UpdateRow(row, index, itemID, qty)
    -- A re-sort can hand this row another item mid-typing; what was typed
    -- belongs to the old one.
    if row.itemID ~= itemID then row.qtyBox:ClearFocus() end
    row.itemID, row.qty = itemID, qty
    row.stripe:SetShown(index % 2 == 0)

    local excluded = self.excludable and self.opts.excluded(itemID) == true
    local dim = excluded or (self.showQty and (qty or 0) == 0)
    row.icon:SetTexture(C_Item.GetItemIconByID(itemID))
    row.icon:SetDesaturated(dim)
    row.icon:SetAlpha(excluded and 0.4 or 1)
    row.label:SetAlpha(excluded and 0.6 or 1)

    -- GetItemQualityByID answers nil for an item the client has not cached,
    -- which is most of a standard set's catalog; LuckyItem kept the quality
    -- when it loaded the name.
    local loaded = LuckyItem:GetCached(itemID)
    local rarity = ITEM_QUALITY_COLORS[loaded and loaded.quality or C_Item.GetItemQualityByID(itemID)]
    if excluded then rarity = { r = R.textDim[1], g = R.textDim[2], b = R.textDim[3] } end
    if rarity then row.rarityBorder:SetColorTexture(rarity.r, rarity.g, rarity.b, dim and 0.35 or 1) end
    row.rarityBorder:SetShown(rarity ~= nil)

    row.qtyLabel:SetShown(self.showQty)
    row.qtyBox:SetShown(self.showQty)
    row.qtyBox:SetEnabled(self.editable)
    row.removeBtn:SetShown(self.editable)
    row.excludeBtn:SetShown(self.excludable and not excluded)
    row.includeBtn:SetShown(excluded)
    -- A refresh can land while a quantity is being typed.
    if not row.qtyBox:HasFocus() then row.qtyBox:SetText(tostring(qty or 0)) end
    local rightmost = self.excludable and row.excludeBtn or row.removeBtn
    row.qtyBox:SetPoint("RIGHT", rightmost, "LEFT", -8, 0)
    row.label:SetPoint("RIGHT", self.showQty and row.qtyLabel or rightmost, "LEFT", -8, 0)

    local name = WarbandStorage.Utils:GetItemName(itemID) or S.items.unknownItem:format(itemID)
    local text = QualityIcon(itemID, excluded) .. name:gsub("%s*|A.-|a", "") .. " |cff6b6250(" .. itemID .. ")|r"
    local tag = self.opts.tag and self.opts.tag(itemID)
    if tag then text = text .. "   " .. DIM .. tag .. "|r" end
    row.label:SetText(text)
    local color = dim and R.textDim or R.text
    row.label:SetTextColor(color[1], color[2], color[3])
end

function ItemList:Refresh()
    local opts = self.opts
    local perfStart = WarbandStorage.Perf:Now()

    local enabled = Resolve(opts.enabled) ~= false
    self.editable = enabled
    self.showQty = Resolve(opts.showQty) ~= false
    self.excludable = Resolve(opts.excludable) == true
    for _, control in ipairs(self.controls) do
        control:SetEnabled(enabled)
        control:SetAlpha(enabled and 1 or 0.35)
    end
    self.qtyLabel:SetShown(self.showQty)
    self.qtyBox:SetShown(self.showQty)
    self.addBtn:SetPoint("LEFT", self.showQty and self.qtyBox or self.idBox, "RIGHT", 14, 0)

    local filter = self.filter ~= "" and self.filter:lower() or nil
    local matches, scanned = {}, 0
    for itemID, qty in pairs(opts.entries()) do
        scanned = scanned + 1
        local name = WarbandStorage.Utils:GetItemName(itemID) or ""
        if not filter or (name .. " " .. itemID):lower():find(filter, 1, true) then
            local group = opts.group and opts.group(itemID) or -math.huge
            matches[#matches + 1] = { itemID = itemID, qty = qty, group = group, sortKey = name:lower() }
        end
    end
    -- Sorted rather than taken straight from the table, so a refresh does not
    -- reshuffle the list under the cursor.
    table.sort(matches, function(a, b)
        if a.group ~= b.group then return a.group > b.group end
        if a.sortKey ~= b.sortKey then return a.sortKey < b.sortKey end
        return a.itemID < b.itemID
    end)

    for index, match in ipairs(matches) do
        self:UpdateRow(self:AcquireRow(index), index, match.itemID, match.qty)
    end
    for i = #matches + 1, #self.rows do self.rows[i]:Hide() end

    self.emptyLabel:SetText(scanned == 0 and Resolve(opts.emptyText) or S.items.noMatches)
    self.emptyLabel:SetShown(#matches == 0)
    -- The scroll frame clips its child, so the empty-state line needs the
    -- height an absent row would have taken.
    self.scroll:SetHeight(#matches > 0 and #matches * ROW_HEIGHT or math.max(40, self.emptyLabel:GetStringHeight() + 16))

    WarbandStorage.Perf:Add("ItemList:Refresh", perfStart)
end

function ItemList:BuildControls(strip)
    local list, opts = self, self.opts

    local search = LuckyUI.CreateSearchBox(strip, {
        width = 220,
        height = CONTROL_HEIGHT,
        placeholder = S.items.filterPlaceholder,
        onChange = function(query)
            list.filter = query or ""
            list:Refresh()
        end,
    })
    search:SetPoint("TOPLEFT", 14, -4)

    local idLabel = Settings.FieldLabel(strip, S.items.itemIdLabel)
    idLabel:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -12)

    local idBox = Settings.NumberBox(strip, 80, S.items.itemIdTooltip)
    idBox:SetPoint("LEFT", idLabel, "RIGHT", 8, 0)

    -- Dragging an item onto the box, or shift-clicking one into it, beats
    -- looking the ID up on a website.
    local function CaptureCursorItem(box)
        local cursorType, itemID, link = GetCursorInfo()
        if cursorType ~= "item" then return end
        local id = ItemIDFromLink(link) or tonumber(itemID)
        if not id then return end
        box:SetText(tostring(id))
        ClearCursor()
    end
    idBox:SetScript("OnReceiveDrag", CaptureCursorItem)
    idBox:SetScript("OnMouseDown", CaptureCursorItem)

    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link)
        if not idBox:HasFocus() then return end
        local id = ItemIDFromLink(link)
        if not id then return end
        idBox:SetText(tostring(id))
        idBox:ClearFocus()
    end)

    local qtyLabel = Settings.FieldLabel(strip, opts.qtyLabel)
    qtyLabel:SetPoint("LEFT", idBox, "RIGHT", 14, 0)

    local qtyBox = Settings.NumberBox(strip, 50, opts.qtyTooltip)
    qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 8, 0)

    local addBtn = LuckyUI.CreateButton(strip, S.items.add, 60, CONTROL_HEIGHT, "primary")
    addBtn:SetPoint("LEFT", qtyBox, "RIGHT", 14, 0)
    Settings.Tooltip(addBtn, S.items.addTooltip)
    addBtn:SetScript("OnClick", function()
        local itemID = tonumber(idBox:GetText())
        local qty = 0
        if list.showQty and qtyBox:GetText() ~= "" then qty = tonumber(qtyBox:GetText()) end
        if not WarbandStorage.Utils:ValidateItemInput(itemID, qty) then
            WarbandStorage:DebugPrint("Invalid item ID or quantity.")
            return
        end
        idBox:SetText("")
        qtyBox:SetText("")
        opts.setQty(itemID, qty)
    end)

    -- The search box stays usable on a locked list: a standard set lists
    -- hundreds of items worth searching.
    self.controls = { idBox, qtyBox, addBtn }
    if opts.clear then
        local clearBtn = LuckyUI.CreateButton(strip, S.items.clear, 90, CONTROL_HEIGHT, "danger")
        clearBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
        Settings.Tooltip(clearBtn, S.items.clearTooltip)
        clearBtn:SetScript("OnClick", function() opts.clear() end)
        table.insert(self.controls, clearBtn)
    end

    self.idBox, self.qtyLabel, self.qtyBox, self.addBtn = idBox, qtyLabel, qtyBox, addBtn
end

--- A list whose `enabled` is false still shows its entries; it is the controls
--- and the per-row Remove and Keep boxes that lock, so a rule-driven set can
--- list the items it currently matches.
--- opts: entries() -> { [itemID] = qty }, setQty(itemID, qty), remove(itemID),
--- qtyLabel, qtyTooltip, emptyText (string or function), and optionally
--- clear() for a Clear List button, enabled(), showQty(), tag(itemID) and
--- group(itemID), a number the list sorts by, highest first, before names.
--- excludable() swaps Remove for an Exclude button that greys the row out
--- instead, reading excluded(itemID) and calling setExcluded(itemID, on).
--- Must be the last thing added to the group: the list fills what is left.
function Settings.CreateItemList(group, opts)
    local list = setmetatable({ opts = opts, filter = "", rows = {} }, ItemList)
    list:BuildControls(group:Frame(70))
    list.scroll = group:Fill()

    list.emptyLabel = list.scroll:CreateFontString(nil, "OVERLAY")
    list.emptyLabel:SetFont(R_FONT, 11, "")
    list.emptyLabel:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    list.emptyLabel:SetPoint("TOPLEFT", 6, -8)
    list.emptyLabel:SetPoint("RIGHT", -6, 0)
    list.emptyLabel:SetJustifyH("LEFT")

    list:Refresh()
    return list
end
