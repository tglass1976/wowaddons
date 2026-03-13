# ProfessionUI TODO

## Minimap Button Startup Visibility (Open)

Status: The minimap button is visually correct and appears in the right place after `/puiresetbtn`, but it still does not appear automatically on login/reload.

### What is already done

- Added button creation on `ADDON_LOADED`.
- Added visibility reassert on `PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD`.
- Added retry logic for minimap readiness.
- Added off-screen detection and default angle fallback.
- Switched to Blizzard-style tracking button visuals and corrected icon alignment.
- Added reset command:
  - `/puiresetbtn`
  - `/puireset`

### Repro

1. `/reload`
2. Do not run reset command
3. Expected: button appears on minimap edge automatically
4. Actual: button hidden until `/puiresetbtn`

### Next debug steps

- Add a temporary debug slash command to print button state at login:
  - `IsShown`, `IsVisible`, `GetAlpha`, `GetParent`, `GetCenter`, minimap center/size, saved angle.
- Add temporary startup traces with timestamps for:
  - `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`
  - every retry call and final coordinates.
- Verify if another addon re-parents/hides unnamed minimap buttons after login.
- If third-party hide is confirmed:
  - persist explicit `SetParent(UIParent)` and re-run `Show()` in delayed timer (2s/5s/8s), and
  - optionally add a user setting to disable minimap button auto-show logic.

### Acceptance criteria

- Fresh login and `/reload` both show the minimap button without running reset commands.
- Button position persists correctly between sessions.

## Archaeology UI Rework (Planned)

Goal: redesign the Archaeology panel to be clearer and more useful than the current list view.

### Scope

- Rework typography/spacing for race rows and artifact progress.
- Improve visual hierarchy: race, active artifact, fragment progress, and solve-ready state.
- Add clearer solve status cues and reduce clutter.

### Acceptance criteria

- Archaeology tab is visually distinct and easier to scan at a glance.
- Solve-ready races are immediately obvious without reading detailed text.

## Secondary Profession Loading Behavior (Planned)

Goal: avoid opening the default Blizzard profession UI when selecting secondary professions.

### Scope

- Audit current data loading paths for Cooking/Fishing/Archaeology.
- Prevent automatic trade-skill open for secondary professions by default.
- Investigate loading patterns that fetch data without forcing default UI popups.

### Acceptance criteria

- Selecting secondary professions does not pop the default Blizzard trade skill frame unless explicitly requested by the user.
- ProfessionUI still displays stable data for secondary professions.

## Craft Options Redesign/Fix (Planned)

Goal: rework craft quantity/options logic because current behavior is not accurate.

### Scope

- Re-evaluate quantity control rules (`+`, `-`, available count, craftable state).
- Align craft button enable/disable logic with actual craft API constraints.
- Verify state updates after crafting (counts, recipe state, row controls).

### Acceptance criteria

- Quantity controls always reflect valid craft ranges.
- Craft button behavior is consistent with available materials and API state.

## Expansion Coverage Validation (Planned)

Goal: verify all expansion tabs populate correctly across professions.

### Scope

- Validate expansion mapping and aliasing for modern + legacy expansion names.
- Confirm recipe population and rank/max-rank display for each expansion tab.
- Identify and fix empty/mis-mapped expansion tabs.

### Acceptance criteria

- All supported expansion tabs populate correctly when data exists.
- No known expansion tabs remain empty due to mapping or filtering bugs.

## Show Source for Missing/Unlearned Recipes (Planned)

Goal: for recipes the player has not yet learned, display where they can be obtained.

### Scope

- Identify unlearned recipes in each expansion tab.
- Display source info per recipe (vendor, drop, quest, trainer, reputation, etc.) where API or data provides it.
- Consider using `C_TradeSkillUI` recipe info or wowhead-style static data table as source.
- Visually differentiate unlearned recipes with source hint vs. already-learned recipes.

### Acceptance criteria

- Unlearned recipes show a source hint (vendor name, quest, drop source, etc.) in the recipe row or a tooltip.
- Learned recipes are unaffected in appearance.
- Source data is accurate or clearly marked as approximate.
