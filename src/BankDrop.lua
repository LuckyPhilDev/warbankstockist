WarbandStorage = WarbandStorage or {}

local Sets = WarbandStorage.Sets
local S = WarbandStorage.Strings
local C = LuckyUI.C

-- Matches the Bank Queue window, which this hangs under.
local WIDTH = 300
local BANK_TAB_STRIP = 50
local SLOT = 40
local PAD = 12
local EXPAND_SECONDS = 0.15

local bankOpen = false
local drawer

local function Master()
    return Sets.EnsureMaster(WarbandStockistDB)
end

-- The item the player holds, when the Warband Bank would take it.
local function HeldItem()
    local kind, itemID, link = GetCursorInfo()
    if kind ~= "item" then return nil end
    local location = C_Cursor.GetCursorItem()
    if not (location and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, location)) then return nil end
    return itemID, link
end

local function Drop()
    local itemID, link = HeldItem()
    if not itemID then return end
    ClearCursor()
    local master = Master()
    Sets:SetItem(master.id, itemID, 0)
    print(S.addon.prefix .. " " .. S.bankDrop.added:format(link, master.name))
    LuckyBankRun:Queue({
        direction = "deposit",
        plan = function() return WarbandStorage:PlanDepositAll(itemID) end,
        run  = function(job, queue) WarbandStorage:ProcessDepositQueue(queue, 1, job) end,
    })
end

local function SetHovered(f, hovered)
    local border = hovered and C.goldPrimary or C.goldMuted
    f.slot:SetBackdropBorderColor(border[1], border[2], border[3])
    f.slotFill:SetShown(hovered)
    f.itemIcon:SetShown(hovered)
    f.arrow:SetShown(not hovered)
end

-- Grows or shrinks toward its target height. The content is pinned to the top
-- and clipped, so the drawer reveals it as it slides down.
local function Animate(f, elapsed)
    local step = f.fullHeight * elapsed / EXPAND_SECONDS
    local height = f:GetHeight() + (f.opening and step or -step)
    if f.opening and height >= f.fullHeight then
        f:SetHeight(f.fullHeight)
        f:SetScript("OnUpdate", nil)
    elseif not f.opening and height <= 1 then
        f:SetScript("OnUpdate", nil)
        f:Hide()
    else
        f:SetHeight(height)
    end
end

local function Drawer()
    if drawer then return drawer end
    local f = LuckyUI.CreatePanel(nil, UIParent, WIDTH, 1)
    f:SetFrameStrata("MEDIUM")
    f:SetScript("OnDragStart", nil)
    f:SetClipsChildren(true)
    f:Hide()

    local slot = CreateFrame("Frame", nil, f, "BackdropTemplate")
    slot:SetSize(SLOT, SLOT)
    slot:SetPoint("TOPLEFT", PAD, -PAD)
    slot:SetBackdrop(LuckyUI.Backdrop)
    slot:SetBackdropColor(C.bgInput[1], C.bgInput[2], C.bgInput[3], C.bgInput[4])
    f.slot = slot

    f.slotFill = slot:CreateTexture(nil, "ARTWORK")
    f.slotFill:SetPoint("TOPLEFT", 1, -1)
    f.slotFill:SetPoint("BOTTOMRIGHT", -1, 1)
    f.slotFill:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], C.highlight[4])

    f.itemIcon = slot:CreateTexture(nil, "OVERLAY")
    f.itemIcon:SetPoint("TOPLEFT", 3, -3)
    f.itemIcon:SetPoint("BOTTOMRIGHT", -3, 3)
    f.itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    f.arrow = slot:CreateTexture(nil, "OVERLAY")
    f.arrow:SetSize(20, 20)
    f.arrow:SetPoint("CENTER")
    f.arrow:SetTexture(LuckyIcon("arrow-down-to-line"))
    f.arrow:SetVertexColor(C.goldIcon[1], C.goldIcon[2], C.goldIcon[3])
    local pulse = f.arrow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.35)
    fade:SetDuration(0.7)
    pulse:Play()

    local textWidth = WIDTH - PAD * 3 - SLOT
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(LuckyUI.TITLE_FONT, 13, "")
    f.title:SetTextColor(C.goldPrimary[1], C.goldPrimary[2], C.goldPrimary[3])
    f.title:SetPoint("TOPLEFT", slot, "TOPRIGHT", PAD, 0)
    f.title:SetWidth(textWidth)
    f.title:SetJustifyH("LEFT")
    f.title:SetText(S.bankDrop.title)

    f.hint = f:CreateFontString(nil, "OVERLAY")
    f.hint:SetFont(LuckyUI.BODY_FONT, 11, "")
    f.hint:SetTextColor(C.textLight[1], C.textLight[2], C.textLight[3])
    f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
    f.hint:SetWidth(textWidth)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetSpacing(2)

    -- The whole drawer takes the drop, not just the slot drawn in it.
    f:SetScript("OnReceiveDrag", Drop)
    f:SetScript("OnMouseUp", Drop)
    f:SetScript("OnEnter", function(self) SetHovered(self, true) end)
    f:SetScript("OnLeave", function(self) SetHovered(self, false) end)

    drawer = f
    return f
end

-- Hangs off the foot of the Bank Queue window, or takes its place beside the
-- bank when that window is not up.
-- ponytail: the fallback only knows Blizzard's bank window; use LuckyBankRun's
-- bank lookup if the library ever exposes it, for Baganator's.
local function Anchor(f)
    local queue = LuckyBankRun.frame
    if queue and not f.hookedQueue then
        f.hookedQueue = true
        queue:HookScript("OnShow", function() if f:IsShown() then Anchor(f) end end)
        queue:HookScript("OnHide", function() if f:IsShown() then Anchor(f) end end)
    end
    f:ClearAllPoints()
    if queue and queue:IsShown() then
        f:SetPoint("TOPLEFT", queue, "BOTTOMLEFT", 0, 1)
        f:SetPoint("TOPRIGHT", queue, "BOTTOMRIGHT", 0, 1)
    else
        f:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT", BANK_TAB_STRIP, 0)
    end
end

local function Open(link)
    local f = Drawer()
    f.hint:SetText(S.bankDrop.hint:format(link))
    f.itemIcon:SetTexture(C_Item.GetItemIconByID(link) or 134400)
    f.fullHeight = PAD * 2 + math.max(SLOT, f.title:GetStringHeight() + 4 + f.hint:GetStringHeight())
    SetHovered(f, f:IsMouseOver())
    f:EnableMouse(true)
    if not f:IsShown() then
        f:SetHeight(1)
        Anchor(f)
        f:Show()
    end
    f.opening = true
    f:SetScript("OnUpdate", Animate)
end

local function Close()
    if not (drawer and drawer:IsShown()) then return end
    drawer:EnableMouse(false)
    drawer.opening = false
    drawer:SetScript("OnUpdate", Animate)
end

-- Open only while the player holds an item themselves: a bank run moves
-- stacks on the cursor too, and those are not being dropped anywhere.
local function Refresh()
    local itemID, link = HeldItem()
    if bankOpen and itemID and not LuckyBankRun.current and C_Bank.CanViewBank(Enum.BankType.Account) then
        Open(link)
    else
        Close()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("BANKFRAME_CLOSED")
events:RegisterEvent("CURSOR_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then
        bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        if drawer then drawer:Hide() end
    end
    Refresh()
end)
