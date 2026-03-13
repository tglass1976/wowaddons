# Bank Mats Viewer

A World of Warcraft addon that shows crafting materials from your Warband Bank in a grouped inventory grid.

## Features

- Scans Warband Bank tabs while the bank window is open.
- Shows a GUI inventory grid with item icons and stack counts.
- Creates sections for each expansion, then organizes by quality, then profession/type.
- Cloth section includes tracked cloth materials you do not currently own.
- Missing cloth entries are displayed as greyed-out icons.
- Shared-use reagents are grouped under `Multi-Profession` instead of a generic crafting label.
- Midnight test mode is enabled (currently includes all reagent materials while testing).
- Caches latest scan result in saved variables.
- Slash commands:
  - `/bmats`
  - `/bankmats`
  - `/bmats scan` (force a rescan)

## Install

1. Copy the `BankMatsViewer` folder into your WoW `Interface/AddOns` directory.
2. Launch WoW and enable **Bank Mats Viewer**.
3. Open your bank at least once so Warband Bank data can be scanned.
4. Run `/bmats` to open the UI window.

## Notes

- Best results are in modern WoW clients where `C_Item.IsCraftingReagentItem` is available.
- If item data is not cached yet, some names may appear as `item:<id>` until WoW loads details.
- Warband tab bag IDs are detected dynamically when possible, with a fallback range for compatibility.
- The tracked cloth catalog is currently maintained in `BankMatsViewer.lua` (`TRACKED_CLOTH_ITEM_IDS`).
- The addon keeps a discovered item catalog (`catalogItemIDs`) so comparison views can include previously seen materials, not only currently owned stacks.
