-- Warband Stockist — Tab System & Lists
-- Contains the main UI tabs, item lists, and assignment lists

-- Ensure namespace
WarbandStorage = WarbandStorage or {}
WarbandStorage.UI = WarbandStorage.UI or {}

-- Storage for UI elements
WarbandStorage.assignRows = WarbandStorage.assignRows or {}
WarbandStorage.assignParent = WarbandStorage.assignParent or nil
WarbandStorage.scrollItems = WarbandStorage.scrollItems or {}
WarbandStorage.scrollParent = WarbandStorage.scrollParent or nil
WarbandStorage.activeProfileDrop = nil
WarbandStorage.itemFilter = WarbandStorage.itemFilter or ""

-- ############################################################
-- ## Item List Management
-- ############################################################
function RefreshItemList()
  local profile
  if WarbandStorage.GetEditedProfile then
    profile = WarbandStorage:GetEditedProfile()
  else
    profile = WarbandStorage:GetActiveProfile()
  end
  local stock = profile.items
  for _, row in ipairs(WarbandStorage.scrollItems or {}) do row:Hide() end
  WarbandStorage.scrollItems = {}

  local filter = WarbandStorage.itemFilter
  if filter == "" then filter = nil else filter = filter:lower() end

  local y = -4
  local index = 0
  for itemID, count in pairs(stock) do
    -- When a filter is active, match against the item name and its ID.
    local include = true
    if filter then
      local name = WarbandStorage.Utils:GetItemName(itemID)
      local haystack = ((name or "") .. " " .. tostring(itemID)):lower()
      include = haystack:find(filter, 1, true) ~= nil
    end

    if include then
      local row = createRow(WarbandStorage.scrollParent, index % 2 == 1, itemID, count)
      row:SetSize(200, 28)
      row:SetPoint("TOPLEFT", WarbandStorage.scrollParent, "TOPLEFT", 8, y)
      row:SetPoint("TOPRIGHT", WarbandStorage.scrollParent, "TOPRIGHT", 0, y)

      table.insert(WarbandStorage.scrollItems, row)
      y = y - 28
      index = index + 1
    end
  end

  WarbandStorage.scrollParent:SetHeight(-y + 10)
end


