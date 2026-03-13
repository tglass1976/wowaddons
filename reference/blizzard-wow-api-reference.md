# Blizzard WoW API Reference

Sources (fetched March 2026):
- https://community.developer.battle.net/documentation/world-of-warcraft/guides/namespaces
- https://community.developer.battle.net/documentation/world-of-warcraft/guides/known-issues
- https://community.developer.battle.net/documentation/world-of-warcraft/guides/localization
- https://community.developer.battle.net/documentation/world-of-warcraft/guides/media-documents
- https://community.developer.battle.net/documentation/world-of-warcraft/guides/character-renders
- https://community.developer.battle.net/documentation/world-of-warcraft/guides/search
- https://community.developer.battle.net/documentation/world-of-warcraft/game-data-apis
- https://community.developer.battle.net/documentation/world-of-warcraft/profile-apis

---

## 1. API Families

| Family | Description | Namespace Category |
|--------|-------------|-------------------|
| Game Data APIs | Static and dynamic game world data | `static-{region}` or `dynamic-{region}` |
| Profile APIs | Account and per-character/guild data | `profile-{region}` |

## 2. Hosts and Regions

Non-China: `{region}.api.blizzard.com`

| Region | Key |
|--------|-----|
| North America | `us` |
| Europe | `eu` |
| Korea | `kr` |
| Taiwan | `tw` |

China: `gateway.battlenet.com.cn`

---

## 3. Namespaces

Every WoW Game Data and Profile API request **must** include a namespace.

### Categories

| Category | Pattern | Description |
|----------|---------|-------------|
| Static | `static-{region}` | Per-patch game data (items, achievements, spells, etc.) |
| Dynamic | `dynamic-{region}` | Frequently-changing live data (leaderboards, WoW Token, auctions) |
| Profile | `profile-{region}` | Character/guild/account data. Characters updated on logout; guilds at regular intervals. |

### Region Identifiers

| Region | ID |
|--------|----|
| North America | `us` |
| Europe | `eu` |
| Korea | `kr` |
| Taiwan | `tw` |
| China | `cn` |

Examples: `static-us`, `dynamic-eu`, `profile-kr`, `dynamic-cn`

### Specifying in a Request

| Method | Format | Example |
|--------|--------|---------|
| Header | `Battlenet-Namespace: {namespace}` | `Battlenet-Namespace: static-us` |
| Query | `?namespace={namespace}` | `?namespace=static-us` |

---

## 4. Localization

### Supported Locales

| Language | Code |
|----------|------|
| English (United States) | `en_US` |
| Spanish (Mexico) | `es_MX` |
| Portuguese (Brazil) | `pt_BR` |
| German | `de_DE` |
| English (Great Britain) | `en_GB` |
| Spanish (Spain) | `es_ES` |
| French | `fr_FR` |
| Italian | `it_IT` |
| Russian | `ru_RU` |
| Korean | `ko_KR` |
| Chinese (Traditional) | `zh_TW` |
| Chinese (Simplified) | `zh_CN` |

### Behavior

- **Without `?locale`:** Localized fields return an object with all locale values.
- **With `?locale={code}`:** Localized fields are flattened to the single requested value.

**Without locale:**
```json
{ "name": { "en_US": "Alliance", "ko_KR": "얼라이언스", ... } }
```

**With `?locale=ko_KR`:**
```json
{ "name": "얼라이언스" }
```

---

## 5. OAuth

### Token Endpoints

| Region | Token URI | Authorize URI |
|--------|-----------|---------------|
| Global | `https://oauth.battle.net/token` | `https://oauth.battle.net/authorize` |
| China | `https://oauth.battlenet.com.cn/token` | `https://oauth.battlenet.com.cn/authorize` |

### Client Credentials Flow (server-to-server, most API calls)

```
POST /token
Authorization: Basic base64(client_id:client_secret)
Body: grant_type=client_credentials
```

Token valid for ~24 hours (`expires_in` in response).

### Authorization Code Flow (user-consented profile data)

