# ProfessionUI

A custom World of Warcraft addon that provides a unified UI window for browsing and managing your character's professions and recipes.

## Features

- Browse all your professions and their recipes from a single window
- Recipes organized by expansion (Classic through Midnight)
- Search recipes by name
- One-click crafting from the recipe list
- Archaeology tracking — view active artifacts and dig site progress by race
- Persistent settings saved per character via `SavedVariables`
- Diagnostic slash command for troubleshooting

## Slash Commands

| Command | Description |
|---------|-------------|
| `/profui` | Toggle the ProfessionUI window open/closed |
| `/profs` | Toggle the ProfessionUI window open/closed |
| `/professionui` | Toggle the ProfessionUI window open/closed |
| `/pui` | Toggle the ProfessionUI window open/closed |
| `/puidiag` | Print diagnostic information to the chat frame |

## Installation

1. Download or clone this repository.
2. Copy the `ProfessionUI` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Launch (or reload) the game and enable the addon in the AddOns menu on the character select screen.

## Compatibility

Supports the following WoW client versions (as declared in the `.toc`):

- **Retail** — 11.x / The War Within / Midnight
- **Cataclysm Classic** — 4.x
- **Classic Era / Anniversary** — 1.x

## Files

| File | Purpose |
|------|---------|
| `ProfessionUI.lua` | Addon entry point — constants, theme, and shared `addon` table |
| `ProfessionUILocalization.lua` | Localized strings |
| `ProfessionUIData.lua` | Data layer — profession loading, recipe data, archaeology data, crafting |
| `ProfessionUIUI.lua` | All UI frames, panels, scroll lists, and event handling |

## SavedVariables

`ProfessionUIDB` is saved per account and stores user preferences across sessions.

## Author

tglass1976

## Version

1.0.0
