# Agent Bootstrap

This repository contains multiple WoW addon projects and a shared reference library.

## Required startup sequence

Before proposing architecture or code, load these files in order:

1. `reference/ai/query-index.json`
2. `reference/ai/knowledge.yaml`
3. `reference/ai/addon-scope.yaml`
4. `reference/ai/prompts.md`

## Working rules for this repo

- Treat `ProfessionUI` and `BankMatsViewer` as separate addon projects.
- Prefer additive changes; avoid unrelated refactors.
- Keep addon runtime code free of Blizzard OAuth client secrets.
- If a feature requires OAuth or web API token exchange, propose external tooling or a hybrid pipeline.

## Fast decision policy

- In-game inventory, bank, and UI behavior: addon runtime.
- OAuth-authenticated account/profile retrieval: external tool.
- Large static metadata imports: external precompute + addon artifact load.

## Output expectations

- Include file-level change plans before edits.
- Preserve existing addon folder structure.
- Reference source docs from `reference/source-pages.md` when citing API behavior.