1. Redirect user to `/authorize?client_id=...&scope=...&state=...&redirect_uri=...&response_type=code`
2. Exchange code: `POST /token` with `grant_type=authorization_code`

### Using the Token

```
Authorization: Bearer {access_token}
```

---

## 6. Request Construction

```
GET https://{region}.api.blizzard.com{path}?namespace={namespace}&locale={locale}
Authorization: Bearer {access_token}
```

Example:
```
GET https://us.api.blizzard.com/data/wow/item/19019?namespace=static-us&locale=en_US
Authorization: Bearer eyJ...
```

---

## 7. Throttling

- **36,000 requests/hour** per client
- **100 requests/second** per client
- Returns `429` when per-second quota exceeded

---

## 8. Media Documents

Media documents expose cached web assets (icons, renders, images) linked from game data resources.

### Pattern

1. A resource document (e.g. item) contains a `media` key:
   ```json
   { "media": { "key": { "href": "https://us.api.blizzard.com/data/wow/media/item/19019?namespace=static-us" }, "id": 19019 } }
   ```

2. Fetch the media document to get assets:
   ```
   GET /data/wow/media/item/19019?namespace=static-us
   ```
   Response:
   ```json
   { "assets": [ { "key": "icon", "value": "https://render-us.worldofwarcraft.com/icons/56/inv_sword_39.jpg" } ] }
   ```

> **Important:** Cache asset URLs on your own servers. Do not link directly to Blizzard CDN resources in production.

### Media Search

Use the search endpoint with `_tag` to query media documents by type:
```
GET /data/wow/search/{documentType}?namespace=static-us&_tag=item
```

---

## 9. Character Renders

Character renders are generated when a character logs out of the game.

### Endpoint

```
GET /profile/wow/character/{realm-slug}/{character-name}/character-media
Namespace: profile-{region}
```

Returns render URLs including `avatar_url`.

### Fallback Images

If an avatar doesn't exist, request a fallback via `?alt`:

```
{avatar_url}?alt=/shadow/avatar/{race-id}-{gender-id}.jpg
```

| Gender | ID |
|--------|----|
| Male | `0` |
| Female | `1` |

Get race IDs from:
```
GET /data/wow/playable-race/index?namespace=static-us
```

---

## 10. Search API

### Currently Supported Document Types

- `realm`
- `connected-realm`

### URL Pattern

```
GET /data/wow/search/{documentType}?namespace={namespace}
GET /data/wow/search/{documentType}?namespace={namespace}&{field}={value}
```

Nested fields use dot notation:
```
/data/wow/search/connected-realm?namespace=dynamic-us&realms.timezone=America/New_York
```

### Special Parameters

| Parameter | Example | Description |
|-----------|---------|-------------|
| `_tag` / `_tags` | `_tag=item` | Media search: specifies document type |
| `_page` | `_page=2` | Page number (default: 1) |
| `_pageSize` | `_pageSize=500` | Results per page (default: 100, min: 1, max: 1000) |
| `orderby` | `orderby=field1:desc,field2:asc` | Comma-separated fields with optional `:asc`/`:desc` |
| `namespace` | `namespace=dynamic-us` | Required namespace |

### Query Operators

| Operation | Syntax | Example |
|-----------|--------|---------|
| AND (implicit) | Multiple params | `str=5&dex=10` |
| OR | `||` between values | `type=man||bear||pig` |
| NOT | `!=` | `race!=orc` |
| NOT + OR | Combined | `race!=orc||human` |
| RANGE inclusive | `[min,max]` | `str=[2,99]` |
| RANGE exclusive | `(min,max)` | `str=(2,99)` |
| MIN | `[min,]` | `str=[41,]` |
| MAX | `[,max]` | `str=[,77]` |

---

## 11. Known Issues

### Unavailable Child Document Links

A JSON response may link to a child document that returns `404`, `401`, or another error because:
- It is protected by a private scope not yet released for public consumption.
- It has not yet been published.

