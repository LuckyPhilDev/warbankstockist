WarbandStorage = WarbandStorage or {}

local S = WarbandStorage.Strings

local MUTED = LuckyUI.C.textMuted
local PRICE_TIMEOUT = 5

-- Bind on pickup, quest and warbound items can never be listed.
local LISTABLE = {
    [Enum.ItemBind.None]    = true,
    [Enum.ItemBind.OnEquip] = true,
    [Enum.ItemBind.OnUse]   = true,
}

local button
local auctionHouseOpen = false
local settled = {}  -- bought, unpriced or unaffordable this visit; bag counts lag a purchase
local awaiting      -- asked for a price, no answer yet
local quote         -- priced, waiting on a click to confirm
local buying        -- confirmed, waiting on the result

local function Say(message)
    print(S.addon.prefix .. " " .. message)
end

local function Describe(item)
    local name = C_Item.GetItemNameByID(item.itemID) or S.commands.itemIdFallback:format(item.itemID)
    return ("%dx %s"):format(item.quantity, name)
end

local function Shortfalls(log)
    local list = {}
    for itemID, range in pairs(WarbandStorage.Sets:RangesFor(WarbandStorage.Utils:GetCharacterKey())) do
        if range.min > 0 and not settled[itemID] then
            local bindType = select(14, C_Item.GetItemInfo(itemID))
            local inBags, fromBank, quantity = WarbandStorage:Supply(itemID, range)
            if log then
                WarbandStorage:DebugPrint(("Restock %d: keep %d, bags %d, from bank %d, bind %s, buy %d"):format(
                    itemID, range.min, inBags, fromBank, tostring(bindType), quantity))
            end
            if quantity > 0 and LISTABLE[bindType] then list[#list + 1] = { itemID = itemID, quantity = quantity } end
        end
    end
    table.sort(list, function(a, b) return a.itemID < b.itemID end)
    return list
end

local function BuildTooltip(tip)
    tip:SetText(S.restock.tooltip)
    for _, item in ipairs(Shortfalls()) do
        tip:AddLine(Describe(item), 1, 1, 1)
    end
    tip:AddLine(" ")
    local hint = quote and S.restock.tooltipConfirm:format(Describe(quote), GetMoneyString(quote.totalPrice, true))
        or S.restock.tooltipPrice
    tip:AddLine(hint, MUTED[1], MUTED[2], MUTED[3], true)
end

-- Blizzard prices a commodity in two steps: ask for a quote, then confirm the
-- total it answers with. One click each, so the price is on screen before any
-- gold moves.
local function Confirm()
    local item = quote
    quote = nil
    if item.totalPrice > GetMoney() then
        Say(S.restock.notEnoughGold:format(Describe(item)))
        settled[item.itemID] = true
        C_AuctionHouse.CancelCommoditiesPurchase()
        return
    end
    buying = item
    C_AuctionHouse.ConfirmCommoditiesPurchase(item.itemID, item.quantity)
end

local function Skip(item)
    Say(S.restock.noPrice:format(Describe(item)))
    settled[item.itemID] = true
end

local Refresh

local function OnClick()
    if quote then return Confirm() end
    if awaiting or buying then return end
    local item = Shortfalls()[1]
    if not item then return end
    awaiting = item
    C_AuctionHouse.StartCommoditiesPurchase(item.itemID, item.quantity)
    -- A request Blizzard refuses outright never answers, which would hold the button forever.
    C_Timer.After(PRICE_TIMEOUT, function()
        if awaiting ~= item then return end
        awaiting = nil
        Skip(item)
        Refresh()
    end)
end

local function Button()
    if button then return button end
    -- Shared with the other Lucky addons, so every Auction House button stacks in one column.
    button = LuckyUI.SideColumn("AuctionHouse", AuctionHouseFrame):AddButton({
        order   = 40,
        texture = "Interface\\Icons\\INV_Misc_Bag_10",
        tooltip = BuildTooltip,
    })
    button:SetScript("OnClick", OnClick)
    return button
end

function Refresh()
    if auctionHouseOpen and (quote or #Shortfalls() > 0) then
        Button():Show()
        if GameTooltip:IsOwned(button) then button:GetScript("OnEnter")(button) end
    elseif button then
        button:Hide()
    end
end

-- The price and purchase events also fire for the player's own shopping, so
-- each branch first checks the purchase is one this button started.
local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("COMMODITY_PRICE_UPDATED")
events:RegisterEvent("COMMODITY_PRICE_UNAVAILABLE")
events:RegisterEvent("COMMODITY_PURCHASE_SUCCEEDED")
events:RegisterEvent("COMMODITY_PURCHASE_FAILED")
events:SetScript("OnEvent", function(_, event, _, totalPrice)
    if event == "AUCTION_HOUSE_SHOW" then
        auctionHouseOpen = true
        settled = {}
        -- The bind type is only readable once the client has loaded the item.
        local ids = {}
        for itemID in pairs(WarbandStorage.Sets:RangesFor(WarbandStorage.Utils:GetCharacterKey())) do
            ids[#ids + 1] = itemID
        end
        LuckyItem:GetMany(ids, function()
            Shortfalls(true)
            Refresh()
        end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        auctionHouseOpen = false
        awaiting, quote, buying = nil, nil, nil
    elseif event == "BAG_UPDATE_DELAYED" then
        if not auctionHouseOpen then return end
    elseif event == "COMMODITY_PRICE_UPDATED" then
        if not awaiting then return end
        quote, awaiting = awaiting, nil
        quote.totalPrice = totalPrice
        Say(S.restock.priced:format(Describe(quote), GetMoneyString(totalPrice, true)))
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        if not awaiting then return end
        Skip(awaiting)
        awaiting = nil
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if not buying then return end
        settled[buying.itemID] = true
        buying = nil
        if #Shortfalls() == 0 then Say(S.restock.done) end
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        if not buying then return end
        buying = nil
    end
    Refresh()
end)
