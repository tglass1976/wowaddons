# AI Reference Pack

Purpose: provide compact, machine-friendly context for coding assistants working in this repo.

## Files

- `knowledge.yaml`: canonical facts from Blizzard WoW web API docs.
- `addon-scope.yaml`: decision map for what belongs in addon runtime vs external tooling.
- `query-index.json`: fast lookup index for common AI questions.
- `prompts.md`: reusable prompt snippets for AI agents.

## Usage guidance for AI

1. Read `knowledge.yaml` first for protocol and constraints.
2. Read `addon-scope.yaml` before proposing implementation architecture.
3. Use `query-index.json` for direct question routing.
4. Use `prompts.md` for repeatable task setup.

## Scope warning

These docs describe Blizzard web APIs (HTTP/OAuth). They do not replace in-game Lua API documentation used by WoW addons.