This is expected behavior — not a bug.

---

## 12. Game Data APIs — Endpoint Reference

Host: `{region}.api.blizzard.com`
Namespace: `static-{region}` (game data) or `dynamic-{region}` (live data) per endpoint.

See full listing: https://community.developer.battle.net/documentation/world-of-warcraft/game-data-apis

### Achievement API
| Endpoint | Path |
|----------|------|
| Achievements Index | `GET /data/wow/achievement/index` |
| Achievement | `GET /data/wow/achievement/{achievementId}` |
| Achievement Media | `GET /data/wow/media/achievement/{achievementId}` |
| Achievement Categories Index | `GET /data/wow/achievement-category/index` |
| Achievement Category | `GET /data/wow/achievement-category/{achievementCategoryId}` |

### Auction House API
| Endpoint | Path |
|----------|------|
| Auctions | `GET /data/wow/connected-realm/{connectedRealmId}/auctions` |
| Commodities | `GET /data/wow/auctions/commodities` |

### Azerite Essence API
| Endpoint | Path |
|----------|------|
| Azerite Essences Index | `GET /data/wow/azerite-essence/index` |
| Azerite Essence | `GET /data/wow/azerite-essence/{azeriteEssenceId}` |
| Azerite Essence Search | `GET /data/wow/search/azerite-essence` |
| Azerite Essence Media | `GET /data/wow/media/azerite-essence/{azeriteEssenceId}` |

> The full API listing is large. The page groups endpoints alphabetically by API name (Connected Realm, Covenant, Creature, Guild Crest, Item, Journal, Media Search, Modified Crafting, Mount, Mythic Keystone, Mythic Raid, Pet, Playable Class/Race/Spec, Power Type, Profession, PvP Season/Tier, Quest, Realm, Region, Reputations, Spell, Talent, Tech Talent, Title, Toy, WoW Token, and more).

---

## 13. Profile APIs — Endpoint Reference

Host: `{region}.api.blizzard.com`
Namespace: `profile-{region}` for all endpoints.

See full listing: https://community.developer.battle.net/documentation/world-of-warcraft/profile-apis

### Account Profile API
| Endpoint | Path |
|----------|------|
| Account Profile Summary | `GET /profile/user/wow` |
| Protected Character Profile Summary | `GET /profile/user/wow/protected-character/{realmId}-{characterId}` |
| Account Collections Index | `GET /profile/user/wow/collections` |
| Account Decor Collection | `GET /profile/user/wow/collections/decor` |
| Account Heirlooms Collection | `GET /profile/user/wow/collections/heirlooms` |
| Account Mounts Collection | `GET /profile/user/wow/collections/mounts` |
| Account Pets Collection | `GET /profile/user/wow/collections/pets` |
| Account Toys Collection | `GET /profile/user/wow/collections/toys` |
| Account Transmog Collection | `GET /profile/user/wow/collections/transmogs` |

### Character Achievements API
| Endpoint | Path |
|----------|------|
| Character Achievements Summary | `GET /profile/wow/character/{realmSlug}/{characterName}/achievements` |
| Character Achievement Statistics | `GET /profile/wow/character/{realmSlug}/{characterName}/achievements/statistics` |

### Character Media API
| Endpoint | Path |
|----------|------|
| Character Media Summary | `GET /profile/wow/character/{realmSlug}/{characterName}/character-media` |

> The full Profile API listing includes: Character Appearance, Collections, Encounters, Equipment, Hunter Pets, Mythic Keystone, Professions, Profile, PvP, Quests, Reputations, Soulbinds, Specializations, Statistics, Titles, and Guild endpoints.

---

## 14. Addon Scope Note

For this monorepo:
- **Addon runtime** (`ProfessionUI`, `BankMatsViewer`) uses in-game Lua APIs only. No Battle.net web API calls happen in-game.
- **External tooling** (companion scripts, data importers, cache builders) is the correct home for Battle.net web API calls.
- **Never** embed `client_id` or `client_secret` in addon Lua files.
