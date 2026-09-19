WarbandStorage = WarbandStorage or {}
WarbandStorage.Settings = WarbandStorage.Settings or {}

local Settings = WarbandStorage.Settings
local Sets = WarbandStorage.Sets
local S = WarbandStorage.Strings
local R = LuckySettings.Rich.Theme
local R_FONT = LuckySettings.Rich.Font

local function AddHint(group, text)
    local frame = group:Frame(40)
    local hint = frame:CreateFontString(nil, "OVERLAY")
    hint:SetFont(R_FONT, 11, "")
    hint:SetPoint("TOPLEFT", 14, -8)
    hint:SetPoint("RIGHT", -14, 0)
    hint:SetJustifyH("LEFT")
    hint:SetSpacing(3)
    hint:SetTextColor(R.textDim[1], R.textDim[2], R.textDim[3])
    hint:SetText(text)
    -- The hint wraps, so its height is only known once the page has a width.
    -- Resizing from inside the frame's own size callback leaves the rows
    -- anchored below it with no position, so the item list never drew.
    frame:SetScript("OnSizeChanged", function()
        RunNextFrame(function() frame:SetHeight(hint:GetStringHeight() + 16) end)
    end)
end

function Settings.BuildReserves(group)
    AddHint(group, S.reserves.hint)
    local list = Settings.CreateItemList(group, {
        entries    = function() return Sets:AllReserves() end,
        setQty     = function(itemID, qty) Sets:SetReserve(itemID, qty) end,
        remove     = function(itemID) Sets:RemoveReserve(itemID) end,
        qtyLabel   = S.reserves.leave,
        qtyTooltip = S.reserves.leaveTooltip,
        emptyText  = S.reserves.empty,
    })
    Settings.OnRefresh(function() list:Refresh() end)
end
