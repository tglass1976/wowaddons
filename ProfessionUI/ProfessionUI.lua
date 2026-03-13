local addonName, addon = ...

addon.name = addonName

addon.constants = {
    FRAME_WIDTH = 760,
    FRAME_HEIGHT = 560,
    EXPANSION_TAB_HEIGHT = 26,
    RECIPE_ROW_HEIGHT = 34,
    ARCH_ROW_HEIGHT = 64,
}

addon.theme = {
    panelBg = { 0.08, 0.08, 0.08, 0.70 },
    panelBorder = { 0.42, 0.42, 0.42, 0.95 },
    textMuted = { 0.74, 0.74, 0.74 },
    textBright = { 0.95, 0.95, 0.95 },
    textLearned = { 1.0, 0.82, 0.0 },
}

addon.expansionOrder = {
    "Midnight",
    "Khaz Algar",
    "Dragon Isles",
    "Shadowlands",
    "Battle for Azeroth",
    "Legion",
    "Draenor",
    "Pandaria",
    "Cataclysm",
    "Northrend",
    "Outland",
    "Classic",
}

addon.expansionAliases = {
    ["Midnight"] = "Midnight",
    ["The War Within"] = "Khaz Algar",
    ["Khaz Algar"] = "Khaz Algar",
    ["Dragonflight"] = "Dragon Isles",
    ["Dragon Isles"] = "Dragon Isles",
    ["Shadowlands"] = "Shadowlands",
    ["Battle for Azeroth"] = "Battle for Azeroth",
    ["Kul Tiran"] = "Battle for Azeroth",
    ["Zandalari"] = "Battle for Azeroth",
    ["Legion"] = "Legion",
    ["Broken Isles"] = "Legion",
    ["Warlords"] = "Draenor",
    ["Warlords of Draenor"] = "Draenor",
    ["Draenor"] = "Draenor",
    ["Mists of Pandaria"] = "Pandaria",
    ["Pandaria"] = "Pandaria",
    ["Cataclysm"] = "Cataclysm",
    ["Wrath"] = "Northrend",
    ["Wrath of the Lich King"] = "Northrend",
    ["Northrend"] = "Northrend",
    ["The Burning Crusade"] = "Outland",
    ["Outland"] = "Outland",
    ["Classic"] = "Classic",
}

addon.state = {
    professions = {},
    selectedProfession = 1,
    selectedExpansion = addon.expansionOrder[1],
    expansionData = {},
    currentRecipes = {},
    professionStateCache = {},
    collapsedCategories = {},
    archRaces = {},
}

addon.defaults = {
    version = 1,
    window = {
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 0,
    },
    ui = {
        selectedProfession = 1,
        selectedExpansionByProfession = {},
    },
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function ValidateWindowDB(db)
    local window = db.window
    if type(window.point) ~= "string" then
        window.point = addon.defaults.window.point
    end
    if type(window.relPoint) ~= "string" then
        window.relPoint = addon.defaults.window.relPoint
    end
    if type(window.x) ~= "number" then
        window.x = addon.defaults.window.x
    end
    if type(window.y) ~= "number" then
        window.y = addon.defaults.window.y
    end
end

local function ValidateUIDB(db)
    local ui = db.ui
    if type(ui.selectedProfession) ~= "number" or ui.selectedProfession < 1 then
        ui.selectedProfession = addon.defaults.ui.selectedProfession
    end
    if type(ui.selectedExpansionByProfession) ~= "table" then
        ui.selectedExpansionByProfession = {}
    end
end

function addon.GetDB()
    if type(ProfessionUIDB) ~= "table" then
        ProfessionUIDB = {}
    end

    CopyDefaults(ProfessionUIDB, addon.defaults)
    ValidateWindowDB(ProfessionUIDB)
    ValidateUIDB(ProfessionUIDB)
    ProfessionUIDB.version = addon.defaults.version

    return ProfessionUIDB
end

function addon.GetStoredSelectedProfession()
    return addon.GetDB().ui.selectedProfession
end

function addon.SetStoredSelectedProfession(index)
    addon.GetDB().ui.selectedProfession = math.max(1, tonumber(index) or 1)
end

function addon.GetStoredSelectedExpansion(cacheKey)
    if not cacheKey or cacheKey == "" then
        return nil
    end

    return addon.GetDB().ui.selectedExpansionByProfession[cacheKey]
end

function addon.SetStoredSelectedExpansion(cacheKey, expansion)
    if not cacheKey or cacheKey == "" then
        return
    end

    addon.GetDB().ui.selectedExpansionByProfession[cacheKey] = expansion
end

function addon.RestoreWindowPosition(frame)
    local db = addon.GetDB()
    frame:ClearAllPoints()
    frame:SetPoint(db.window.point, UIParent, db.window.relPoint, db.window.x, db.window.y)
end

function addon.SaveWindowPosition(frame)
    local point, _, relPoint, x, y = frame:GetPoint()
    if not point then
        return
    end

    local db = addon.GetDB()
    db.window.point = point
    db.window.relPoint = relPoint
    db.window.x = x
    db.window.y = y
end

addon.pools = {
    professionTabs = {},
    expansionTabs = {},
    recipeRows = {},
    archRaceRows = {},
}
