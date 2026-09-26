WarbandStorage = nil

dofile("src/StockRules.lua")

local StockRules = WarbandStorage.StockRules
local HUGE = math.huge
local ITEM = 212283

local passed = 0

local function check(label, actual, expected)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
    passed = passed + 1
end

local function keepSet(qty, returnExtras, lowStockWarning)
    return { type = "keep", returnExtras = returnExtras, lowStockWarning = lowStockWarning, items = { [ITEM] = qty } }
end

local function depositSet()
    return { type = "deposit", returnExtras = true, items = { [ITEM] = 0 } }
end

local function range(sets)
    return StockRules.Merge(sets)[ITEM]
end

-- Overlapping Keep amounts: largest Keep wins.
local r = range({ keepSet(5, true), keepSet(10, true) })
check("largest keep min", r.min, 10)
check("largest keep max", r.max, 10)
check("largest keep withdraws to 10", StockRules.Withdrawal(r, 0, 100), 10)

-- Keep vs Deposit All on the same item: Keep wins.
r = range({ keepSet(3, true), depositSet() })
check("keep over deposit min", r.min, 3)
check("keep over deposit max", r.max, 3)
check("keep over deposit leaves 3", StockRules.Deposit(r, 8), 5)
r = range({ depositSet(), keepSet(3, false) })
check("keep without extras over deposit max", r.max, HUGE)
check("keep without extras over deposit deposits nothing", StockRules.Deposit(r, 8), 0)

-- Return Extras across sets: only when every Keep set listing the item has it on.
r = range({ keepSet(5, true), keepSet(10, false) })
check("one set keeps extras", r.max, HUGE)
check("one set keeps extras deposits nothing", StockRules.Deposit(r, 30), 0)
r = range({ keepSet(5, true), keepSet(10, true) })
check("every set returns extras", StockRules.Deposit(r, 30), 20)

-- Keep 0 inside a Keep set.
r = range({ keepSet(0, true) })
check("keep 0 with extras withdraws nothing", StockRules.Withdrawal(r, 0, 50), 0)
check("keep 0 with extras deposits every copy", StockRules.Deposit(r, 7), 7)
r = range({ keepSet(0, false) })
check("keep 0 without extras deposits nothing", StockRules.Deposit(r, 7), 0)

-- Deposit All alone.
r = range({ depositSet() })
check("deposit all withdraws nothing", StockRules.Withdrawal(r, 0, 50), 0)
check("deposit all deposits every copy", StockRules.Deposit(r, 12), 12)

-- Reserves: Keep 20, bank holds 60, reserve 50.
r = range({ keepSet(20, true) })
check("normal character takes only the surplus", StockRules.Withdrawal(r, 0, 60, 50, false), 10)
check("priority character takes it all", StockRules.Withdrawal(r, 0, 60, 50, true), 20)
check("no reserve takes it all", StockRules.Withdrawal(r, 0, 60), 20)
check("bags already stocked", StockRules.Withdrawal(r, 20, 60, 50, true), 0)
check("partly stocked tops up", StockRules.Withdrawal(r, 15, 60), 5)
check("bank short of the keep", StockRules.Withdrawal(r, 0, 12), 12)

-- Bank holding less than the reserve.
check("bank under reserve, normal", StockRules.Withdrawal(r, 0, 30, 50, false), 0)
check("bank under reserve, priority", StockRules.Withdrawal(r, 0, 30, 50, true), 20)

-- Low Stock Warning only for Keep amounts above 0 from sets that opt in.
check("warning set warns", range({ keepSet(3, true, true) }).warn, true)
check("quiet set does not warn", range({ keepSet(3, true, false) }).warn, false)
check("keep 0 does not warn", range({ keepSet(0, true, true) }).warn, false)
check("any warning set warns", range({ keepSet(3, true, false), keepSet(1, true, true) }).warn, true)
check("a later quiet set keeps the warning", range({ keepSet(1, true, true), keepSet(3, true, false) }).warn, true)
check("deposit all does not warn", range({ depositSet() }).warn, false)

-- Buying covers only what the bank cannot.
r = range({ keepSet(20, true) })
check("buy the whole shortfall", StockRules.Purchase(r, 5, 0), 15)
check("bank covers it", StockRules.Purchase(r, 5, 60), 0)
check("bank covers part", StockRules.Purchase(r, 5, 10), 5)
check("reserve held back from the bank", StockRules.Purchase(r, 0, 30, 25, false), 15)
check("priority ignores the reserve", StockRules.Purchase(r, 0, 30, 25, true), 0)
check("already stocked buys nothing", StockRules.Purchase(r, 25, 0), 0)

-- Withdraw All takes whatever the bank can spare beyond its Reserve, and never buys.
r = range({ keepSet(HUGE, true) })
check("withdraw all takes the bank less its reserve", StockRules.Withdrawal(r, 40, 100, 30, false), 70)
check("withdraw all never deposits", StockRules.Deposit(r, 500), 0)
check("withdraw all never buys", StockRules.Purchase(r, 0, 0), 0)

check("unlisted item has no range", StockRules.Merge({ keepSet(3, true) })[1], nil)

print(string.format("%d StockRules tests passed", passed))
