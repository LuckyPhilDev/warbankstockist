WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local Sets = WarbandStorage.Sets
local Standard = WarbandStorage.StandardSets
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

-- Only remembers which set this page shows. The bank never reads it.
local function EditedSet()
    return Sets:Get(WarbandStockistDB.lastEditedSet) or Sets:All()[1]
end

local function EditSet(set)
    WarbandStockistDB.lastEditedSet = set.id
    Settings.Refresh()
end

local function StandardDescription(set)
    local kind = Standard.kinds[set.standard]
    if not kind then return "" end
    if kind.reagent then return S.standard.reagentDesc:format(S.standard[set.standard]) end
    return S.standard[set.standard .. "Desc"]
end

-- Reagent categories sit in a submenu of their own, ahead of the other kinds.
local function OpenNewMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(S.sets.newEmpty, function() StaticPopup_Show("WBSTOCKIST_NEW_SET") end)
        root:CreateDivider()
        root:CreateTitle(S.sets.newStandard)
        local reagents = root:CreateButton(S.sets.newReagents)
        for _, kind in ipairs(Standard.order) do
            local menu = Standard.kinds[kind].reagent and reagents or root
            menu:CreateButton(S.standard[kind], function() EditSet(Sets:AddStandard(kind)) end)
        end
    end)
end

