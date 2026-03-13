# Blizzard WoW API Reference (Practical)

Source root: https://community.developer.battle.net/documentation/world-of-warcraft

## 1) API families

World of Warcraft docs are split into:

- Game Data APIs: static and dynamic world data.
- Profile APIs: account and character profile data.
- Guides: namespaces, known issues, localization, media documents, character renders, search.

## 2) Hosts and regions

For non-China regions, host format is:

- `{region}.api.blizzard.com`

Supported region keys in WoW docs include:

- `us`, `eu`, `kr`, `tw` (and `cn` for China partition)

China host:

- `gateway.battlenet.com.cn`

## 3) Namespaces (required for every WoW request)

A namespace can be sent as either:

- Header: `Battlenet-Namespace: {namespace}`
- Query: `?namespace={namespace}`

Namespace categories:

- Static: `static-{region}`
- Dynamic: `dynamic-{region}`
- Profile: `profile-{region}`

Typical examples:

- `static-us`
- `dynamic-eu`
- `profile-kr`

## 4) Localization behavior

Supported locale codes include:

- `en_US`, `es_MX`, `pt_BR`, `de_DE`, `en_GB`, `es_ES`, `fr_FR`, `it_IT`, `ru_RU`, `ko_KR`, `zh_TW`, `zh_CN`

Behavior:

- Without `locale`, localized fields can include all locale values.
- With `?locale=<code>`, localized fields are flattened to that locale.

## 5) OAuth essentials

Docs: Using OAuth + Client Credentials Flow + Authorization Code Flow

Token URIs:

- Global: `https://oauth.battle.net/token`
- China: `https://oauth.battlenet.com.cn/token`

Authorize URIs:

- Global: `https://oauth.battle.net/authorize`
- China: `https://oauth.battlenet.com.cn/authorize`

Client credentials flow (most requests):

- `POST /token` with `grant_type=client_credentials`
- Basic auth uses `client_id` as user and `client_secret` as password

Authorization code flow (user-consented resources):

- Redirect to authorize URI with `client_id`, `scope`, `state`, `redirect_uri`, `response_type=code`
- Exchange code via `POST /token` using `grant_type=authorization_code`

Token lifetime called out in docs:

- `expires_in` approximately 24 hours in examples.

## 6) Request construction baseline

- Include bearer token in `Authorization: Bearer <token>` header.
- Build request URI from host + API path.
- Include `namespace` for WoW Game Data/Profile endpoints.
- Include `locale` when deterministic language output is needed.

## 7) Throughput and throttling note

Getting Started documents:

- 36,000 requests/hour
- 100 requests/second
- 429 errors when per-second quota is exceeded

## 8) Key implementation takeaway for this repo

For your addon monorepo:

- Addon runtime code (`ProfessionUI`, `BankMatsViewer`) uses in-game Lua APIs.
- Blizzard web API docs here are best used for optional companion tooling (for example, cache builders, account/profile fetchers, data import scripts).
