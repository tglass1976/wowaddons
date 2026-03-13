# Agent Bootstrap

This repository contains multiple WoW addon projects.

## Working rules for this repo

- Treat `ProfessionUI` and `BankMatsViewer` as separate addon projects.
- Prefer additive changes; avoid unrelated refactors.
- Keep changes scoped to the target addon.
- Preserve existing folder structure and code style.

## Fast decision policy

- In-game inventory, bank, events, and UI behavior: addon runtime Lua APIs.
- Avoid introducing external dependencies unless explicitly requested.

## Output expectations

- Include file-level change plans before edits.
- Make practical, testable changes with minimal risk.
