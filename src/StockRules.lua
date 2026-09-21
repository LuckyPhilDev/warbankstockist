WarbandStorage = WarbandStorage or {}
WarbandStorage.StockRules = {}

local StockRules = WarbandStorage.StockRules

-- ranges[itemID] = { min = n, max = n or math.huge, warn = bool }: withdraw up
-- to min, deposit anything above max.
function StockRules.Merge(sets)
    local ranges = {}
    local function add(itemID, min, max, warn)
        local r = ranges[itemID]
        if not r then
            ranges[itemID] = { min = min, max = max, warn = warn }
            return
        end
        r.min = math.max(r.min, min)
        r.max = math.max(r.max, max)
        r.warn = r.warn or warn
    end
    for _, set in ipairs(sets) do
        for itemID, qty in pairs(set.items) do
            if set.type == "deposit" then
                add(itemID, 0, 0, false)
            else
                add(itemID, qty, set.returnExtras and qty or math.huge, set.lowStockWarning == true and qty > 0)
            end
        end
    end
    return ranges
end

function StockRules.Withdrawal(range, inBags, inBank, reserve, priority)
    local need = range.min - inBags
    if need <= 0 then return 0 end
    local available = inBank - (priority and 0 or (reserve or 0))
    return math.max(0, math.min(need, available))
end

function StockRules.Deposit(range, inBags)
    return math.max(0, inBags - range.max)
end
