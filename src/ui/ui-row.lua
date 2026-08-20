
local FONTS = WarbandStorage.Theme.FONTS
local S = WarbandStorage.Strings

-- Tracked item rows are pooled. A refresh reuses the frames it built last time
-- instead of orphaning a hidden set and building another, so repeated refreshes
-- (filter keystrokes, item loads, add/remove) stay flat rather than growing.
-- Handlers read row.itemID at click time because a row's item changes on reuse.
local rowPool = {}
local rowsInUse = 0

local function BuildRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(200, 28)

    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints()
    row.stripe:SetColorTexture(0.15, 0.15, 0.2, 0.4)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:EnableMouse(true)
    row.icon:SetScript("OnEnter", function()
      if GameTooltip_SetDefaultAnchor and GameTooltip then
        GameTooltip_SetDefaultAnchor(GameTooltip, row)
        if row.itemID and GameTooltip.SetItemByID then GameTooltip:SetItemByID(row.itemID) end
      end
    end)
    row.icon:SetScript("OnLeave", GameTooltip_Hide)

    row.removeBtn = CreateStyledButton(row, 70, 20, S.tracked.remove)
    row.removeBtn:SetPoint("RIGHT", row, "RIGHT", -15, 0)
    row.removeBtn:SetScript("OnClick", function()
      WarbandStorage.ProfileManager:RemoveItemFromProfile(row.itemID)
    end)

    row.qtyBox = CreateNumericEditText(row, nil, 50, 22)
    row.qtyBox:SetPoint("RIGHT", row.removeBtn, "LEFT", -15, 0)
    row.qtyBox:SetScript("OnEnterPressed", function(self)
      local val = tonumber(self:GetText())
      if val ~= nil then
        WarbandStorage.ProfileManager:AddItemToProfile(row.itemID, val)
      end
      self:ClearFocus()
    end)
    row.qtyBox:SetScript("OnEscapePressed", function(self)
      self:SetText(tostring(row.count or 0))
      self:ClearFocus()
    end)

    row.label = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.label:SetPoint("RIGHT", row.qtyBox, "LEFT", 8, 0)
    row.label:SetJustifyH("LEFT")

    return row
end

local function UpdateRow(row, lightBg, itemID, count)
    row.itemID = itemID
    row.count = count

    row.stripe:SetShown(lightBg and true or false)

    local itemIcon
    if C_Item and C_Item.GetItemIconByID then
      itemIcon = C_Item.GetItemIconByID(itemID)
    end
    row.icon:SetTexture(itemIcon)
    row.icon:SetDesaturated((count or 0) == 0)

    row.qtyBox:SetText(tostring(count or 0))

    local itemName = WarbandStorage.Utils:GetItemName(itemID)
    local safeID = (itemID ~= nil) and tostring(itemID) or "?"
    local safeName = itemName or ("Item " .. safeID)
    local itemText = safeName .. " (ID: " .. safeID .. ")"
    local shade = ((count or 0) == 0) and "|cff666666" or "|cffcccccc"
    row.label:SetText(shade .. itemText .. "|r")
end

-- Hide every pooled row and hand the pool back to the start.
function ReleaseItemRows()
    for _, row in ipairs(rowPool) do row:Hide() end
    rowsInUse = 0
end

function AcquireItemRow(parent, lightBg, itemID, count)
    local perfStart = WarbandStorage.Perf:Now()

    rowsInUse = rowsInUse + 1
    local row = rowPool[rowsInUse]
    if not row then
      row = BuildRow(parent)
      rowPool[rowsInUse] = row
      WarbandStorage.Perf:Count("itemRow:built")
    end

    UpdateRow(row, lightBg, itemID, count)
    row:Show()

    WarbandStorage.Perf:Add("itemRow:acquire", perfStart)
    return row
end
