## [Unreleased]

### Added
- **Sets** Give each character as many item lists as you like, such as a general set plus a raiding set, from the Characters page. Your profiles carry over as sets.
- **Every Character** A set with Every Character ticked on the Sets page stocks all your characters, new ones included. Untick it for any character on the Characters page.
- **Deposit All** A set of this Set Type on the Sets page sends every item on it to your Warband Bank whenever you open the bank.
- **Reserves** The Reserves page sets how many of an item your Warband Bank always keeps, and only characters marked Priority withdraw below it. (Thanks for the suggestion 2B, or not 2B)
- **Standard Sets** New on the Sets page can add a ready-made set that follows a rule instead of a list: one per reagent category, Lumber, or Weekly Treatise, which withdraws a Thalassian Treatise for each of your professions until you use it that week.
- **Lucky's Grab-bag - Bank Features** Reagent Mains, Lumber, Treatise withdrawal and the Custom Item Whitelist carry over as sets on the Sets page, with your mains unticked, and Grab-bag leaves those moves to Stockist. (Thanks for the suggestion Halliday)

### Improved
- **Sort Bank After Deposit** Now one setting on the Bank page for all your characters, instead of one per profile.

### Fixed
- Renaming or duplicating a set on the Sets page keeps all of its options, and Duplicate no longer overwrites an existing copy.
- The /wbs report lists your tracked items by name against the amounts your sets keep.
- Characters you Ignore on the Characters page no longer run any of your sets.
- A Thalassian Treatise withdrawn for this week's profession quest is no longer deposited again by a set that deposits treatises, as long as Weekly Treatise is on. (Thanks for the suggestion Tuulani)

### Removed
- Default Qty to 0 is gone, since a Deposit All set on the Sets page does the same job.

## [1.13.0] - 2026-09-18

### Added
- **Bank Queue** A window beside the bank lists the items still to move, with a count and a progress bar, and ticks each one off as your warbound deposit, restock and excess deposit run. Lucky's Grab-bag's bank moves join the same queue, so the two addons take turns. (Thanks for the suggestion Halliday)
- **Manual Mode** The Bank Queue can list everything it is about to move to and from your Warband Bank under a Start button, and wait for you to press it. Handy when you only came for the guild bank or your gold. (Thanks for the suggestion Halliday)
- **Pause** A Pause button at the top of the Bank Queue stops your items moving after the current one, and Resume picks up where it left off.

### Fixed
- Deposit Excess Items no longer tries to deposit soulbound copies of a tracked item, which the Warband Bank refuses, every time you open the bank.
