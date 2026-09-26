WarbandStorage = WarbandStorage or {}

local S = WarbandStorage.Strings
local Sets = WarbandStorage.Sets
local Standard = WarbandStorage.StandardSets
local WC = LuckyUI.WC

local function Text()
    if not WarbandStockistDB.bankActiveSets then return nil end
    local charKey = WarbandStorage.Utils:GetCharacterKey()
    local title = WC.goldPrimary .. S.bankSets.title .. WC.reset
    if Sets:IsIgnored(charKey) then return title .. "\n" .. S.bankSets.ignored end

    local keep, withdrawAll, deposit = {}, {}, {}
    for _, set in ipairs(Sets:ActiveSetsFor(charKey)) do
        local kind = set.standard and Standard.kinds[set.standard]
        local group = set.type ~= "keep" and deposit or (kind and kind.reagent) and withdrawAll or keep
        table.insert(group, set.name)
    end
    if #keep + #withdrawAll + #deposit == 0 then return title .. "\n" .. S.bankSets.none end

    local lines = { title }
    local function AddLine(label, names)
        if #names == 0 then return end
        lines[#lines + 1] = WC.goldAccent .. label .. ":" .. WC.reset .. " " .. table.concat(names, ", ")
    end
    AddLine(S.sets.typeKeep, keep)
    AddLine(S.sets.typeWithdrawAll, withdrawAll)
    AddLine(S.sets.typeDeposit, deposit)
    return table.concat(lines, "\n")
end

-- Names the sets this character runs at the foot of the Bank Queue window.
-- Every Character sets, skips and ignored characters make that hard to read
-- off the settings pages.
LuckyBankRun:AddFooter(Text)
