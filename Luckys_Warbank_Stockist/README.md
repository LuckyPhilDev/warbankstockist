**Warband Stockist** is a smart inventory management addon for World of Warcraft that keeps chosen items topped up across your characters using the Warband Bank.

It automatically withdraws what you’re missing and, if enabled, deposits excess—preferring to merge into existing stacks and using empty slots only when needed.

---

## ✨ Features

- Auto‑withdraw: Match your configured stock when the Warband Bank opens.
- Auto‑deposit (optional): Move excess items back to the Warband Bank.
- Profiles + Assignments: Create named profiles and assign them to characters; ignored characters are listed separately and do not auto‑process.
- Desired = 0 means “keep none”: Items explicitly set to 0 will be deposited automatically.
- Stack‑first placement: Tries to merge into existing stacks (bags and bank) before using empty slots.

---

## 📋 Setup & Usage

1. Open settings: Interface → AddOns → Warband Stockist (or type /wbs settings).
2. Profiles tab:
	- Create/select a profile.
	- Add items by Item ID and desired quantity. Tip: 0 means “deposit all/keep none”.
3. Assignments tab:
	- Assign a profile to each character.
	- Optional: Mark characters as Ignored; they appear under a divider and won’t be auto‑processed.
4. Options:
	- Deposit Excess Items: enable if you want to auto‑deposit anything above the desired amounts.
	- Debug Logging: prints detailed steps to chat when enabled.

Behavior on bank open
- Uses the assigned profile for your character.
- Calculates need/excess from your current inventory (including reagent bag).
- Withdraws first, then deposits excess if enabled.
- Placement prefers stacking into existing stacks; otherwise uses the first available empty slot.

---

## 🧰 Commands

- /wbs settings — open the addon’s settings in the game Settings UI.

---

## � Troubleshooting & Debugging

- Enable “Debug Logging” in settings to print detailed messages (desired vs. inventory, queues, slot choices).
- On bank open you’ll see which profile is used and summary counts.
- If stack merges appear inconsistent, just keep the bank open—actions are paced; a second pass (reopen bank) may tidy remaining items depending on the in‑game API state.

---

## 🗒️ What’s New (recent updates)

- Switched to Profiles + Assignments; Ignored characters sorted last and visually divided in the Assignments tab.
- Auto behavior matches manual commands: stack‑first then empty‑slot fallback, with per‑slot max‑stack checks.
- Reagent bag support: included in scans and as a deposit source.
- Desired=0 now means “deposit all” for listed items.
- More robust logging on bank open, withdraw, and deposit flows.

---

With Warband Stockist, you’ll always be prepared—whether you’re switching specs, gearing alts, or just keeping your bags tidy.

> Note: Requires access to the Warband Bank and works best with consistent item availability.
