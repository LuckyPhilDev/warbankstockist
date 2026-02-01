# GitHub Copilot Instructions for Warband Stockist

## Project Overview
Warband Stockist is a World of Warcraft addon that automatically manages item quantities between your bags and the Warband Bank. It allows players to create profiles with rules for which items to keep in their bags and which to deposit, with support for multiple characters sharing warband storage.

## Code Style & Conventions

### Lua Standards
- **Lua Version**: Lua 5.1 (WoW's embedded version)
- **Line Length**: 120 characters maximum
- **Indentation**: 2 spaces (no tabs)
- **Comments**: Use `--` for single-line, document complex logic
- **String Quotes**: Prefer double quotes `"` for user-facing strings, single quotes `'` for internal keys

### Naming Conventions
```lua
-- Global addon namespace (PascalCase)
WarbandStockist = {}

-- Module functions (PascalCase)
function WarbandStockist.GetProfile() end
function WarbandStockist.UpdateInventory() end

-- Local/private functions (camelCase)
local function scanBags() end
local function depositItem() end

-- Constants (UPPER_SNAKE_CASE)
local MAX_RETRIES = 3
local DEFAULT_QUANTITY = 1

-- Variables (camelCase)
local activeProfile = {}
local itemCache = {}
```

### File Organization
```
WarbankStockist/
├── core.lua                -- Core addon initialization and main logic
├── utils.lua               -- Utility functions
├── common-utils.lua        -- Shared utility functions
├── config.lua              -- Configuration and settings
├── profile-manager.lua     -- Profile management system
├── profiles.lua            -- Profile data handling
├── character-data.lua      -- Character-specific data
├── inventory.lua           -- Bag inventory scanning
├── bank.lua                -- Warbank interaction
├── deposit-commands.lua    -- Slash commands for deposits/withdrawals
├── frame-factory.lua       -- UI frame creation helpers
└── ui/                     -- UI components
    ├── ui-theme.lua        -- Theme and styling
    ├── ui-row.lua          -- Row widgets
    ├── ui-components.lua   -- Reusable UI components
    ├── ui-tabs.lua         -- Tab system
    ├── profile-panel.lua   -- Profile management panel
    ├── assignment-panel.lua -- Item assignment panel
    └── settings-panel.lua  -- Settings panel
```

## WoW API Patterns

### Safe API Calls
Always use pcall for potentially failing WoW APIs:
```lua
local ok, result = pcall(C_Item.GetItemInfo, itemID)
if ok and result then
  -- use result
end
```

### Event Handling
```lua
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    -- handle login
  elseif event == "BANKFRAME_OPENED" then
    -- handle bank open
  end
end)
```

### Warband Bank API
```lua
-- Check if warband bank is available
if C_Bank and C_Bank.CanUseBank and C_Bank.CanUseBank() then
  -- Interact with warband bank
end

-- Deposit/withdraw operations
C_Bank.AutoDepositItemToBank(bagID, slotID)
C_Bank.FetchDepositedMoney(amount)
```

## Addon-Specific Patterns

### Profile System
Profiles define rules for which items to manage:
```lua
-- Profile structure
local profile = {
  name = "Main Tank",
  assignments = {
    [itemID] = {
      quantity = 20,      -- Keep this many in bags
      enabled = true,     -- Rule is active
    }
  }
}
```

### Debug Logging
Use the debug system for verbose logging:
```lua
local function dprint(...)
  if WarbandStockist.debug then
    print("[WarbandStockist]", ...)
  end
end
```

### SavedVariables
```lua
-- Account-wide data
WarbandStockistDB = {
  profiles = {},
  settings = {
    autoDeposit = true,
    debugMode = false,
  }
}

-- Cross-character warband data
WarbandStorageData = {
  -- Shared storage information
}

-- Per-character data
WarbandStorageCharData = {
  activeProfile = "Default",
  lastSync = 0,
}
```

## Testing & Debugging

### Testing Commands
```lua
/wbdeposit <itemID>     -- Deposit 1 of item
/warbanddeposit <itemID>
/wbwithdraw <itemID>    -- Withdraw 1 of item
/warbandwithdraw <itemID>
/wbhelp                 -- Show help
```

### Adding New Test Commands
```lua
-- In deposit-commands.lua
SLASH_MYTEST1 = "/wbtest"
SlashCmdList["MYTEST"] = function(msg)
  print("Testing:", msg)
end
```

## Common Pitfalls to Avoid

### ❌ Don't: Access bank without checking
```lua
-- Bad: Direct bank access
C_Bank.AutoDepositItemToBank(bag, slot)
```

### ✅ Do: Check bank availability
```lua
-- Good: Verify bank is accessible
if C_Bank and C_Bank.CanUseBank and C_Bank.CanUseBank() then
  C_Bank.AutoDepositItemToBank(bag, slot)
else
  print("Warband bank is not available")
end
```

### ❌ Don't: Modify items during iteration
```lua
-- Bad: Changing table while iterating
for itemID, data in pairs(profile.assignments) do
  if condition then
    profile.assignments[itemID] = nil  -- Don't do this!
  end
end
```

### ✅ Do: Collect items to modify, then modify
```lua
-- Good: Two-pass approach
local toRemove = {}
for itemID, data in pairs(profile.assignments) do
  if condition then
    table.insert(toRemove, itemID)
  end
end
for _, itemID in ipairs(toRemove) do
  profile.assignments[itemID] = nil
end
```

### ❌ Don't: Use global variables without declaration
```lua
-- Bad: Implicit global
myVariable = 123
```

### ✅ Do: Use local or explicit namespace
```lua
-- Good: Explicit scope
local myVariable = 123
-- Or if part of addon:
WarbandStockist.myVariable = 123
```

## Architecture Principles

### Module Separation
- **Core**: Initialization, event handling, main addon logic
- **Profile Manager**: Profile creation, editing, switching
- **Inventory**: Bag scanning and item tracking
- **Bank**: Warband bank operations
- **UI**: User interface panels and components
- **Commands**: Slash command handlers

### Event Flow
```
PLAYER_LOGIN
  → Initialize SavedVariables
  → Load active profile
  → Register other events

BANKFRAME_OPENED
  → Scan current inventory
  → Compare with profile rules
  → Execute auto-deposit if enabled

BAG_UPDATE
  → Update inventory cache
  → Check if items need repositioning
```

### Data Flow
```
User creates profile
  → Profile stored in WarbandStockistDB
  → UI updates to show profile

User assigns item to profile
  → Assignment stored in profile.assignments
  → Inventory scanner monitors for item

Bank opens
  → Compare bags vs profile rules
  → Auto-deposit/withdraw as needed
  → Update character data
```

## TOC File Requirements

When adding new Lua files, update `WarbankStockist.toc`:
```toc
## Interface: 120000
## Title: Warbank Stockist
## Notes: Automatically manages item quantities between your bags and the Warband Bank.
## Version: 1.1
## Author: Lucky Phil

ui/ui-theme.lua
common-utils.lua
frame-factory.lua
profile-manager.lua
core.lua
utils.lua
config.lua
character-data.lua
profiles.lua
ui/ui-row.lua
ui/ui-components.lua
ui/ui-tabs.lua
ui/profile-panel.lua
ui/assignment-panel.lua
ui/settings-panel.lua
inventory.lua
bank.lua
deposit-commands.lua
NewFile.lua  ← Add here in load order

## SavedVariables: WarbandStockistDB, WarbandStorageData
## SavedVariablesPerCharacter: WarbandStorageCharData
## Dependencies: Blizzard_Settings
```

## Performance Considerations

- **Throttle bag scans**: Don't scan on every BAG_UPDATE, use debouncing
- **Cache item data**: Store item info to avoid repeated API calls
- **Batch operations**: Group deposits/withdrawals when possible
- **Limit profile size**: Large profiles with many rules can slow down scanning

## Git Workflow

### Commit Messages
Follow conventional commits:
```bash
feat: add profile import/export functionality
fix: correct item quantity calculation
docs: update README with profile examples
chore: bump version to 1.2.0
ci: improve release workflow packaging
```

### Release Process
```bash
# 1. Update version in TOC file
# 2. Update CHANGELOG.md with new version (if exists)
# 3. Commit changes
git add .
git commit -m "chore: bump version to v1.2.0"

# 4. Push to main
git push origin main

# 5. Create and push tag
git tag v1.2.0
git push origin v1.2.0

# 6. GitHub Actions automatically:
#    - Packages addon from WarbankStockist subfolder
#    - Creates release zip
#    - Uploads to CurseForge via BigWigsMods packager
#    - Optionally creates GitHub Release (if GITHUB_OAUTH set)
```

## When Making Changes

1. **Check for existing patterns** - Look at similar code in other files
2. **Test in-game** - Open warband bank to verify behavior
3. **Enable debug logging** - Use debug mode to see what's happening
4. **Handle edge cases** - nil checks, empty tables, API failures, bank not available
5. **Update CHANGELOG.md** - Add user-facing changes only (new features, bug fixes, behavior changes). Skip internal refactoring, code cleanup, or non-visible changes
6. **Update documentation** - README.md and inline comments when needed
7. **Verify TOC load order** - Ensure dependencies are loaded first

### Changelog Guidelines
- **Include**: New features, bug fixes, UI changes, performance improvements users will notice, API changes
- **Exclude**: Code refactoring, variable renames, internal architecture changes, dependency updates
- **Format**: Use Added/Changed/Fixed/Removed categories under the version heading

## Resources

- [WoW API Documentation](https://wowpedia.fandom.com/wiki/World_of_Warcraft_API)
- [Bank API](https://wowpedia.fandom.com/wiki/API_C_Bank)
- [Item API](https://wowpedia.fandom.com/wiki/API_C_Item)
- [Lua 5.1 Reference](https://www.lua.org/manual/5.1/)
