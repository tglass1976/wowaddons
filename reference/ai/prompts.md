# Prompt Snippets For AI Agents

## 1) Architecture placement decision

Task: decide whether each proposed feature belongs in addon runtime, external tooling, or hybrid.
Context files:
- reference/ai/addon-scope.yaml
- reference/ai/knowledge.yaml
Output format:
- feature
- recommended_layer
- one-sentence reason
- implementation sketch

## 2) API request template generation

Task: generate minimal request templates for Blizzard WoW web APIs using correct host, namespace, locale, and bearer token format.
Constraints:
- do not invent endpoints not present in docs
- include both header and query style namespace examples
Context files:
- reference/ai/knowledge.yaml
- reference/source-pages.md

## 3) Addon-safe design review

Task: review a design and flag violations of addon runtime constraints.
Checks:
- secret handling
- OAuth in addon runtime
- unsupported assumptions about in-game networking
Context files:
- reference/ai/addon-scope.yaml

## 4) Data pipeline proposal

Task: propose a pipeline that fetches web API data offline and produces addon-readable artifacts.
Must include:
- refresh cadence
- error handling and backoff
- output artifact format
- in-addon loading strategy
Context files:
- reference/ai/knowledge.yaml
- reference/ai/addon-scope.yaml
