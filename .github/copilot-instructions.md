# Copilot Instructions

## Reference-first workflow

When working in this repo, load these files first:

1. `reference/ai/query-index.json`
2. `reference/ai/knowledge.yaml`
3. `reference/ai/addon-scope.yaml`
4. `reference/ai/prompts.md`

## Repo context

- Monorepo root contains multiple addons under top-level folders.
- Current addons include `ProfessionUI` and `BankMatsViewer`.
- Shared documentation and machine-readable reference files are under `reference/`.

## Architecture guardrails

- Do not place OAuth secrets in addon Lua code or addon assets.
- Do not assume addon runtime performs OAuth redirect/token flows.
- For Blizzard web API use, recommend external tooling or hybrid data pipelines.

## Coding expectations

- Keep changes scoped to the target addon.
- Preserve existing code style and folder layout.
- Prefer practical, testable changes with minimal risk.
- Use source links in `reference/source-pages.md` for API claims.

## If uncertain

Use the decision map in `reference/ai/addon-scope.yaml` before suggesting implementation.
