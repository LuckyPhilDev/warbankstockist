## v1.9.2

### Changed
- `/wbs` on its own now opens the settings panel directly, instead of requiring `/wbs settings`. The old default behavior (scan bags and print tracked inventory) moved to `/wbs report`.

## v1.9.1

### Improved
- Tighter settings layout, so the tracked items list shows more items without scrolling.
- Faster list updates when adding, removing, or filtering items.

### Fixed
- The tracked items scrollbar can now be dragged, and no longer overlaps the bottom of the panel.

## v1.9.0

### Added
- Pick up an item from your bags and click the Item ID field to fill it in, as well as dragging it there.
- Per-profile "Default Qty to 0" option, so the quantity box starts at 0 instead of blank when you add items you only want deposited. Off by default, and available on profiles that deposit excess. If you clear the quantity, it goes back to 0 as soon as you enter an item.

## v1.8.2

### Improved
- Minor maintenance and packaging updates.

## v1.8.1

### Improved
- Updated for the latest game patch.

## v1.8.0

### Added
- Search box on the Profiles tab to filter the tracked items list by name or item ID, so you can quickly find an entry in a large profile.

### Fixed
- The tracked items filter box now lines up with the section header and no longer overlaps the list.

## v1.7.3

### Fixed
- Items withdrawn from the Warband Bank now stack onto matching items already in your bags instead of taking up new slots. Thanks to Eshir for reporting the bug and contributing the fix.

## v1.7.2

### Fixed
- "Sort Bank After Deposit" now works for profiles that have "Deposit Excess Items" turned off. The sort was previously only triggered as part of the excess-deposit pass, so it never ran when that option was disabled.

## v1.7.1

### Improved
- New profiles now deposit excess stock by default, so over-stock is returned to the Warband Bank without any extra setup.

## v1.7.0

### Added
- Option to hide the minimap button, in Settings.
- Per-profile "Sort Bank After Deposit" toggle that tidies the Warband Bank automatically once a deposit run finishes.

### Fixed
- Minimap button now appears correctly on the minimap instead of sometimes hiding behind it.
- Removed a black square that could appear when hovering the minimap button.

### Improved
- Move the minimap button with a simple click and drag.
