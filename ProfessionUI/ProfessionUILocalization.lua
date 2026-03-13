local _, addon = ...

addon.locale = {
    FRAME_TITLE = "Profession Atlas",
    NO_PROFESSIONS = "No professions found.",
    NO_RECIPES = "No recipes found for this expansion.",
    EXPANSION_NOT_LEARNED = "Expansion skill is not learned yet.",
    RECIPES_LOAD_ERROR = "Unable to load recipes: %s",
    RECIPES_SUMMARY = "Recipes %d | Learned %d | Unlearned %d | Skill-locked %d | Unavailable %d",
    STATUS_LEARNED = "Learned",
    STATUS_UNLEARNED = "Unlearned",
    STATUS_SKILL_LOCKED = "Skill locked",
    STATUS_UNAVAILABLE = "Unavailable",
    STATUS_READY = "Ready",
    STATUS_UNKNOWN = "Unknown",
    BUTTON_CRAFT = "Craft",
    BUTTON_LOCKED = "Locked",
    BUTTON_LOAD = "Reload All",
    BUTTON_REFRESH = "Refresh",
    LABEL_EXPANSION = "Expansion: %s",
    LABEL_SKILL = "Skill: %d / %d",
    LABEL_SKILL_NOT_LEARNED = "Skill: Not learned",
    LABEL_RECIPES_HINT = "Recipes load automatically — select an expansion tab to view.",
    LABEL_DISABLED_REASON = "Reason: %s",
    LABEL_UNLOCKED_AT = "Unlocks at skill %d",
    ADDON_LOADED = "|cff00ccffProfessionUI|r loaded. Type |cffffd700/profui|r to open.",
    ERR_PREFIX = "|cffff4444ProfessionUI:|r %s",
    ERR_CRAFT_API = "Craft API is unavailable.",
    ERR_CRAFT = "|cffff4444ProfessionUI craft error:|r %s",
    ERR_MISSING_TRADE_SKILL = "Missing trade skill API or skill line.",
    ERR_COMBAT_LOCKDOWN = "Cannot open trade skill while in combat.",
    ERR_RECIPES_UNAVAILABLE = "Recipe APIs unavailable on this client.",
    ERR_NO_RECIPE_DATA = "No recipe data returned for this expansion.",
    DIAG_HEADER = "|cff00ccffProfessionUI|r diagnostics:",
    ARCH_TAB_LABEL = "Artifact Races",
    ARCH_SOLVE = "Solve",
    ARCH_COMPLETED = "%d solved",
    ARCH_FRAGMENTS = "%d / %d fragments",
    ARCH_NO_ARTIFACT = "No active artifact",
    ARCH_NO_DATA = "Archaeology data is unavailable on this client.",
    ARCH_SUMMARY = "%d races  \xC2\xB7  %d solvable",
}

function addon.GetString(key, ...)
    local value = addon.locale[key] or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end

    return value
end