local function FillSetOptions(options)
    wipe(options)
    for _, set in ipairs(Sets:All()) do
        options[#options + 1] = { key = set.id, label = set.name }
    end
end

local function SetRowEnabled(setting, enabled)
    local control = setting.checkbox or setting.dropdown
    control:SetEnabled(enabled)
    setting.row:SetAlpha(enabled and 1 or 0.35)
end

local function UsedByText(set)
    local names = {}
    for _, charKey in ipairs(Sets:CharactersUsing(set.id)) do
        local name, _, color = WarbandStorage.Utils:GetCharacterParts(charKey)
        names[#names + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255), math.floor(color.g * 255), math.floor(color.b * 255), name)
    end
    return #names > 0 and table.concat(names, ", ") or S.sets.usedByNone
end

local function ShowAssignments(panel)
    for _, other in ipairs(panel.groups) do
        if other.name == S.characters.section then
            panel:SetActiveGroup(other)
            return
        end
    end
end

-- A Label row cannot change its value once built, so this draws its own.
local function AddUsedByRow(group)
    local frame = group:Frame(22)
    frame:EnableMouse(true)

    local key = frame:CreateFontString(nil, "OVERLAY")
    key:SetFont(R_FONT, 11, "")
    key:SetPoint("LEFT", 14, 0)
    key:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    key:SetText(S.sets.usedBy)

    local value = frame:CreateFontString(nil, "OVERLAY")
    value:SetFont(R_FONT, 11, "")
    value:SetPoint("LEFT", key, "RIGHT", 8, 0)
    value:SetPoint("RIGHT", -14, 0)
    value:SetJustifyH("LEFT")
    value:SetWordWrap(false)
    value:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])

    -- The names carry their own class colours, so the label is what lights up.
    frame:SetScript("OnEnter", function(self)
        key:SetTextColor(R.text[1], R.text[2], R.text[3])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(S.sets.usedBy, 1, 0.82, 0)
        GameTooltip:AddLine(S.sets.usedByTooltip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        key:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
        GameTooltip_Hide()
    end)
    frame:SetScript("OnMouseUp", function() ShowAssignments(group.panel) end)

    return value
end

local function AddSetButtons(group)
    group:ButtonRow({ buttons = {
        { label = S.sets.new, desc = S.sets.newDesc, icon = "plus",
          onClick = function() OpenNewMenu(group.byLabel[S.sets.new].button) end },

        { label = S.sets.rename, desc = S.sets.renameDesc, icon = "pencil",
          onClick = function() StaticPopup_Show("WBSTOCKIST_RENAME_SET", nil, nil, EditedSet().id) end },

        { label = S.sets.duplicate, desc = S.sets.duplicateDesc, icon = "copy",
          onClick = function() EditSet(Sets:Duplicate(EditedSet().id)) end },

        { label = S.sets.delete, desc = S.sets.deleteDesc, icon = "trash",
          onClick = function()
              local set = EditedSet()
              StaticPopup_Show("WBSTOCKIST_DELETE_SET", set.name, nil, set.id)
          end },
    } })
end

local function AddOptionToggle(group, label, desc, since, key, apply)
    group:Toggle({
        label    = label,
        desc     = desc,
        since    = since,
        checked  = function()
            local set = EditedSet()
            return set ~= nil and set[key] == true
        end,
        onToggle = function(checked) apply(EditedSet().id, checked) end,
    })
    AddRowTooltip(group.byLabel[label], label, desc)
end

-- A dropdown keeps showing its last pick until its menu is generated again;
-- the library's refresh only sets the text shown when nothing is picked.
local function RedrawSelect(setting)
    setting.refreshSelect()
    setting.dropdown:GenerateMenu()
end

-- The library only re-reads row state when the panel opens, so switching or
-- changing a set mid-panel redraws these rows by hand.
local function Sync(group, options, usedBy, list)
    local set = EditedSet()
    local hasSet = set ~= nil
    local keeps = hasSet and set.type == "keep"
    local standard = hasSet and Standard.kinds[set.standard]

    FillSetOptions(options)
    RedrawSelect(group.byLabel[S.sets.label])

    for _, label in ipairs({ S.sets.rename, S.sets.duplicate, S.sets.delete }) do
        local button = group.byLabel[label].button
        button:SetEnabled(hasSet)
        button:SetAlpha(hasSet and 1 or 0.35)
    end

    local typeRow = group.byLabel[S.sets.type]
    RedrawSelect(typeRow)
    SetRowEnabled(typeRow, hasSet and not set.standard)

    for label, enabled in pairs({
        [S.sets.returnExtras]     = keeps,
        [S.sets.everyCharacter]   = hasSet,
        [S.lowStock.toggle]       = keeps,
        [S.sets.currentExpansion] = standard and standard.reagent == true,
    }) do
        local row = group.byLabel[label]
        row.checkbox:SetChecked(row.getChecked())
        SetRowEnabled(row, enabled)
    end

    usedBy:SetText(hasSet and UsedByText(set) or "")
    list:Refresh()
end

function Settings.BuildSets(group)
    local options = {}
    FillSetOptions(options)
    group:Select({
        label    = S.sets.label,
        desc     = S.sets.labelDesc,
        options  = options,
        value    = function()
            local set = EditedSet()
            return set and set.id
        end,
        onSelect = function(id) EditSet(Sets:Get(id)) end,
    })
    AddRowTooltip(group.byLabel[S.sets.label], S.sets.label, function()
        local set = EditedSet()
        return set and set.standard and StandardDescription(set) or S.sets.labelDesc
    end)
    AddSetButtons(group)
    local usedBy = AddUsedByRow(group)

    group:Select({
        label    = S.sets.type,
        desc     = S.sets.typeDesc,
        options  = {
            { key = "keep", label = S.sets.typeKeep },
            { key = "deposit", label = S.sets.typeDeposit },
        },
        value    = function()
            local set = EditedSet()
            return set and set.type
        end,
        onSelect = function(key) Sets:SetOption(EditedSet().id, "type", key) end,
    })
    AddOptionToggle(group, S.sets.returnExtras, S.sets.returnExtrasDesc, SINCE, "returnExtras",
        function(id, on) Sets:SetOption(id, "returnExtras", on) end)
    AddOptionToggle(group, S.sets.everyCharacter, S.sets.everyCharacterDesc, SINCE, "everyCharacter",
        function(id, on) Sets:SetEveryCharacter(id, on) end)
    AddOptionToggle(group, S.lowStock.toggle, S.lowStock.tooltip, "1.12.0", "lowStockWarning",
        function(id, on) Sets:SetOption(id, "lowStockWarning", on) end)
    AddOptionToggle(group, S.sets.currentExpansion, S.sets.currentExpansionDesc, nil, "currentExpansionOnly",
        function(id, on) Sets:SetOption(id, "currentExpansionOnly", on) end)

    group:Section(S.items.section)
    local list = Settings.CreateItemList(group, {
        enabled    = function()
            local set = EditedSet()
            return set ~= nil and not set.standard
        end,
        showQty    = function()
            local set = EditedSet()
            return set ~= nil and set.type == "keep"
        end,
        entries    = function()
            local set = EditedSet()
            if not set then return {} end
            return set.standard and Standard.Resolve(set).items or set.items
        end,
        setQty     = function(itemID, qty) Sets:SetItem(EditedSet().id, itemID, qty) end,
        remove     = function(itemID) Sets:RemoveItem(EditedSet().id, itemID) end,
        clear      = function()
            local set = EditedSet()
            StaticPopup_Show("WBSTOCKIST_CLEAR_SET_ITEMS", set.name, nil, set.id)
        end,
        qtyLabel   = S.items.keep,
        qtyTooltip = S.items.keepTooltip,
        emptyText  = function()
            local set = EditedSet()
            if not set then return S.sets.none end
            return set.standard and StandardDescription(set) or S.items.empty
        end,
        tag        = function(itemID)
            local reserve = Sets:GetReserve(itemID)
            return reserve and S.items.reserveTag:format(reserve)
        end,
    })

    Settings.OnRefresh(function() Sync(group, options, usedBy, list) end)
    Sync(group, options, usedBy, list)
end

local function FocusPopup(dialog, text)
    local editBox = dialog:GetEditBox()
    editBox:SetText(text or "")
    if text then editBox:HighlightText() end
    editBox:SetFocus()
end

local function AcceptOnEnter(editBox)
    StaticPopup_OnClick(editBox:GetParent(), 1)
end

StaticPopupDialogs["WBSTOCKIST_NEW_SET"] = {
    text = S.sets.newPrompt,
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self) FocusPopup(self) end,
    EditBoxOnEnterPressed = AcceptOnEnter,
    OnAccept = function(self)
        local ok, name = WarbandStorage.Utils:ValidateSetName(self:GetEditBox():GetText())
        if ok then EditSet(Sets:Create(name)) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WBSTOCKIST_RENAME_SET"] = {
    text = S.sets.renamePrompt,
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self, id) FocusPopup(self, Sets:Get(id).name) end,
    EditBoxOnEnterPressed = AcceptOnEnter,
    -- The set it opened for, which may no longer be the one on the page, or
    -- may have been deleted since.
    OnAccept = function(self, id)
        local set = Sets:Get(id)
        if not set then return end
        local ok, name = WarbandStorage.Utils:ValidateSetName(self:GetEditBox():GetText(), set.name)
        if ok and name ~= set.name then Sets:Rename(set.id, name) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WBSTOCKIST_DELETE_SET"] = {
    text = S.sets.deletePrompt,
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(_, id) Sets:Delete(id) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WBSTOCKIST_CLEAR_SET_ITEMS"] = {
    text = S.items.clearPrompt,
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(_, id)
        if Sets:Get(id) then Sets:ClearItems(id) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
