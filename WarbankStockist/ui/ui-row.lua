
local FONTS = WarbandStorage.Theme.FONTS
local STRINGS = WarbandStorage.Theme.STRINGS

function createRow(parent, lightBg, itemID, count)
    
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(200, 28)

    if lightBg then
      local bg = row:CreateTexture(nil, "BACKGROUND")
      bg:SetAllPoints()
      bg:SetColorTexture(0.15, 0.15, 0.2, 0.4)
    end

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
     local itemIcon = select(5, GetItemInfoInstant(itemID))
    if itemIcon then 
      icon:SetTexture(itemIcon) 
    end
    icon:SetDesaturated(count == 0)
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function() 
      GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
      GameTooltip:SetItemByID(itemID)
      GameTooltip:Show() 
    end)
    icon:SetScript("OnLeave", GameTooltip_Hide)

    local removeBtn = CreateStyledButton(row, 70, 20,STRINGS.BUTTON_REMOVE)
    removeBtn:SetPoint("RIGHT", row, "RIGHT", -15, 0)
    removeBtn:SetScript("OnClick", function()
      WarbandStorage.ProfileManager:RemoveItemFromProfile(itemID)
    end)

    local qtyBox = CreateNumericEditText(row, nil, 50, 22)
    qtyBox:SetPoint("RIGHT", removeBtn, "LEFT", -15, 0)
    qtyBox:SetText(tostring(count))
    qtyBox:SetScript("OnEnterPressed", function(self)
      local val = tonumber(self:GetText())
      if val ~= nil then 
        WarbandStorage.ProfileManager:AddItemToProfile(itemID, val)
      end
      self:ClearFocus()
    end)
    qtyBox:SetScript("OnEscapePressed", function(self) 
      self:SetText(tostring(count))
      self:ClearFocus() 
    end)
    
    local label = row:CreateFontString(nil, "OVERLAY", FONTS.LABEL)
    label:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", qtyBox, "LEFT", 8, 0)
    label:SetJustifyH("LEFT")

    local itemName = WarbandStorage.Utils:GetItemName(itemID)
    local itemText = ("%s (ID: %d)"):format(itemName, itemID)
    if count == 0 then
      label:SetText("|cff666666" .. itemText .. "|r")
    else
      label:SetText("|cffcccccc" .. itemText .. "|r")
    end
    return row
end