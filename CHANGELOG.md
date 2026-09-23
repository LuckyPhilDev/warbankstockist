## [2.0.1] - 2026-09-23

### Fixed
- The Add button on the Sets page works again with the Keep box left blank, adding the item with a Keep of 0. (Thanks for the report Miserian)

## [2.0.0] - 2026-09-21

### Added
- **Sets** Give each character as many item lists as you like, such as a general set plus a raiding set, from the Assignments page. Your profiles carry over as sets.
- **Every Character** A set with Every Character ticked on the Sets page stocks all your characters, new ones included. Untick it for any character on the Assignments page.
- **Deposit All** A set of this Set Type on the Sets page sends every item on it to your Warband Bank whenever you open the bank.
- **Reserves** The Reserves page sets how many of an item your Warband Bank always keeps, and only characters marked Priority withdraw below it. (Thanks for the suggestion 2B, or not 2B)
- **Standard Sets** New on the Sets page can add a ready-made set that follows a rule instead of a list: one per reagent category, Lumber, or Weekly Treatise, which withdraws a Thalassian Treatise for each of your professions until you use it that week.
- **Lucky's Grab-bag - Bank Features** Reagent Mains, Lumber, Treatise withdrawal and the Custom Item Whitelist carry over as sets on the Sets page, with your mains unticked, and Grab-bag leaves those moves to Stockist. (Thanks for the suggestion Halliday)

### Improved
- **Warbound Items** A standard set on the Sets page now, not Bank page options, so you pick which characters deposit warbound gear. Armor, weapons, tokens and everything else warbound, such as consumables, are separate choices on the set, and your Bank settings carry over.
- **Sort Bank After Deposit** Now one setting on the Bank page for all your characters, instead of one per profile.

### Fixed
- Hide Bank Queue on the Bank page is locked off while Warbank Stocking Mode is Manual, which needs the window for its Start button, and goes back to your own choice on Auto.
- The Warbank Stocking Mode dropdown on the Bank page no longer covers its own label.
- Renaming or duplicating a set on the Sets page keeps all of its options, and Duplicate no longer overwrites an existing copy.
- The /wbs report lists your tracked items by name against the amounts your sets keep.
- Characters you Ignore on the Assignments page no longer run any of your sets.
- A Thalassian Treatise withdrawn for this week's profession quest is no longer deposited again by a set that deposits treatises, as long as Weekly Treatise is on. (Thanks for the suggestion Tuulani)

### Removed
- Deposit Excess Items is gone. Every set now returns anything in your bags above an item's Keep amount to the Warband Bank.
- Default Qty to 0 is gone, since a Deposit All set on the Sets page does the same job.
