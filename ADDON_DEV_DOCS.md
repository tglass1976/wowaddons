# WoW Addon Lua/API Docs (Runtime-Focused)

This repository targets in-game WoW addon development.
Use these sources for addon runtime APIs, events, frames, and UI behavior.

## Primary References

1. Warcraft Wiki API Portal
- https://warcraft.wiki.gg/wiki/World_of_Warcraft_API
- Best quick lookup for API functions, events, payloads, and examples.

2. WoW UI Source (FrameXML/SharedXML)
- https://github.com/Gethe/wow-ui-source
- Ground truth for implementation details and behavior.

3. Blizzard UI & Macro Forum
- https://us.forums.blizzard.com/en/wow/c/ui-and-macro/123
- Useful for current-client breakages and edge-case behavior.

4. AddOn Studio API Index (secondary)
- https://addonstudio.org/mw_/index.php?title=WoW:World_of_Warcraft_API
- Helpful quick reference, but verify against Warcraft Wiki and UI source.

## What To Use In Addons

- In-game Lua APIs only (for example: `C_Container`, `GetItemInfo`, events, frame APIs).
- SavedVariables for persistence.
- Slash commands, frame scripts, and event-driven updates.

## What Not To Use In Addons

- Battle.net OAuth token flows.
- Blizzard web API calls from addon runtime.
- Embedded secrets (client IDs/secrets) in addon files.

## Fast Debug Workflow

1. Reproduce in-game with `/reload` and a small slash command.
2. Check event flow with temporary `print` traces.
3. Confirm function behavior in Warcraft Wiki.
4. Validate edge behavior in Gethe UI source.
5. Keep fixes small and test after each change.

## Useful In-Game Checks

- Open AddOn list and confirm addon is enabled and not out-of-date.
- Use `/console scriptErrors 1` to surface Lua errors.
- Use `/reload` after edits.
- Trigger bank-related behavior by opening/closing bank to fire events.

## Repo Notes

- `BankMatsViewer` and `ProfessionUI` are separate addon projects.
- Keep changes scoped to one addon unless a cross-addon change is intentional.

## Release Packaging (One Command)

Use the repo script to build clean release zips for both addons:

```powershell
Set-Location c:\projects\wowaddons
.\package-release.ps1
```

Optional flags:

```powershell
# Put zips in a custom folder
.\package-release.ps1 -OutputDir dist

# Add version suffix to zip names
.\package-release.ps1 -Version 1.2.3

# Keep README.md files in zips
.\package-release.ps1 -IncludeReadme

# Show validation details while packaging
.\package-release.ps1 -VerboseValidation

# Skip zip validation checks (not recommended for release)
.\package-release.ps1 -SkipValidation
```

Default behavior:

- Builds one zip per addon: `BankMatsViewer.zip` and `ProfessionUI.zip`.
- Excludes markdown/dev docs from addon folders by default.
- Keeps addon folder root in each zip so they can be dropped directly into `Interface\AddOns`.
- Validates each zip before success: addon root present, at least one `.toc`, no markdown except optional `README.md`.
