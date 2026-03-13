# Bank Mats Viewer

A World of Warcraft addon that shows crafting materials currently stored in your bank and reagent bank.

## Features

- Scans bank containers and reagent bank while the bank window is open.
- Filters items to crafting materials.
- Caches latest scan result in saved variables.
- Slash commands:
  - `/bmats`
  - `/bankmats`

## Install

1. Copy the `BankMatsViewer` folder into your WoW `Interface/AddOns` directory.
2. Launch WoW and enable **Bank Mats Viewer**.
3. Open your bank at least once, then run `/bmats`.

## Notes

- Best results are in modern WoW clients where `C_Item.IsCraftingReagentItem` is available.
- If item data is not cached yet, item names can appear as `item:<id>` until WoW loads details.
