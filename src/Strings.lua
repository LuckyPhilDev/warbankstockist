-- Warband Stockist: User-facing strings.
-- Centralised here so wording can be tweaked without hunting through feature
-- files. Format strings use Lua's standard %s / %d placeholders; pass through
-- string.format at the call site. Debug output stays inline with the code that
-- emits it, being diagnostics rather than copy.

WarbandStorage = WarbandStorage or {}

WarbandStorage.Strings = LuckyStrings.New("WarbandStorage.Strings", {
    addon = {
        title         = "Lucky's Warband Stockist",
        prefix        = "|cff7fd5ff[Warband Stockist]|r",
        errorPrefix   = "|cffff0000Error:|r",
        successPrefix = "|cff00ff00Success:|r",
    },

    minimap = {
        tooltipTitle = "|cffffd100Warband Stockist|r",
        click        = "Click: Open settings",
        middleClick  = "Middle-click: Toggle dev mode",
        drag         = "Drag: Move button",
        devMode      = "Dev mode %s.",
        devModeOn    = "|cff00ff00enabled|r",
        devModeOff   = "|cffff0000disabled|r",
    },

    whatsNew = {
        -- Must match the library's own heading, or the panel repeats it.
        section     = "What's New",
        versionInfo = "Version info",
        utilsLabel  = "Lucky's Utils",
    },

    settings = {
        unknownCommand = "Unknown /wbs command. Try: settings, report, autoopen, perf, devopen",
    },

    profiles = {
        section       = "Profiles",
        label         = "Profile",
        labelDesc     = "The profile these options and the item list apply to. A profile keeps the items you list topped up from your Warband Bank for every character it is assigned to.",
        new           = "New",
        newDesc       = "Create an empty profile and start editing it. Assign it to a character on the Assignments page.",
        rename        = "Rename",
        renameDesc    = "Give this profile a new name. Every character assigned to it follows the rename.",
        duplicate     = "Duplicate",
        duplicateDesc = "Copy this profile, item list and options included, as a starting point for another one.",
        delete        = "Delete",
        deleteDesc    = "Remove this profile. Characters assigned to it are left unassigned.",
        newPrompt     = "Enter new profile name:",
        renamePrompt  = "Rename profile:",
        clearPrompt   = "Clear all tracked items for profile '%s'?",
        deletePrompt  = "Delete profile '%s'? This cannot be undone.",
        nameRequired  = "Please enter a profile name.",
        nameEmpty     = "Profile name cannot be empty.",
        nameTooLong   = "Profile name is too long (max 40 characters).",
        nameInvalid   = "Profile name contains invalid characters.",
        nameReserved  = "The profile name '%s' is reserved.",
        nameTaken     = "A profile named '%s' already exists.",
    },

    assignments = {
        section           = "Assignments",
        unassign          = "Unassign",
        ignore            = "Ignore",
        include           = "Include",
        unassigned        = "Unassigned",
        ignoredCharacters = "Ignored Characters",
    },

    addItem = {
        itemIdLabel   = "Item ID",
        itemIdTooltip = "Enter the numeric ID of the item you want to track. You can also drop an item link here.",
        qtyLabel      = "Qty",
        qtyTooltip    = "Enter the quantity to keep stocked.",
        add           = "Add",
        addTooltip    = "Adds the specified item and quantity to the profile's stock list.",
        clear         = "Clear List",
        clearTooltip  = "Removes all items from the current profile.",
    },

    tracked = {
        section           = "Items",
        empty             = "No items tracked in this profile. Add one below.",
        noMatches         = "No tracked item matches that filter.",
        filterPlaceholder = "Filter items...",
        remove            = "Remove",
    },

    deposit = {
        section               = "Deposit",
        excess                = "Deposit Excess Items",
        excessTooltip         = "When enabled, items this profile stocks beyond their configured amount are deposited into the Warband Bank when it is open. Applies to every character assigned to this profile.",
        sortAfter             = "Sort Bank After Deposit",
        sortAfterTooltip      = "When enabled, the Warband Bank is cleaned up and sorted automatically once this profile finishes depositing. Applies to every character assigned to this profile.",
        defaultQtyZero        = "Default Qty to 0",
        defaultQtyZeroTooltip = "When enabled, the Qty box in Add Item starts at 0 instead of blank for this profile, so items you only want deposited can be added in one click. Requires Deposit Excess Items.",
    },

    warbound = {
        section        = "Warbound",
        master         = "Auto-Deposit Warbound Items",
        masterTooltip  = "When you open the bank, deposits warbound gear from your bags into the Warband Bank before restocking your profile.",
        armor          = "Warbound Armor",
        armorTooltip   = "Auto-deposit warbound armor.",
        weapons        = "Warbound Weapons",
        weaponsTooltip = "Auto-deposit warbound weapons.",
        tokens         = "Warbound Tokens",
        tokensTooltip  = "Auto-deposit warbound tier tokens.",
        hint           = "Items with a stock amount in the active profile are never deposited by this; the restock keeps them in your bags.",
    },

    gold = {
        section          = "Gold",
        bracketsSection  = "Level Brackets",
        bracketHint      = "Characters whose level falls within a bracket automatically have their gold balanced when at the Warband Bank. Overrides below always take priority.",
        colMinLevel      = "Min Lvl",
        colMaxLevel      = "Max Lvl",
        colGold          = "Gold (g)",
        addBracket       = "Add Bracket",
        removeBracket    = "Remove",
        overridesSection = "Character Overrides",
        overrideHint     = "Set a specific gold amount for an individual character, overriding any bracket. Leave blank or set 0 to remove.",
        colCharacter     = "Character",
        addOverride      = "Add Override",
        removeOverride   = "Remove",
        createBracket    = "Create / Adjust Bracket",
        createOverride   = "Create / Adjust Override",
        noBrackets       = "No brackets defined. Add one below.",
        noOverrides      = "No character overrides set. Add one below.",
        selectCharacter  = "Select character...",
        invalidBracket   = "Enter valid Min (1 or more), Max (Min or more), Gold (above 0).",
        invalidOverride  = "Select a character and enter a gold amount above 0.",
        deposited        = "Deposited %dg %ds %dc to Warband Bank.",
        withdrew         = "Withdrew %dg %ds %dc from Warband Bank.",
    },

    commands = {
        depositUsage      = "Usage: /wbdeposit <itemID>",
        depositExample    = "Example: /wbdeposit 6948",
        bankUnavailable   = "Warband bank is not available. You must be at a warband bank to use this command.",
        itemIdFallback    = "Item ID: %d",
        depositSuccess    = "Deposited 1x %s into warband bank.",
        withdrawInvalid   = "Please provide a valid item ID or item link.",
        withdrawUsage     = "|cffccccccUsage:|r /wbwithdraw <itemID> or /wbwithdraw [item link]",
        invalidItemId     = "Invalid item ID: %s",
        helpTitle         = "|cff7fd5ff[Warband Stockist] Available Commands:|r",
        helpDeposit       = "|cff00ff00/wbdeposit <itemID>|r - Deposit 1 of the specified item into warband bank",
        helpDepositAlias  = "|cff00ff00/warbanddeposit <itemID>|r - Same as above",
        helpWithdraw      = "|cff00ff00/wbwithdraw <itemID>|r - Withdraw 1 of the specified item from warband bank",
        helpWithdrawAlias = "|cff00ff00/warbandwithdraw <itemID>|r - Same as above",
        helpHelp          = "|cff00ff00/wbhelp|r - Show this help message",
        helpNote          = "|cffccccccNote:|r You must be at a warband bank to use these commands.",
        loaded            = "Deposit commands loaded. Type /wbhelp for usage.",
    },
})
