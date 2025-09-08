# Warband Bank Deposit Command System

## Overview
Created a new slash command system that allows depositing items from player bags directly into the warband bank using item IDs. This system is built independently using WoW's container and banking APIs.

## Commands Available

### `/wbdeposit <itemID>`
**Purpose**: Deposits 1 of the specified item from your bags into the warband bank
**Aliases**: `/warbanddeposit <itemID>`
**Example**: `/wbdeposit 6948` (deposits 1 Hearthstone)

### `/wbhelp`
**Purpose**: Shows help information and available commands

## Features

### ✅ **Smart Item Detection**
- Searches all player bags (0-4) for the specified item ID
- Handles both single items and stacks
- Provides clear feedback if item is not found

### ✅ **Warband Bank Integration** 
- Detects if warband bank is accessible
- Finds available slots in warband bank tabs
- Uses proper container APIs for account bank access

### ✅ **Stack Handling**
- Automatically splits stacks when depositing only 1 item
- Preserves remaining stack in player bags
- Handles single items and full stacks appropriately

### ✅ **Error Handling**
- Validates item IDs exist
- Checks if warband bank is available
- Provides helpful error messages and tips
- Safely handles API failures

## Technical Implementation

### **API Functions Used**
```lua
-- Container Management
C_Container.GetContainerNumSlots(bagID)
C_Container.GetContainerItemInfo(bagID, slotID)  
C_Container.PickupContainerItem(bagID, slotID)
C_Container.SplitContainerItem(bagID, slotID, quantity)

-- Item Information
C_Item.GetItemNameByID(itemID)
GetCursorInfo()

-- Banking
BankFrame:IsVisible()
C_Bank.IsAtBank()
```

### **Container IDs**
- **Player Bags**: 0-4 (backpack + 4 equipped bags)
- **Warband Bank**: Uses account bank container enums or -3 offset
- **Multiple Tabs**: Supports 5 warband bank tabs (standard)

### **Safety Features**
- Validates all parameters before execution
- Checks cursor state during item transfers  
- Restores items to original location on failure
- Clears cursor after successful operations

## Usage Instructions

### **Basic Usage**
1. **At a Bank**: Must be at a bank with warband banking available
2. **Get Item ID**: Use item links, tooltips, or online databases
3. **Run Command**: `/wbdeposit <itemID>`
4. **Confirmation**: System provides success/error feedback

### **Getting Item IDs**
- **Tooltip Method**: Hold Shift while hovering over items (if enabled)
- **Chat Links**: Shift+click item links while typing command
- **Online**: Use sites like Wowhead.com to look up item IDs
- **Addons**: Many addons display item IDs in tooltips

### **Examples**
```
/wbdeposit 6948     # Hearthstone
/wbdeposit 2589     # Linen Cloth  
/wbdeposit 818      # Tigerseye
/wbhelp             # Show help
```

## Error Messages Guide

| Message | Meaning | Solution |
|---------|---------|----------|
| "Warband bank is not available" | Not at bank or warband banking unavailable | Go to a bank that supports warband banking |
| "Item not found in your bags" | Item ID not in player inventory | Check item ID and inventory |
| "Invalid item ID" | Item ID doesn't exist | Verify the item ID is correct |
| "No available space in warband bank" | Warband bank is full | Make space in warband bank |
| "Failed to pick up item" | API error during transfer | Try again, check for UI conflicts |

## File Structure
- **Location**: `deposit-commands.lua`  
- **Load Order**: Added to `WarbankStockist.toc` 
- **Namespace**: `WarbandStockist_Commands`
- **Dependencies**: Core WoW APIs (no addon dependencies)

## Future Enhancements
- Support for depositing multiple quantities
- Integration with existing profile system
- Keybind support for common items  
- GUI item picker interface
- Batch deposit from profile lists

## Compatibility
- **WoW Version**: Retail (110200+)
- **API Dependencies**: Container API, Banking API  
- **Warband Support**: Requires warband banking feature
- **Fallback Methods**: Includes alternative API approaches for compatibility
