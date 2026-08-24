-- Warband Stockist: Profiles page.
-- Picks the profile being edited, manages the profile list, carries the
-- per-profile deposit options, and hosts that profile's item list below them.

WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings

local DEPOSIT_ROWS = {
    { label = S.deposit.excess,
      desc  = S.deposit.excessTooltip,
      get   = function(name) return WarbandStorage:IsExcessDepositEnabled(name) end,
      set   = function(name, on) WarbandStorage:SetExcessDepositEnabled(name, on) end },

    { label = S.deposit.sortAfter,
      desc  = S.deposit.sortAfterTooltip,
      get   = function(name) return WarbandStorage:IsSortAfterDepositEnabled(name) end,
      set   = function(name, on) WarbandStorage:SetSortAfterDepositEnabled(name, on) end },

    { label  = S.deposit.defaultQtyZero,
      desc   = S.deposit.defaultQtyZeroTooltip,
      parent = S.deposit.excess,
      get    = function(name) return WarbandStorage:IsDefaultQtyZeroEnabled(name) end,
      set    = function(name, on) WarbandStorage:SetDefaultQtyZeroEnabled(name, on) end },
}

-- Switching profile mid-panel has to redraw these rows by hand: the library
-- only re-reads row state when the panel opens.
local function SyncDepositRows(group)
    -- The picker registers this before its rows exist, so a refresh triggered
    -- mid-build has nothing to sync yet.
    if not group.byLabel[DEPOSIT_ROWS[1].label] then return end

    local name = Settings.EditedProfileName()
    for _, spec in ipairs(DEPOSIT_ROWS) do
        group.byLabel[spec.label].checkbox:SetChecked(spec.get(name) and true or false)
    end
    for _, spec in ipairs(DEPOSIT_ROWS) do
        if spec.parent then
            local row = group.byLabel[spec.label]
            local enabled = group.byLabel[spec.parent].checkbox:GetChecked() and true or false
            row.checkbox:SetEnabled(enabled)
            row.row:SetAlpha(enabled and 1 or 0.35)
        end
    end
    if WarbandStorage.ResetItemInputQty then WarbandStorage.ResetItemInputQty() end
end

local function AddProfileButtons(group)
    group:ButtonRow({ buttons = {
        { label = S.profiles.new, desc = S.profiles.newDesc, icon = "plus",
          onClick = function() StaticPopup_Show("WBSTOCKIST_NEW_PROFILE") end },

        { label = S.profiles.rename, desc = S.profiles.renameDesc, icon = "pencil",
          onClick = function() StaticPopup_Show("WBSTOCKIST_RENAME_PROFILE") end },

        { label = S.profiles.duplicate, desc = S.profiles.duplicateDesc, icon = "copy",
          onClick = function()
              local name = Settings.EditedProfileName()
              local copy = name .. " Copy"
              WarbandStorage.ProfileManager:DuplicateProfile(name, copy)
              Settings.SetEditedProfile(copy)
          end },

        { label = S.profiles.delete, desc = S.profiles.deleteDesc, icon = "trash",
          onClick = function()
              StaticPopup_Show("WBSTOCKIST_DELETE_PROFILE", Settings.EditedProfileName())
          end },
    } })
end

function Settings.BuildProfiles(group)
    Settings.AddProfileSelect(group, function() SyncDepositRows(group) end)
    AddProfileButtons(group)

    group:Section(S.deposit.section)
    for _, spec in ipairs(DEPOSIT_ROWS) do
        group:Toggle({
            label    = spec.label,
            desc     = spec.desc,
            parent   = spec.parent,
            checked  = function() return spec.get(Settings.EditedProfileName()) end,
            onToggle = function(checked)
                spec.set(Settings.EditedProfileName(), checked)
                -- Turning excess deposit off takes the zero default with it, so
                -- every row on this page reseeds the quantity box.
                if WarbandStorage.ResetItemInputQty then WarbandStorage.ResetItemInputQty() end
            end,
        })
    end

    Settings.AddItems(group)
end

-- ############################################################
-- ## Profile dialogs
-- ############################################################

local function PopupText(frame)
    local editBox = frame and (frame.editBox or frame.EditBox)
    return editBox and editBox:GetText() or nil
end

local function FocusPopup(frame, text)
    local editBox = frame.editBox or frame.EditBox
    if not editBox then return end
    editBox:SetText(text or "")
    if text then editBox:HighlightText() end
    editBox:SetFocus()
end

StaticPopupDialogs["WBSTOCKIST_NEW_PROFILE"] = {
    text = S.profiles.newPrompt,
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self) FocusPopup(self) end,
    EditBoxOnEnterPressed = function(editBox) editBox:GetParent().button1:Click() end,
    OnAccept = function(self)
        local ok, cleaned = WarbandStorage.Utils:ValidateProfileName(PopupText(self))
        if not ok then return end
        WarbandStorage.ProfileManager:CreateProfile(cleaned)
        WarbandStorage:SetEditedProfileName(cleaned)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WBSTOCKIST_RENAME_PROFILE"] = {
    text = S.profiles.renamePrompt,
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self) FocusPopup(self, WarbandStorage:GetEditedProfileName()) end,
    EditBoxOnEnterPressed = function(editBox) editBox:GetParent().button1:Click() end,
    OnAccept = function(self)
        local oldName = WarbandStorage:GetEditedProfileName()
        local ok, cleaned = WarbandStorage.Utils:ValidateProfileName(PopupText(self), oldName)
        if not ok or cleaned == oldName then return end
        WarbandStorage.ProfileManager:RenameProfile(oldName, cleaned)
        WarbandStorage:SetEditedProfileName(cleaned)
        WarbandStorage.ProfileManager:RefreshUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WBSTOCKIST_DELETE_PROFILE"] = {
    text = S.profiles.deletePrompt,
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function()
        local name = WarbandStorage:GetEditedProfileName()
        WarbandStorage.ProfileManager:DeleteProfile(name)
        local remaining = WarbandStorage:GetAllProfileNames()[1]
        if remaining then WarbandStorage:SetEditedProfileName(remaining) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["WBSTOCKIST_CLEAR_PROFILE_ITEMS"] = {
    text = S.profiles.clearPrompt,
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function()
        WarbandStorage.ProfileManager:ClearProfileItems(WarbandStorage:GetEditedProfileName())
        WarbandStorage.ProfileManager:RefreshUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
