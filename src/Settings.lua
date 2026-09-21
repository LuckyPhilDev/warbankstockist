WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font
local C = LuckyUI.C

local ADDON_FOLDER = "Luckys_Warbank_Stockist"

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

-- Pages register here to redraw after any change to sets, characters or
-- reserves, wherever it was made. The panel would otherwise only catch up the
-- next time it opened.
Settings.listeners = {}

function Settings.OnRefresh(redraw)
    table.insert(Settings.listeners, redraw)
end

function Settings.Refresh()
    for _, redraw in ipairs(Settings.listeners) do redraw() end
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

local function BuildBank(group)
    group:Section(S.bank.sorting)
    group:Toggle({
        label    = S.bank.sortAfter,
        desc     = S.bank.sortAfterDesc,
        since    = "2.0.0",
        checked  = function() return WarbandStockistDB.sortAfterDeposit == true end,
        onToggle = function(checked) WarbandStockistDB.sortAfterDeposit = checked end,
    })

    group:Section(S.bankQueue.section)
    LuckyBankRun:AddModeSetting(group, { since = "1.13.0" })
    LuckyBankRun:AddSettingsToggle(group, "1.13.0")
end

function Settings.Create()
    if WarbandStorage.SettingsPanel then return WarbandStorage.SettingsPanel end

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
        p:Group(S.sets.section, { showAbout = false }, Settings.BuildSets)
        p:Group(S.reserves.section, { showAbout = false }, Settings.BuildReserves)
        p:Group(S.characters.section, { showAbout = false }, Settings.BuildCharacters)
        p:Group(S.gold.section, { showAbout = false }, Settings.BuildGold)
        p:Group(S.bank.section, BuildBank)
    end)

    panel:OnOpen(function()
        WarbandStorage.Perf:Reset()
        local perfStart = WarbandStorage.Perf:Now()

        Settings.Refresh()
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
