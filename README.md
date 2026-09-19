# Lucky's Warband Stockist

Keep chosen items and gold topped up across your characters using the Warband Bank.

[Join the Discord](https://discord.gg/ptTtYyAjdZ)

## Features

- **Stock sets**: Build item lists for raiding, crafting, gathering, leveling, or any other purpose, and give each character as many as you like.
- **Every Character sets**: A set can stock all your characters, new ones included, with any character left out from the Characters page.
- **Keep in Bags or Deposit All**: A Keep in Bags set withdraws each item up to its Keep amount. A Deposit All set sends every item on it to the Warband Bank.
- **Standard sets**: Add ready-made sets that follow a rule instead of a list: every reagent of a category, such as Herbs or Cloth, all lumber, or one unused Thalassian Treatise for each of your professions each week.
- **Automatic withdrawals**: Opening the Warband Bank withdraws missing items until your bags reach the Keep amounts of the character's sets. When two sets list the same item, the larger amount wins.
- **Return Extras**: Optionally deposit anything above an item's Keep amount back into the Warband Bank.
- **Reserves**: The Warband Bank always keeps at least a chosen amount of an item, and only characters marked Priority withdraw below it.
- **Warbound auto-deposit**: Opening the Warband Bank can deposit warbound armor, weapons, and tier tokens from your bags before the restock runs.
- **Automatic bank sorting**: Clean up and sort the Warband Bank once the deposits finish.
- **Characters**: Choose each character's sets, mark Priority characters that may withdraw below your reserves, or ignore a character so none of your sets run for it.
- **Flexible item entry**: Add items by item link or item ID, or pick up a bag item and drop or click it onto the Item ID field, and set how many to keep.
- **Set management**: Create, rename, duplicate, and delete sets. A renamed set stays on every character that uses it.
- **Searchable item lists**: Filter large sets by item name or item ID.
- **Gold targets**: Keep characters at a chosen gold amount using level brackets, with optional per-character overrides.
- **Low stock warnings**: A set can open a small window at login listing its items a character's bags are short of. It closes itself after 10 seconds unless your mouse is over it.
- **Bank Queue**: A window beside the bank lists the items still to move, with a progress bar. Pause it mid-run, or switch to Manual mode to review the list and press Start yourself. Lucky's Grab-bag's bank moves share the same queue.
- **Manual transfers**: Deposit or withdraw a single item with slash commands while the Warband Bank is open.
- **Minimap access**: Open settings from a draggable minimap button, which can be hidden in settings.

## Installation

Install from [CurseForge](https://www.curseforge.com/wow/addons/luckys-warbank-stockist), or place the `Luckys_Warbank_Stockist` folder in `World of Warcraft/_retail_/Interface/AddOns/`.

Lucky's Utils is required. CurseForge release packages include it automatically.

## Usage

1. Open **Options > AddOns > Lucky's Warband Stockist**, or enter `/wbs`.
2. On the **Sets** page, create or select a set, then add its items and how many of each to keep.
3. On the **Characters** page, tick the sets each character should use. Sets with Every Character on are already ticked for everyone.
4. Open the Warband Bank. Missing items are withdrawn automatically, and your deposit, reserve, and gold rules are applied.

## Slash Commands

| Command | Action |
|---|---|
| `/wbs` | Open the settings panel |
| `/wbs report` | Print every item your sets keep on this character, with how many you have |
| `/wbs autoopen [on\|off\|toggle]` | Control whether settings open automatically when this character logs in |
| `/wbdeposit <itemID>` | Deposit one of the specified item while the Warband Bank is open |
| `/warbanddeposit <itemID>` | Alias for `/wbdeposit` |
| `/wbwithdraw <itemID or item link>` | Withdraw one of the specified item while the Warband Bank is open, ignoring reserves |
| `/warbandwithdraw <itemID or item link>` | Alias for `/wbwithdraw` |
| `/wbhelp` | Print the manual transfer command list |

## Settings

Open settings with the minimap button, `/wbs`, or **Options > AddOns > Lucky's Warband Stockist**.

- **What's New**: Highlights from recent releases, the installed versions, and links to the rest of the suite.
- **Sets**: Create empty or standard sets, rename, duplicate, and delete them, choose each one's Set Type, Return Extras, Every Character, Low Stock Warning, and Current Expansion Only options, and edit its items and Keep amounts.
- **Characters**: Tick the sets each character uses, mark Priority characters, or move unused characters into the ignored section and back again.
- **Reserves**: Set how many of each item the Warband Bank always keeps.
- **Gold**: Set target gold by level range and add overrides for individual characters.
- **Bank**: Choose whether warbound armor, weapons, and tier tokens are deposited when you open the bank, sort the Warband Bank after deposits, pick Auto or Manual for the Bank Queue, or hide its window.

The minimap button and debug logging are toggled from the buttons in the panel's title bar.

## A note on AI

My addons are made by one person who plays the game and wants them to work properly. I use AI tools to move faster, mostly on code, bug hunting, and docs, but every change is reviewed and tested in game before release. If a feature feels off or something breaks, that's mine to fix, and the Discord is the fastest way to reach me.

## Author

Lucky Phil
