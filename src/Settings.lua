-- Warband Stockist: settings panel.
-- Builds the rich settings panel and owns the state shared between its pages.
-- Each page's rows live in settings/*.lua and are attached to
-- WarbandStorage.Settings by those files.

WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font
local C = LuckyUI.C

local ADDON_FOLDER = "Luckys_Warbank_Stockist"

-- ############################################################
-- ## Shared inputs
-- ############################################################

--- A numeric entry box styled to match the panel. Blizzard's InputBoxTemplate
--- carries its own gold border art, which reads as a different addon inside
--- this panel.
function Settings.NumberBox(parent, width, tooltip)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width, 24)
    box:SetBackdrop(LuckyUI.Backdrop)
    box:SetBackdropColor(C.bgInput[1], C.bgInput[2], C.bgInput[3], C.bgInput[4])
    box:SetBackdropBorderColor(C.borderDark[1], C.borderDark[2], C.borderDark[3])
    box:SetFont(R_FONT, 12, "")
    box:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    box:SetTextInsets(6, 6, 0, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(9)
    box:SetScript("OnEscapePressed", box.ClearFocus)

    if tooltip then
        box:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        box:SetScript("OnLeave", GameTooltip_Hide)
    end
    return box
end

--- Hover text for controls the rich rows do not cover, whose About-rail
--- description a player never sees.
function Settings.Tooltip(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

function Settings.FieldLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(R_FONT, 12, "")
    label:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    label:SetText(text)
    return label
end

-- Pages that show the edited profile register a callback here. Changing the
-- profile from any page then keeps every other page in step, which the panel
-- would otherwise only do the next time it opened.
Settings.profileListeners = {}

function Settings.EditedProfileName()
    return WarbandStorage:GetEditedProfileName()
end

function Settings.SetEditedProfile(name)
    WarbandStorage:SetEditedProfileName(name)
end

-- The hook the profile and item modules already call after any change that
-- moves a profile in or out of the list, or switches which one is edited.
function WarbandStorage.RefreshProfileDropdown()
    for _, refresh in ipairs(Settings.profileListeners) do
        refresh()
    end
end

-- Fill `options` in place from the current profile list. Select reads the same
-- table every time its menu opens, so refilling it is what makes a profile
-- created or deleted mid-session show up.
function Settings.RefreshProfileOptions(options)
    table.wipe(options)
    for _, name in ipairs(WarbandStorage:GetAllProfileNames()) do
        table.insert(options, { key = name, label = name })
    end
    return options
end

-- A profile picker, plus the plumbing that keeps it and the page it sits on in
-- step with the other pages. `onChanged` runs after the profile changes,
-- however it changed.
function Settings.AddProfileSelect(group, onChanged)
    local options = Settings.RefreshProfileOptions({})

    group:Select({
        label    = S.profiles.label,
        desc     = S.profiles.labelDesc,
        options  = options,
        value    = Settings.EditedProfileName,
        onSelect = Settings.SetEditedProfile,
    })

    local picker = group.byLabel[S.profiles.label]
    table.insert(Settings.profileListeners, function()
        Settings.RefreshProfileOptions(options)
        picker.refreshSelect()
        if onChanged then onChanged() end
    end)
end

-- The version rows and the suite links sit on the first group, which is where
-- the library appends the What's New list.
local function AddWhatsNew(panel)
    local group = panel:Group(S.whatsNew.section)

    group:BottomSection(S.whatsNew.versionInfo)
    group:BottomLabel({
        label = S.addon.title,
        value = "v" .. (C_AddOns.GetAddOnMetadata(ADDON_FOLDER, "Version") or "?"),
    })
    group:BottomLabel({
        label = S.whatsNew.utilsLabel,
        value = "v" .. (C_AddOns.GetAddOnMetadata("Luckys_Utils", "Version")
            or ("1.0 r" .. LibStub.minors["LuckysUtils-1.0"])),
    })

    LuckyPromo:AddToRichGroup(group, ADDON_FOLDER)
end

local function BuildWarbound(group)
    local function config()
        WarbandStockistDB.warboundDeposit = WarbandStockistDB.warboundDeposit or {}
        return WarbandStockistDB.warboundDeposit
    end

    local function toggle(key, label, desc, parent, note, since)
        group:Toggle({
            label    = label,
            desc     = desc,
            note     = note,
            parent   = parent,
            since    = since,
            checked  = function() return config()[key] == true end,
            onToggle = function(checked) config()[key] = checked end,
        })
    end

    toggle("enabled", S.warbound.master, S.warbound.masterTooltip, nil, S.warbound.hint, "1.10.0")
    toggle("armor", S.warbound.armor, S.warbound.armorTooltip, S.warbound.master)
    toggle("weapons", S.warbound.weapons, S.warbound.weaponsTooltip, S.warbound.master)
    toggle("tokens", S.warbound.tokens, S.warbound.tokensTooltip, S.warbound.master)
end

function Settings.Create()
    if WarbandStorage.SettingsPanel then return WarbandStorage.SettingsPanel end

    WarbandStorage:MigrateLegacyIfNeeded()
    WarbandStorage.ProfileManager:EnsureProfile(WarbandStockistDB.defaultProfile)

    local panel = LuckySettings:NewRichPanel(S.addon.title, {
        addonFolder = ADDON_FOLDER,
        minVersion  = WarbandStorage.WHATS_NEW_MIN_VERSION,
        devMode = {
            checked  = function() return WarbandStockistDB.debugEnabled == true end,
            onToggle = function(checked) WarbandStockistDB.debugEnabled = checked end,
        },
        minimapButton = {
            checked  = function() return not (WarbandStockistDB.minimap and WarbandStockistDB.minimap.hide) end,
            onToggle = function(checked)
                -- The button is built on a retry when the minimap is not ready
                -- at login, so the flag has to be persisted either way.
                WarbandStockistDB.minimap = WarbandStockistDB.minimap or {}
                WarbandStockistDB.minimap.hide = not checked
                if WarbandStorage.Minimap.button then
                    WarbandStorage.Minimap.button:SetShown_Persisted(checked)
                end
            end,
        },
    }, function(p)
        AddWhatsNew(p)
        p:Group(S.profiles.section, { showAbout = false }, Settings.BuildProfiles)
        p:Group(S.assignments.section, { showAbout = false }, Settings.BuildAssignments)
        p:Group(S.gold.section, { showAbout = false }, Settings.BuildGold)
        p:Group(S.warbound.section, BuildWarbound)
    end)

    panel:OnOpen(function()
        WarbandStorage.Perf:Reset()
        local perfStart = WarbandStorage.Perf:Now()

        WarbandStorage.RefreshProfileDropdown()
        if RefreshItemList then RefreshItemList() end
        if RefreshAssignmentsList then RefreshAssignmentsList() end
        if WarbandStorage.RefreshGoldLists then WarbandStorage.RefreshGoldLists() end

        WarbandStorage.Perf:Add("Settings:OnOpen", perfStart)
        -- Async item loads keep refreshing the list after this returns, so the
        -- report waits for that settle before dumping.
        if WarbandStockistDB.debugEnabled then
            C_Timer.After(3, function() WarbandStorage.Perf:Dump("settings load (+3s)") end)
        end
    end)

    WarbandStorage.SettingsPanel = panel
    return panel
end
