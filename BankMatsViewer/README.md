# Bank Mats Viewer

A World of Warcraft addon that shows crafting materials from your Warband Bank in a grouped inventory grid.

## Features

- Scans Warband Bank tabs while the bank window is open.
- Shows a GUI inventory grid with item icons and stack counts.
- Creates sections for each expansion (newest first).
- Includes a tracked catalog across major material types (cloth, herbs, ores/metals, leather).
- Missing catalog entries are displayed as greyed-out icons.
- Reagent quality variants are supported, with quality tier badge overlays on item icons when available.
- Caches latest scan result in saved variables.
- Slash commands:
  - `/bmats`
  - `/bankmats`
  - `/bmats scan` (force a rescan)
  - `/bmats audit` (print tracked vs full-catalog diagnostics in chat)
  - `/bmats missing N` (print up to `N` missing tracked items)
  - `/bmats missing N all` (print up to `N` missing full-catalog items, including discovered history)
  - `/bmats help`

## Install

1. Copy the `BankMatsViewer` folder into your WoW `Interface/AddOns` directory.
2. Launch WoW and enable **Bank Mats Viewer**.
3. Open your bank at least once so Warband Bank data can be scanned.
4. Run `/bmats` to open the UI window.

## Notes

- Best results are in modern WoW clients where `C_Item.IsCraftingReagentItem` is available.
- If item data is not cached yet, some names may appear as `item:<id>` until WoW loads details.
- Warband tab bag IDs are detected dynamically when possible, with a fallback range for compatibility.
- The tracked material catalog is maintained in `BankMatsViewer.lua` (`TRACKED_MATERIAL_ITEM_IDS`).
- The addon keeps a discovered item catalog (`catalogItemIDs`) so comparison views can include previously seen materials, not only currently owned stacks.
