# Copilot Instructions

## Repo context

- Monorepo root contains multiple addons under top-level folders.
- Current addons include `ProfessionUI` and `BankMatsViewer`.

## Architecture guardrails

- Use WoW addon runtime Lua APIs for addon features.
- Do not place secrets in addon Lua code or addon assets.

## Coding expectations

- Keep changes scoped to the target addon.
- Preserve existing code style and folder layout.
- Prefer practical, testable changes with minimal risk.
