local _, addon = ...

-- Augments Blizzard's default profession UI with a side expansion tab list,
-- so expansion switching does not require drilling through a dropdown.

local EXPANSION_ORDER = addon.expansionOrder or {}

local expansionOrderIndex = {}
for i, name in ipairs(EXPANSION_ORDER) do
    expansionOrderIndex[name] = i
end

local ui = {
    panel = nil,
    title = nil,
    subtitle = nil,
    archaeologyNotice = nil,
    professionButtons = {},
    professionSectionHeaders = {},
    joinSeam = nil,
    topSeam = nil,
    bottomSeam = nil,
    tabs = {},
    tabScroll = nil,
    tabContent = nil,
    hooksInstalled = false,
    archaeologyHooksInstalled = false,
    hideUntilNextTradeSkillOpen = false,
    pinAutoSwitchRetryKey = nil,
    pinAutoSwitchRetryCount = 0,
}

local refreshSideTabs

local PIN_ICON_LOCKED = "Interface\\Buttons\\UI-CheckBox-Check"
local PIN_ICON_UNLOCKED = "Interface\\Buttons\\UI-CheckBox-Up"
local ARCHAEOLOGY_SKILL_LINE_ID = 794
local DEFAULT_PROFESSION_ICON = 134400
local DEFAULT_PANEL_WIDTH = 238
local ARCHAEOLOGY_PANEL_WIDTH = 468
local TAB_ROW_HEIGHT = 30
local PROF_SWITCHER_BUTTON_SIZE = 40
local PROF_SWITCHER_ICON_SIZE = 34
local PROF_SWITCHER_BUTTON_STRIDE = 44
local ATT_TAB_SAFE_GUTTER = 56

local THEME = {
    panelBg = { 0.08, 0.08, 0.08, 0.97 },
    panelBorder = { 0.42, 0.42, 0.42, 0.95 },
    headerBg = { 0.13, 0.13, 0.13, 0.96 },
    seamStrong = { 0.44, 0.44, 0.44, 0.72 },
    seamSoft = { 0.44, 0.44, 0.44, 0.42 },
    switcherBg = { 0.11, 0.11, 0.11, 0.93 },
    switcherBorder = { 0.38, 0.38, 0.38, 0.95 },
    switcherActiveBg = { 0.17, 0.15, 0.12, 0.97 },
    switcherActiveBorder = { 0.76, 0.62, 0.26, 0.95 },
    activeGlow = { 1.00, 0.88, 0.45, 0.80 },
    rowOddBg = { 0.11, 0.11, 0.11, 0.90 },
    rowEvenBg = { 0.13, 0.13, 0.13, 0.90 },
    rowHoverBg = { 0.18, 0.17, 0.15, 0.95 },
    rowBorder = { 0.36, 0.36, 0.36, 0.95 },
    rowSelectedBg = { 0.22, 0.19, 0.14, 0.97 },
    rowSelectedBorder = { 0.76, 0.62, 0.26, 0.95 },
    rowSelectedAccent = { 0.93, 0.76, 0.28, 0.95 },
    rowSelectedText = { 1.00, 0.93, 0.56 },
    rowText = { 0.94, 0.94, 0.94 },
    rowSubText = { 0.84, 0.84, 0.84 },
    pinBg = { 0.10, 0.10, 0.10, 0.96 },
    pinBorder = { 0.42, 0.42, 0.42, 0.60 },
    pinPinnedBg = { 0.19, 0.16, 0.11, 0.98 },
    pinPinnedBorder = { 0.82, 0.66, 0.25, 0.82 },
    pinIcon = { 0.90, 0.90, 0.90, 0.98 },
    pinPinnedIcon = { 1.00, 0.94, 0.62, 1.00 },
}

local function getExpansionSort(expansionName)
    return expansionOrderIndex[expansionName] or 999
end

local function isSupportedExpansionName(expansionName)
    return type(expansionName) == "string" and expansionOrderIndex[expansionName] ~= nil
end

local function getDisplayExpansionName(expansionName)
    if addon.GetExpansionDisplayName then
        return addon.GetExpansionDisplayName(expansionName)
    end
    return expansionName
end

local function escapeLuaPattern(text)
    return (text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function resolveExpansionName(info)
    if type(info) ~= "table" then
        return nil
    end

    if info.expansionName then
        local normalized = addon.NormalizeExpansionName(info.expansionName)
        if normalized then
            return normalized
        end
    end

    local candidates = { info.professionName, info.skillLineName }
    for _, raw in ipairs(candidates) do
        if type(raw) == "string" and raw ~= "" then
            local normalized = addon.NormalizeExpansionName(raw)
            if normalized then
                return normalized
            end

            -- Common format: "Cataclysm Leatherworking". Strip profession suffix.
            if type(info.parentProfessionName) == "string" and info.parentProfessionName ~= "" then
                local suffixPattern = "%s+" .. escapeLuaPattern(info.parentProfessionName) .. "$"
                local withoutSuffix = raw:gsub(suffixPattern, "")
                normalized = addon.NormalizeExpansionName(withoutSuffix)
                if normalized then
                    return normalized
                end
            end

            -- Alias token search for cases where the full line name includes extra words.
            local lowerRaw = string.lower(raw)
            for alias, canonical in pairs(addon.expansionAliases or {}) do
                if string.find(lowerRaw, string.lower(alias), 1, true) then
                    return canonical
                end
            end
        end
    end

    return nil
end

local function getActiveProfessionContext()
    local context = {
        professionID = nil,
        currentSkillLineID = nil,
        professionName = nil,
    }

    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if type(baseInfo) == "table" then
            if type(baseInfo.parentProfessionID) == "number" then
                context.professionID = baseInfo.parentProfessionID
            elseif type(baseInfo.professionID) == "number" then
                context.professionID = baseInfo.professionID
            end
            if type(baseInfo.skillLineID) == "number" then
                context.currentSkillLineID = baseInfo.skillLineID
            end
            if type(baseInfo.parentProfessionName) == "string" and baseInfo.parentProfessionName ~= "" then
                context.professionName = baseInfo.parentProfessionName
            elseif type(baseInfo.professionName) == "string" and baseInfo.professionName ~= "" then
                context.professionName = baseInfo.professionName
            end
        end
    end

    if not context.professionID and C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfo then
        local childInfo = C_TradeSkillUI.GetChildProfessionInfo()
        if type(childInfo) == "table" then
            if type(childInfo.parentProfessionID) == "number" then
                context.professionID = childInfo.parentProfessionID
            elseif type(childInfo.professionID) == "number" then
                context.professionID = childInfo.professionID
            end
            if type(childInfo.skillLineID) == "number" then
                context.currentSkillLineID = childInfo.skillLineID
            end
            if not context.professionName then
                if type(childInfo.parentProfessionName) == "string" and childInfo.parentProfessionName ~= "" then
                    context.professionName = childInfo.parentProfessionName
                elseif type(childInfo.professionName) == "string" and childInfo.professionName ~= "" then
                    context.professionName = childInfo.professionName
                end
            end
        end
    end

    if _G.Professions and type(_G.Professions.GetProfessionInfo) == "function" then
        local pInfo = _G.Professions.GetProfessionInfo()
        if type(pInfo) == "table" then
            if not context.professionID then
                if type(pInfo.parentProfessionID) == "number" then
                    context.professionID = pInfo.parentProfessionID
                elseif type(pInfo.professionID) == "number" then
                    context.professionID = pInfo.professionID
                end
            end
            if not context.currentSkillLineID and type(pInfo.skillLineID) == "number" then
                context.currentSkillLineID = pInfo.skillLineID
            end
            if not context.professionName then
                if type(pInfo.parentProfessionName) == "string" and pInfo.parentProfessionName ~= "" then
                    context.professionName = pInfo.parentProfessionName
                elseif type(pInfo.professionName) == "string" and pInfo.professionName ~= "" then
                    context.professionName = pInfo.professionName
                elseif type(pInfo.skillLineName) == "string" and pInfo.skillLineName ~= "" then
                    context.professionName = pInfo.skillLineName
                end
            end
        end
    end

    if not context.currentSkillLineID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionChildSkillLineID then
        local childSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
        if type(childSkillLineID) == "number" then
            context.currentSkillLineID = childSkillLineID
        end
    end

    if context.currentSkillLineID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local activeInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(context.currentSkillLineID)
        if type(activeInfo) == "table" then
            if type(activeInfo.parentProfessionID) == "number" then
                context.professionID = activeInfo.parentProfessionID
            elseif type(activeInfo.professionID) == "number" then
                context.professionID = activeInfo.professionID
            end

            if type(activeInfo.parentProfessionName) == "string" and activeInfo.parentProfessionName ~= "" then
                context.professionName = activeInfo.parentProfessionName
            elseif type(activeInfo.professionName) == "string" and activeInfo.professionName ~= "" then
                context.professionName = activeInfo.professionName
            end
        end
    end

    return context
end

local function lineBelongsToActiveProfession(info, activeContext)
    if type(info) ~= "table" or type(activeContext) ~= "table" then
        return false
    end

    local activeProfessionID = activeContext.professionID
    if type(activeProfessionID) == "number" then
        local lineProfessionID = info.parentProfessionID or info.professionID
        if type(lineProfessionID) == "number" and lineProfessionID == activeProfessionID then
            return true
        end
    end

    local activeName = activeContext.professionName
    if type(activeName) == "string" and activeName ~= "" then
        local lowerActiveName = string.lower(activeName)
        local candidates = {
            info.parentProfessionName,
            info.professionName,
            info.skillLineName,
        }
        for _, candidate in ipairs(candidates) do
            if type(candidate) == "string" and candidate ~= "" then
                local lowerCandidate = string.lower(candidate)
                if lowerCandidate == lowerActiveName then
                    return true
                end
                if string.find(lowerCandidate, lowerActiveName, 1, true) then
                    return true
                end
                if string.find(lowerActiveName, lowerCandidate, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

local function buildFallbackEntries(activeContext)
    if type(addon.BuildExpansionDataForProfession) ~= "function" then
        return {}
    end

    local prof = {
        name = activeContext.professionName,
        skillLine = activeContext.professionID or activeContext.currentSkillLineID,
    }

    local expansionData = addon.BuildExpansionDataForProfession(prof)
    if type(expansionData) ~= "table" then
        return {}
    end

    local entries = {}
    for expansionName, data in pairs(expansionData) do
        if isSupportedExpansionName(expansionName) and type(data) == "table" and type(data.skillLineID) == "number" then
            entries[#entries + 1] = {
                skillLineID = data.skillLineID,
                expansionName = expansionName,
                rank = tonumber(data.rank) or 0,
                maxRank = tonumber(data.maxRank) or 0,
                isChildSkillLine = true,
                isFallback = true,
                professionID = activeContext.professionID,
            }
        end
    end

    table.sort(entries, function(a, b)
        local as = getExpansionSort(a.expansionName)
        local bs = getExpansionSort(b.expansionName)
        if as ~= bs then
            return as < bs
        end
        return a.expansionName < b.expansionName
    end)

    return entries
end

local function getPinStorage()
    local db = addon.GetDB and addon.GetDB() or nil
    if type(db) ~= "table" then
        return nil
    end
    db.ui = db.ui or {}
    db.ui.pinnedExpansionByProfessionID = db.ui.pinnedExpansionByProfessionID or {}
    return db.ui
end

local function getLegacyPinnedExpansion(uiStorage)
    local legacy = uiStorage and uiStorage.pinnedExpansionByProfessionID or nil
    if type(legacy) ~= "table" then
        return nil
    end

    for _, expansionName in ipairs(EXPANSION_ORDER) do
        for _, pinned in pairs(legacy) do
            if pinned == expansionName then
                return expansionName
            end
        end
    end

    for _, pinned in pairs(legacy) do
        if isSupportedExpansionName(pinned) then
            return pinned
        end
    end

    return nil
end

local function getSelectedExpansionStorage()
    local db = addon.GetDB and addon.GetDB() or nil
    if type(db) ~= "table" then
        return nil
    end
    db.ui = db.ui or {}
    return db.ui
end

local function getLastSelectedExpansion()
    local uiStorage = getSelectedExpansionStorage()
    if not uiStorage then
        return nil
    end
    return uiStorage.lastSelectedExpansion
end

local function setLastSelectedExpansion(expansionName)
    local uiStorage = getSelectedExpansionStorage()
    if not uiStorage or type(expansionName) ~= "string" or expansionName == "" then
        return
    end
    uiStorage.lastSelectedExpansion = expansionName
end

local function getPinnedExpansion()
    local storage = getPinStorage()
    if not storage then
        return nil
    end

    if isSupportedExpansionName(storage.globalPinnedExpansion) then
        return storage.globalPinnedExpansion
    end

    local migrated = getLegacyPinnedExpansion(storage)
    if migrated then
        storage.globalPinnedExpansion = migrated
        return migrated
    end

    return nil
end

local function setPinnedExpansion(expansionName)
    local storage = getPinStorage()
    if not storage or not isSupportedExpansionName(expansionName) then
        return
    end

    storage.globalPinnedExpansion = expansionName

    local legacy = storage.pinnedExpansionByProfessionID
    if type(legacy) == "table" then
        for key in pairs(legacy) do
            legacy[key] = nil
        end
    end
end

local function clearPinnedExpansion()
    local storage = getPinStorage()
    if not storage then
        return
    end

    storage.globalPinnedExpansion = nil
end

local function clearAllPinnedExpansions()
    local storage = getPinStorage()
    if type(storage) ~= "table" then
        return 0
    end

    local removed = 0

    if storage.globalPinnedExpansion ~= nil then
        storage.globalPinnedExpansion = nil
        removed = removed + 1
    end

    local legacy = storage.pinnedExpansionByProfessionID
    if type(legacy) == "table" then
        for key in pairs(legacy) do
            legacy[key] = nil
            removed = removed + 1
        end
    end

    return removed
end

local function getExpansionEntriesForCurrentProfession()
    local entries = {}
    local activeContext = getActiveProfessionContext()
    if not activeContext.professionID and not activeContext.professionName then
        return entries
    end

    local byExpansion = {}

    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local lines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
        if type(lines) == "table" then
            for _, skillLineID in ipairs(lines) do
                if type(skillLineID) == "number" then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
                    if type(info) == "table" and lineBelongsToActiveProfession(info, activeContext) then
                        local expansionName = resolveExpansionName(info)
                        if expansionName and isSupportedExpansionName(expansionName) then
                            local rank = tonumber(info.skillLevel) or 0
                            local maxRank = tonumber(info.maxSkillLevel) or 0

                            local prev = byExpansion[expansionName]
                            if not prev or rank > (prev.rank or 0) then
                                byExpansion[expansionName] = {
                                    skillLineID = skillLineID,
                                    expansionName = expansionName,
                                    rank = rank,
                                    maxRank = maxRank,
                                    isChildSkillLine = info.parentProfessionID ~= nil,
                                    professionID = info.parentProfessionID or info.professionID or activeContext.professionID,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    -- Merge fallback entries so unlearned expansions still appear in the side list.
    local fallbackEntries = buildFallbackEntries(activeContext)
    for _, fallback in ipairs(fallbackEntries) do
        local existing = byExpansion[fallback.expansionName]
        if not existing then
            byExpansion[fallback.expansionName] = fallback
        elseif (type(existing.skillLineID) ~= "number") and type(fallback.skillLineID) == "number" then
            existing.skillLineID = fallback.skillLineID
            existing.isChildSkillLine = fallback.isChildSkillLine
            existing.isFallback = true
            if type(existing.professionID) ~= "number" then
                existing.professionID = fallback.professionID
            end
        end
    end

    -- Ensure a consistent, full expansion roster for every profession.
    for _, expansionName in ipairs(EXPANSION_ORDER) do
        if not byExpansion[expansionName] then
            byExpansion[expansionName] = {
                skillLineID = nil,
                expansionName = expansionName,
                rank = 0,
                maxRank = 0,
                isChildSkillLine = true,
                isPlaceholder = true,
                professionID = activeContext.professionID,
            }
        end
    end

    for _, entry in pairs(byExpansion) do
        entries[#entries + 1] = entry
    end

    table.sort(entries, function(a, b)
        local as = getExpansionSort(a.expansionName)
        local bs = getExpansionSort(b.expansionName)
        if as ~= bs then
            return as < bs
        end
        return a.expansionName < b.expansionName
    end)

    return entries
end

local function resolveSkillLineForExpansion(expansionName, preferredProfessionID)
    if type(expansionName) ~= "string" or expansionName == "" then
        return nil, nil
    end

    local activeContext = getActiveProfessionContext()
    if not activeContext.professionID and not activeContext.professionName then
        return nil, nil
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local lines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
        if type(lines) == "table" then
            for _, lineSkillLineID in ipairs(lines) do
                if type(lineSkillLineID) == "number" then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineSkillLineID)
                    if type(info) == "table" then
                        local belongsToPreferred = false
                        if type(preferredProfessionID) == "number" then
                            local lineProfessionID = info.parentProfessionID or info.professionID
                            belongsToPreferred = (type(lineProfessionID) == "number" and lineProfessionID == preferredProfessionID)
                        end
                        if (belongsToPreferred or lineBelongsToActiveProfession(info, activeContext)) then
                        local resolvedExpansion = resolveExpansionName(info)
                        if resolvedExpansion == expansionName then
                            return lineSkillLineID, info.parentProfessionID ~= nil
                        end
                        end
                    end
                end
            end
        end
    end

    if type(addon.BuildExpansionDataForProfession) == "function" then
        local prof = {
            name = activeContext.professionName,
            skillLine = activeContext.professionID or activeContext.currentSkillLineID,
        }
        local expansionData = addon.BuildExpansionDataForProfession(prof)
        local info = type(expansionData) == "table" and expansionData[expansionName] or nil
        if type(info) == "table" and type(info.skillLineID) == "number" then
            return info.skillLineID, true
        end
    end

    return nil, nil
end

local function printExpansionTrainingHint(expansionName)
    if type(expansionName) ~= "string" or expansionName == "" then
        return
    end

    print("|cffff9933ProfessionUI:|r " .. tostring(getDisplayExpansionName(expansionName)) .. " isn't unlocked for this profession yet. Train this expansion first.")
end

local function isArchaeologyContext(activeContext)
    if type(activeContext) ~= "table" then
        return false
    end

    if activeContext.professionID == ARCHAEOLOGY_SKILL_LINE_ID then
        return true
    end

    if activeContext.currentSkillLineID == ARCHAEOLOGY_SKILL_LINE_ID then
        return true
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID and type(activeContext.currentSkillLineID) == "number" then
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(activeContext.currentSkillLineID)
        if type(info) == "table" then
            if info.professionID == ARCHAEOLOGY_SKILL_LINE_ID or info.parentProfessionID == ARCHAEOLOGY_SKILL_LINE_ID then
                return true
            end
        end
    end

    return false
end

local function getArchaeologyRaceEntries()
    if type(addon.LoadArchaeologyData) ~= "function" then
        return {}
    end

    local races = addon.LoadArchaeologyData() or {}
    local entries = {}

    for _, race in ipairs(races) do
        local progressText = ""
        local completedArtifacts = tonumber(race.completedArtifacts) or 0
        local totalArtifacts = tonumber(race.totalArtifacts)

        if completedArtifacts < 0 then
            completedArtifacts = 0
        end

        if totalArtifacts and totalArtifacts > 0 then
            if completedArtifacts > totalArtifacts then
                completedArtifacts = totalArtifacts
            end
            progressText = string.format("%d/%d", completedArtifacts, totalArtifacts)
        else
            progressText = string.format("%d/?", completedArtifacts)
        end

        entries[#entries + 1] = {
            expansionName = race.raceName or "Unknown Race",
            rankLabel = progressText,
            isArchaeologyRace = true,
            raceIndex = race.raceIndex,
            canSolve = race.canSolve == true,
        }
    end

    table.sort(entries, function(a, b)
        if a.canSolve ~= b.canSolve then
            return a.canSolve
        end
        return (a.expansionName or "") < (b.expansionName or "")
    end)

    return entries
end

local function openArchaeologyCompletedForRace(raceIndex)
    if type(raceIndex) ~= "number" then
        return false
    end

    local selected = false
    if type(_G.SetSelectedArtifactRace) == "function" then
        local ok = pcall(_G.SetSelectedArtifactRace, raceIndex)
        selected = ok or selected
    elseif C_Archaeology and type(C_Archaeology.SetSelectedArtifactRace) == "function" then
        local ok = pcall(C_Archaeology.SetSelectedArtifactRace, raceIndex)
        selected = ok or selected
    end

    local switched = false
    local switchers = {
        _G.ArchaeologyFrame_ShowArtifact,
        _G.ArchaeologyFrame_ShowArtifacts,
        _G.ArchaeologyFrame_ShowCompletedArtifacts,
    }
    for _, fn in ipairs(switchers) do
        if type(fn) == "function" then
            local ok = pcall(fn)
            if ok then
                switched = true
                break
            end
        end
    end

    local buttonCandidates = {
        "ArchaeologyFrameArtifactPageButton",
        "ArchaeologyFrameArtifactsButton",
        "ArchaeologyFrameCompletedArtifactsButton",
    }
    for _, buttonName in ipairs(buttonCandidates) do
        local btn = _G[buttonName]
        if btn and type(btn.Click) == "function" and btn.IsShown and btn:IsShown() then
            local ok = pcall(btn.Click, btn)
            if ok then
                switched = true
                break
            end
        end
    end

    if type(_G.SetSelectedArtifactRace) == "function" then
        pcall(_G.SetSelectedArtifactRace, raceIndex)
    elseif C_Archaeology and type(C_Archaeology.SetSelectedArtifactRace) == "function" then
        pcall(C_Archaeology.SetSelectedArtifactRace, raceIndex)
    end

    return selected or switched
end

local function switchProfessionSkillLine(skillLineID, isChildSkillLine)
    if type(skillLineID) ~= "number" then
        return false
    end

    if isChildSkillLine and C_TradeSkillUI and C_TradeSkillUI.SetProfessionChildSkillLineID then
        local ok = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, skillLineID)
        if ok then
            local activeChild = C_TradeSkillUI.GetProfessionChildSkillLineID and C_TradeSkillUI.GetProfessionChildSkillLineID() or nil
            if type(activeChild) == "number" and activeChild == skillLineID then
                local pf = _G.ProfessionsFrame
                if pf and type(pf.SetProfessionInfo) == "function" and _G.Professions and type(_G.Professions.GetProfessionInfo) == "function" then
                    local professionInfo = _G.Professions.GetProfessionInfo()
                    local useLastSkillLine = false
                    pcall(pf.SetProfessionInfo, pf, professionInfo, useLastSkillLine)
                end
                return true
            end
        end
    end

    if addon.OpenTradeSkillForLine then
        local opened = addon.OpenTradeSkillForLine(skillLineID)
        return opened == true
    end

    return false
end

local function openArchaeologyInProfessionsUI()
    if not (GetProfessions and GetProfessionInfo) then
        return false
    end

    local _, _, archaeology = GetProfessions()
    local archaeologySkillLineID = ARCHAEOLOGY_SKILL_LINE_ID
    if archaeology then
        local _, _, _, _, _, _, skillLine = GetProfessionInfo(archaeology)
        if type(skillLine) == "number" then
            archaeologySkillLineID = skillLine
        end
    end

    local opened = false
    if addon.OpenTradeSkillForLine then
        opened = (addon.OpenTradeSkillForLine(archaeologySkillLineID) == true)
    end

    if not opened and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
        local ok, result = pcall(C_TradeSkillUI.OpenTradeSkill, archaeologySkillLineID)
        opened = ok and (result == true)
    end

    if not opened then
        return false
    end

    local professionsShown = (_G.ProfessionsFrame and _G.ProfessionsFrame.IsShown and _G.ProfessionsFrame:IsShown()) or false
    if not professionsShown then
        return false
    end

    if _G.ArchaeologyFrame and _G.ArchaeologyFrame.IsShown and _G.ArchaeologyFrame:IsShown() then
        _G.ArchaeologyFrame:Hide()
    end
    C_Timer.After(0, refreshSideTabs)

    return true
end

local function triggerArchaeologyRedirect(attempt)
    attempt = attempt or 1
    local redirected = openArchaeologyInProfessionsUI()
    if redirected then
        return
    end

    if attempt >= 8 then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            triggerArchaeologyRedirect(attempt + 1)
        end)
    end
end

local function installArchaeologyRedirect()
    if type(_G.ToggleArchaeology) == "function" and not ui.archaeologyTogglePatched then
        hooksecurefunc("ToggleArchaeology", function()
            triggerArchaeologyRedirect(1)
        end)
        ui.archaeologyTogglePatched = true
    end

    if _G.ArchaeologyFrame and not ui.archaeologyFrameHookInstalled then
        _G.ArchaeologyFrame:HookScript("OnShow", function(frame)
            local redirected = openArchaeologyInProfessionsUI()
            if not redirected then
                triggerArchaeologyRedirect(1)
            end

            if redirected and frame and frame.IsShown and frame:IsShown() then
                frame:Hide()
            end
        end)
        ui.archaeologyFrameHookInstalled = true
    end

    ui.archaeologyRedirectInstalled = ui.archaeologyTogglePatched or ui.archaeologyFrameHookInstalled
end

local function getProfessionSwitchEntries()
    local entries = {}

    if not (GetProfessions and GetProfessionInfo) then
        return entries
    end

    local rootSkillLineByProfessionID = {}
    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local lines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
        if type(lines) == "table" then
            for _, lineSkillLineID in ipairs(lines) do
                if type(lineSkillLineID) == "number" then
                    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineSkillLineID)
                    if type(info) == "table" and info.parentProfessionID == nil and type(info.professionID) == "number" then
                        rootSkillLineByProfessionID[info.professionID] = lineSkillLineID
                    end
                end
            end
        end
    end

    local seenByProfessionID = {}
    local function addEntry(profIndex, section)
        if not profIndex then
            return
        end

        local name, texture, _, _, _, _, professionID = GetProfessionInfo(profIndex)
        if type(professionID) ~= "number" or seenByProfessionID[professionID] then
            return
        end
        seenByProfessionID[professionID] = true

        local skillLineID = rootSkillLineByProfessionID[professionID] or professionID
        entries[#entries + 1] = {
            professionID = professionID,
            skillLineID = skillLineID,
            label = (type(name) == "string" and name ~= "") and name or tostring(professionID),
            section = section,
            icon = texture,
        }
    end

    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    addEntry(prof1, "Primary")
    addEntry(prof2, "Primary")
    addEntry(cooking, "Secondary")
    addEntry(fishing, "Secondary")
    addEntry(archaeology, "Archaeology")

    local sectionSort = {
        Primary = 1,
        Secondary = 2,
        Archaeology = 3,
    }

    table.sort(entries, function(a, b)
        local aSort = sectionSort[a.section] or 99
        local bSort = sectionSort[b.section] or 99
        if aSort ~= bSort then
            return aSort < bSort
        end
        return (a.label or "") < (b.label or "")
    end)

    return entries
end

local function acquireProfessionButton(index)
    local btn = ui.professionButtons[index]
    if btn then
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, ui.panel, "BackdropTemplate")
    btn:SetSize(PROF_SWITCHER_BUTTON_SIZE, PROF_SWITCHER_BUTTON_SIZE)
    btn:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(unpack(THEME.switcherBg))
    btn:SetBackdropBorderColor(unpack(THEME.switcherBorder))
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(PROF_SWITCHER_ICON_SIZE, PROF_SWITCHER_ICON_SIZE)
    btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.activeGlow = btn:CreateTexture(nil, "OVERLAY")
    btn.activeGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    btn.activeGlow:SetBlendMode("ADD")
    btn.activeGlow:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
    btn.activeGlow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
    btn.activeGlow:SetVertexColor(unpack(THEME.activeGlow))
    btn.activeGlow:SetAlpha(0.38)
    btn.activeGlow:Hide()
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetJustifyH("CENTER")
    btn.text:SetWordWrap(false)
    btn.text:Hide()

    btn:SetScript("OnClick", function(self)
        if not self.skillLineID then
            return
        end
        switchProfessionSkillLine(self.skillLineID, false)
        C_Timer.After(0, refreshSideTabs)
    end)

    btn:SetScript("OnEnter", function(self)
        if not self.fullLabel or self.fullLabel == "" then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.fullLabel, 1, 0.93, 0.45)
        if self.sectionLabel and self.sectionLabel ~= "" then
            GameTooltip:AddLine(self.sectionLabel, 0.80, 0.80, 0.80)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ui.professionButtons[index] = btn
    return btn
end

local function acquireProfessionSectionHeader(index)
    local header = ui.professionSectionHeaders[index]
    if header then
        header:Show()
        return header
    end

    header = ui.panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetJustifyH("LEFT")
    header:SetTextColor(0.88, 0.76, 0.42)
    ui.professionSectionHeaders[index] = header
    return header
end

local function refreshProfessionSwitcher(activeContext)
    local entries = getProfessionSwitchEntries()
    local rightPadding = 8
    local y = -48

    local buttonIndex = 0
    local cursor = 4
    local rowHeight = PROF_SWITCHER_BUTTON_STRIDE
    local panelWidth = (ui.panel and ui.panel.GetWidth and ui.panel:GetWidth()) or DEFAULT_PANEL_WIDTH
    local iconAreaWidth = math.max(0, panelWidth - ATT_TAB_SAFE_GUTTER - rightPadding)
    local columns = math.max(1, math.floor((iconAreaWidth + (PROF_SWITCHER_BUTTON_STRIDE - PROF_SWITCHER_BUTTON_SIZE)) / PROF_SWITCHER_BUTTON_STRIDE))

    for i = 1, #entries do
        local entry = entries[i]
        buttonIndex = buttonIndex + 1
        local btn = acquireProfessionButton(buttonIndex)
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        local rowStartIndex = row * columns + 1
        local rowEndIndex = math.min(#entries, rowStartIndex + columns - 1)
        local rowItemCount = rowEndIndex - rowStartIndex + 1
        local rowWidth = ((rowItemCount - 1) * PROF_SWITCHER_BUTTON_STRIDE) + PROF_SWITCHER_BUTTON_SIZE
        local rowStartX = panelWidth - rightPadding - rowWidth

        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", rowStartX + (col * PROF_SWITCHER_BUTTON_STRIDE), y - cursor - (row * rowHeight))

        btn.text:SetText("")
        btn.fullLabel = entry.label
        btn.sectionLabel = entry.section
        btn.skillLineID = entry.skillLineID
        btn.icon:SetTexture(entry.icon or DEFAULT_PROFESSION_ICON)

        local isActive = false
        if type(activeContext) == "table" then
            if type(activeContext.professionID) == "number" and activeContext.professionID == entry.professionID then
                isActive = true
            elseif type(activeContext.professionName) == "string" and string.lower(activeContext.professionName) == string.lower(entry.label or "") then
                isActive = true
            end
        end

        if isActive then
            btn:SetBackdropColor(unpack(THEME.switcherActiveBg))
            btn:SetBackdropBorderColor(unpack(THEME.switcherActiveBorder))
            btn.activeGlow:Show()
            btn.text:SetTextColor(unpack(THEME.rowSelectedText))
        else
            btn:SetBackdropColor(unpack(THEME.switcherBg))
            btn:SetBackdropBorderColor(unpack(THEME.switcherBorder))
            btn.activeGlow:Hide()
            btn.text:SetTextColor(unpack(THEME.rowText))
        end
    end

    local totalRows = math.max(1, math.ceil(#entries / columns))
    cursor = cursor + (totalRows * rowHeight) + 8

    for i = buttonIndex + 1, #ui.professionButtons do
        ui.professionButtons[i]:Hide()
    end

    for i = 1, #ui.professionSectionHeaders do
        ui.professionSectionHeaders[i]:Hide()
    end

    return cursor
end

local function acquireTab(index)
    local btn = ui.tabs[index]
    if btn then
        btn:Show()
        return btn
    end

    local parent = ui.tabContent or ui.panel
    btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(228, 26)
    btn:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(unpack(THEME.rowOddBg))
    btn:SetBackdropBorderColor(unpack(THEME.rowBorder))
    btn.leftAccent = btn:CreateTexture(nil, "ARTWORK")
    btn.leftAccent:SetColorTexture(unpack(THEME.rowSelectedAccent))
    btn.leftAccent:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
    btn.leftAccent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 3, 3)
    btn.leftAccent:SetWidth(2)
    btn.leftAccent:Hide()
    btn.pinBtn = CreateFrame("Button", nil, btn)
    btn.pinBtn:SetSize(18, 18)
    btn.pinBtn:SetPoint("LEFT", btn, "LEFT", 7, 0)
    btn.pinBtn.bg = btn.pinBtn:CreateTexture(nil, "BACKGROUND")
    btn.pinBtn.bg:SetAllPoints(btn.pinBtn)
    btn.pinBtn.bg:SetColorTexture(unpack(THEME.pinBg))
    btn.pinBtn.border = btn.pinBtn:CreateTexture(nil, "BORDER")
    btn.pinBtn.border:SetAllPoints(btn.pinBtn)
    btn.pinBtn.border:SetColorTexture(unpack(THEME.pinBorder))
    btn.pinBtn.icon = btn.pinBtn:CreateTexture(nil, "OVERLAY")
    btn.pinBtn.icon:SetAllPoints(btn.pinBtn)
    btn.pinBtn.icon:SetTexture(PIN_ICON_UNLOCKED)
    btn.pinBtn.icon:SetVertexColor(unpack(THEME.pinIcon))
    btn.pinBtn:SetScript("OnClick", function(pinButton)
        local owner = pinButton:GetParent()
        if not owner or not owner.expansionName then
            return
        end

        if owner.isPinned then
            clearPinnedExpansion()
            print("|cff33ff99ProfessionUI:|r Unpinned " .. tostring(getDisplayExpansionName(owner.expansionName)))
        else
            setPinnedExpansion(owner.expansionName)
            setLastSelectedExpansion(owner.expansionName)
            print("|cff33ff99ProfessionUI:|r Pinned " .. tostring(getDisplayExpansionName(owner.expansionName)) .. " for all professions")
        end
        C_Timer.After(0, refreshSideTabs)
    end)
    btn.pinBtn:SetScript("OnEnter", function(pinButton)
        local owner = pinButton:GetParent()
        local expansionName = owner and owner.expansionName or ""
        local isPinned = owner and owner.isPinned == true

        GameTooltip:SetOwner(pinButton, "ANCHOR_RIGHT")
        if isPinned then
            GameTooltip:SetText("Unpin expansion", 1, 0.93, 0.45)
        else
            GameTooltip:SetText("Pin expansion", 1, 0.93, 0.45)
        end
        if expansionName ~= "" then
            GameTooltip:AddLine(tostring(getDisplayExpansionName(expansionName)), 0.82, 0.82, 0.82)
        end
        GameTooltip:AddLine("Pinned expansion applies to all professions", 0.72, 0.72, 0.72, true)
        GameTooltip:Show()
    end)
    btn.pinBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.label:SetPoint("LEFT", btn, "LEFT", 32, 0)
    btn.label:SetPoint("RIGHT", btn, "RIGHT", -62, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    btn.rankText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.rankText:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    btn.rankText:SetJustifyH("RIGHT")
    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetColorTexture(1, 0.85, 0.2, 0.10)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetScript("OnClick", function(self)
        if self.isArchaeologyRace then
            if self.raceIndex then
                openArchaeologyCompletedForRace(self.raceIndex)
                C_Timer.After(0.05, refreshSideTabs)
            end
            return
        end

        if not self.skillLineID then
            local resolvedSkillLineID, resolvedIsChild = resolveSkillLineForExpansion(self.expansionName, self.baseProfessionID)
            if type(resolvedSkillLineID) == "number" then
                self.skillLineID = resolvedSkillLineID
                self.isChildSkillLine = resolvedIsChild == true
            end
        end

        if not self.skillLineID then
            printExpansionTrainingHint(self.expansionName)
            return
        end

        local warnedUntrained = false
        local expansionRank = tonumber(self.expansionRank) or 0
        local expansionMaxRank = tonumber(self.expansionMaxRank) or 0
        if self.expansionName and (expansionMaxRank == 0 or expansionRank == 0) then
            printExpansionTrainingHint(self.expansionName)
            warnedUntrained = true
        end

        if self.expansionName then
            setLastSelectedExpansion(self.expansionName)
        end

        local switched = switchProfessionSkillLine(self.skillLineID, self.isChildSkillLine == true)
        if not switched and not warnedUntrained then
            printExpansionTrainingHint(self.expansionName)
        end

        C_Timer.After(0, refreshSideTabs)
    end)

    btn:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self:SetBackdropColor(unpack(THEME.rowHoverBg))
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if self.isSelected then
            self:SetBackdropColor(unpack(THEME.rowSelectedBg))
        else
            if self.isEvenRow then
                self:SetBackdropColor(unpack(THEME.rowEvenBg))
            else
                self:SetBackdropColor(unpack(THEME.rowOddBg))
            end
        end
    end)

    ui.tabs[index] = btn
    return btn
end

local function getActiveAnchorFrame()
    local archaeologyFrame = _G.ArchaeologyFrame
    if archaeologyFrame and archaeologyFrame.IsShown and archaeologyFrame:IsShown() then
        return archaeologyFrame, true
    end

    local professionsFrame = _G.ProfessionsFrame
    if professionsFrame and professionsFrame.IsShown and professionsFrame:IsShown() then
        return professionsFrame, false
    end

    return nil, false
end

local function shouldAttachLeft(anchorFrame, preferLeft)
    if not anchorFrame then
        return false
    end

    if not preferLeft then
        return false
    end

    local panelWidth = (ui.panel and ui.panel.GetWidth and ui.panel:GetWidth()) or 238
    local left = anchorFrame.GetLeft and anchorFrame:GetLeft() or nil
    if type(left) == "number" and left < (panelWidth + 6) then
        return false
    end

    return true
end

local function setPanelAttachment(anchorFrame, attachLeft)
    if not (ui.panel and anchorFrame) then
        return
    end

    ui.panel:SetParent(anchorFrame)
    ui.panel:ClearAllPoints()
    if attachLeft then
        ui.panel:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", 0, 0)
        ui.panel:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMLEFT", 0, 0)

        if ui.joinSeam then
            ui.joinSeam:ClearAllPoints()
            ui.joinSeam:SetPoint("TOPRIGHT", ui.panel, "TOPRIGHT", 0, -1)
            ui.joinSeam:SetPoint("BOTTOMRIGHT", ui.panel, "BOTTOMRIGHT", 0, 1)
            ui.joinSeam:SetWidth(1)
        end
    else
        local rightGap = -1
        if anchorFrame == _G.ArchaeologyFrame then
            -- Keep clear of archaeology's protruding right-side ornament/buttons.
            rightGap = 12
        end

        ui.panel:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", rightGap, 0)
        ui.panel:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMRIGHT", rightGap, 0)

        if ui.joinSeam then
            ui.joinSeam:ClearAllPoints()
            ui.joinSeam:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 0, -1)
            ui.joinSeam:SetPoint("BOTTOMLEFT", ui.panel, "BOTTOMLEFT", 0, 1)
            ui.joinSeam:SetWidth(1)
        end
    end

    ui.panel:SetFrameStrata(anchorFrame:GetFrameStrata())
    ui.panel:SetFrameLevel(anchorFrame:GetFrameLevel() + 1)
end

local function setPanelWidth(panelWidth)
    if not ui.panel then
        return
    end

    panelWidth = tonumber(panelWidth) or DEFAULT_PANEL_WIDTH
    if panelWidth < DEFAULT_PANEL_WIDTH then
        panelWidth = DEFAULT_PANEL_WIDTH
    end

    ui.panel:SetWidth(panelWidth)
    if ui.tabContent then
        local contentWidth = math.max(1, panelWidth - 16)
        ui.tabContent:SetWidth(contentWidth)
    end
end

local function ensurePanel(anchorFrame, attachLeft)
    if not anchorFrame then
        return nil
    end

    if ui.panel then
        setPanelAttachment(anchorFrame, shouldAttachLeft(anchorFrame, attachLeft))
        return ui.panel
    end

    local panel = CreateFrame("Frame", "ProfessionUIExpansionSideTabs", anchorFrame, "BackdropTemplate")
    panel:SetWidth(DEFAULT_PANEL_WIDTH)
    panel:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(unpack(THEME.panelBg))
    panel:SetBackdropBorderColor(unpack(THEME.panelBorder))

    local headerBar = panel:CreateTexture(nil, "ARTWORK")
    headerBar:SetColorTexture(unpack(THEME.headerBg))
    headerBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    headerBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    headerBar:SetHeight(31)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -34, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Expansions")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -34, -12)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("")
    subtitle:SetTextColor(0.82, 0.82, 0.82)

    local archaeologyNotice = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    archaeologyNotice:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 8)
    archaeologyNotice:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 8)
    archaeologyNotice:SetJustifyH("CENTER")
    archaeologyNotice:SetTextColor(1.0, 0.82, 0.42)
    archaeologyNotice:SetText("In progress: Archaeology is not fully functional yet")
    archaeologyNotice:Hide()

    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        ui.hideUntilNextTradeSkillOpen = true
        panel:Hide()
    end)

    -- Seam lines to visually attach this panel to the default professions frame.
    local joinSeam = panel:CreateTexture(nil, "BORDER")
    joinSeam:SetColorTexture(unpack(THEME.seamStrong))
    joinSeam:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -1)
    joinSeam:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 1)
    joinSeam:SetWidth(1)

    local topSeam = panel:CreateTexture(nil, "BORDER")
    topSeam:SetColorTexture(unpack(THEME.seamSoft))
    topSeam:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, 0)
    topSeam:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, 0)
    topSeam:SetHeight(1)

    local bottomSeam = panel:CreateTexture(nil, "BORDER")
    bottomSeam:SetColorTexture(unpack(THEME.seamSoft))
    bottomSeam:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 0)
    bottomSeam:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 0)
    bottomSeam:SetHeight(1)

    local tabScroll = CreateFrame("ScrollFrame", nil, panel)
    tabScroll:EnableMouseWheel(true)
    local tabContent = CreateFrame("Frame", nil, tabScroll)
    tabContent:SetSize(DEFAULT_PANEL_WIDTH - 16, 1)
    tabScroll:SetScrollChild(tabContent)
    tabScroll:SetScript("OnMouseWheel", function(self, delta)
        local childHeight = (ui.tabContent and ui.tabContent.GetHeight and ui.tabContent:GetHeight()) or 0
        local visibleHeight = self:GetHeight() or 0
        local maxScroll = math.max(0, childHeight - visibleHeight)
        local nextScroll = (self:GetVerticalScroll() or 0) - (delta * 28)
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)

    ui.panel = panel
    ui.title = title
    ui.subtitle = subtitle
    ui.archaeologyNotice = archaeologyNotice
    ui.joinSeam = joinSeam
    ui.topSeam = topSeam
    ui.bottomSeam = bottomSeam
    ui.tabScroll = tabScroll
    ui.tabContent = tabContent

    setPanelAttachment(anchorFrame, shouldAttachLeft(anchorFrame, attachLeft))

    return panel
end

refreshSideTabs = function()
    local anchorFrame, anchorIsArchaeology = getActiveAnchorFrame()
    local panel = ensurePanel(anchorFrame, anchorIsArchaeology)
    if not panel then
        return
    end

    if ui.hideUntilNextTradeSkillOpen then
        panel:Hide()
        return
    end

    local activeContext = getActiveProfessionContext()
    local activeProfessionID = activeContext.professionID or ARCHAEOLOGY_SKILL_LINE_ID
    local currentChildSkillLineID = activeContext.currentSkillLineID
    local archaeologyMode = anchorIsArchaeology or isArchaeologyContext(activeContext)

    local entries = archaeologyMode and getArchaeologyRaceEntries() or getExpansionEntriesForCurrentProfession()
    if #entries == 0 then
        panel:Hide()
        return
    end

    panel:Show()

    if archaeologyMode then
        setPanelWidth(ARCHAEOLOGY_PANEL_WIDTH)
    else
        setPanelWidth(DEFAULT_PANEL_WIDTH)
    end

    if archaeologyMode then
        ui.title:SetText("Archaeology Races")
        ui.subtitle:SetText("In progress: Archaeology view is not fully functional yet")
        if ui.archaeologyNotice then
            ui.archaeologyNotice:Show()
        end
    else
        ui.title:SetText("Expansions")
        ui.subtitle:SetText("")
        if ui.archaeologyNotice then
            ui.archaeologyNotice:Hide()
        end
    end

    local pinProfessionID = activeProfessionID
    if not archaeologyMode then
        for _, entry in ipairs(entries) do
            if type(entry.professionID) == "number" then
                pinProfessionID = entry.professionID
                break
            end
        end
    end

    local pinnedExpansion = archaeologyMode and nil or getPinnedExpansion()
    local desiredExpansion = archaeologyMode and nil or (pinnedExpansion or getLastSelectedExpansion())
    if not archaeologyMode and desiredExpansion then
        for _, entry in ipairs(entries) do
            if entry.expansionName == desiredExpansion then
                local canSwitchToEntry = (entry.isPlaceholder ~= true and type(entry.skillLineID) == "number")
                if canSwitchToEntry and currentChildSkillLineID ~= entry.skillLineID then
                    local retryKey = tostring(pinProfessionID or "?") .. ":" .. tostring(desiredExpansion)
                    if ui.pinAutoSwitchRetryKey ~= retryKey then
                        ui.pinAutoSwitchRetryKey = retryKey
                        ui.pinAutoSwitchRetryCount = 0
                    end

                    ui.pinAutoSwitchRetryCount = (ui.pinAutoSwitchRetryCount or 0) + 1
                    local switched = switchProfessionSkillLine(entry.skillLineID, entry.isChildSkillLine == true)
                    C_Timer.After(0, refreshSideTabs)

                    if not switched and ui.pinAutoSwitchRetryCount < 4 then
                        C_Timer.After(0.10, refreshSideTabs)
                    elseif switched then
                        ui.pinAutoSwitchRetryKey = nil
                        ui.pinAutoSwitchRetryCount = 0
                    end
                    return
                end

                ui.pinAutoSwitchRetryKey = nil
                ui.pinAutoSwitchRetryCount = 0
            end
        end
    end

    local switcherHeight = refreshProfessionSwitcher(activeContext)
    local listTop = -48 - switcherHeight - 8
    local listBottom = archaeologyMode and 28 or 10

    if ui.tabScroll then
        ui.tabScroll:ClearAllPoints()
        ui.tabScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, listTop)
        ui.tabScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, listBottom)
        ui.tabScroll:SetVerticalScroll(0)
    end

    local rowsPerColumn = 10
    local listWidth = (panel.GetWidth and panel:GetWidth() or DEFAULT_PANEL_WIDTH) - 16
    local columnGap = 8
    local columns = 1
    local rowWidth = listWidth
    if archaeologyMode and #entries <= (rowsPerColumn * 2) then
        columns = 2
        rowWidth = math.floor((listWidth - columnGap) / 2)
        if rowWidth < 100 then
            columns = 1
            rowWidth = listWidth
        end
    end

    for i, entry in ipairs(entries) do
        local btn = acquireTab(i)
        if btn:GetParent() ~= ui.tabContent and ui.tabContent then
            btn:SetParent(ui.tabContent)
        end
        btn:ClearAllPoints()

        local col = 0
        local row = i - 1
        if columns > 1 then
            col = math.floor((i - 1) / rowsPerColumn)
            if col > 1 then
                col = 1
            end
            row = (i - 1) % rowsPerColumn
        end
        local x = col * (rowWidth + columnGap)
        local rowY = -row * TAB_ROW_HEIGHT

        btn:SetPoint("TOPLEFT", ui.tabContent or panel, "TOPLEFT", x, rowY)
        btn:SetWidth(rowWidth)

        local label = getDisplayExpansionName(entry.expansionName)
        local rankLabel = ""
        if archaeologyMode then
            rankLabel = entry.rankLabel or ""
        elseif entry.maxRank and entry.maxRank > 0 then
            rankLabel = string.format("%d/%d", entry.rank or 0, entry.maxRank)
        end
        local isPinned = (pinnedExpansion ~= nil and pinnedExpansion == entry.expansionName)
        btn.label:SetText(label)
        btn.rankText:SetText(rankLabel)
        btn.skillLineID = archaeologyMode and nil or entry.skillLineID
        btn.isChildSkillLine = archaeologyMode and false or (entry.isChildSkillLine == true)
        btn.expansionRank = archaeologyMode and nil or (tonumber(entry.rank) or 0)
        btn.expansionMaxRank = archaeologyMode and nil or (tonumber(entry.maxRank) or 0)
        btn.isUnavailableExpansion = false
        btn.expansionName = entry.expansionName
        btn.baseProfessionID = pinProfessionID
        btn.isPinned = archaeologyMode and false or isPinned
        btn.isArchaeologyRace = archaeologyMode and entry.isArchaeologyRace == true
        btn.raceIndex = archaeologyMode and entry.raceIndex or nil
        btn.canSolve = archaeologyMode and entry.canSolve == true
        btn.isEvenRow = (i % 2 == 0)

        if archaeologyMode then
            btn.pinBtn:Hide()
            btn.pinBtn:Disable()
            btn.label:SetPoint("LEFT", btn, "LEFT", 12, 0)
            btn.label:SetPoint("RIGHT", btn, "RIGHT", -62, 0)
        else
            btn.pinBtn:Show()
            btn.pinBtn:Enable()
            btn.pinBtn.icon:SetTexture(isPinned and PIN_ICON_LOCKED or PIN_ICON_UNLOCKED)
            btn.label:SetPoint("LEFT", btn, "LEFT", 32, 0)
            btn.label:SetPoint("RIGHT", btn, "RIGHT", -62, 0)
        end

        local isSelected = (not archaeologyMode and currentChildSkillLineID == entry.skillLineID)
        btn.isSelected = isSelected
        if archaeologyMode and btn.canSolve then
            btn.label:SetTextColor(0.65, 1, 0.65)
            btn.rankText:SetTextColor(0.65, 1, 0.65)
            btn:SetBackdropColor(0.14, 0.21, 0.14, 0.92)
            btn:SetBackdropBorderColor(0.26, 0.56, 0.26, 0.95)
            btn.leftAccent:Show()
            btn.leftAccent:SetColorTexture(0.45, 0.95, 0.45, 0.95)
        elseif isSelected then
            btn.label:SetTextColor(unpack(THEME.rowSelectedText))
            btn.rankText:SetTextColor(unpack(THEME.rowSelectedText))
            btn:SetBackdropColor(unpack(THEME.rowSelectedBg))
            btn:SetBackdropBorderColor(unpack(THEME.rowSelectedBorder))
            btn.leftAccent:Show()
            btn.leftAccent:SetColorTexture(unpack(THEME.rowSelectedAccent))
        else
            btn.label:SetTextColor(unpack(THEME.rowText))
            btn.rankText:SetTextColor(unpack(THEME.rowSubText))
            if btn.isEvenRow then
                btn:SetBackdropColor(unpack(THEME.rowEvenBg))
            else
                btn:SetBackdropColor(unpack(THEME.rowOddBg))
            end
            btn:SetBackdropBorderColor(unpack(THEME.rowBorder))
            btn.leftAccent:Hide()
        end
        if archaeologyMode then
            btn.pinBtn.icon:SetVertexColor(unpack(THEME.pinIcon))
            btn.pinBtn.bg:SetColorTexture(unpack(THEME.pinBg))
            btn.pinBtn.border:SetColorTexture(unpack(THEME.pinBorder))
        elseif isPinned then
            btn.pinBtn.icon:SetVertexColor(unpack(THEME.pinPinnedIcon))
            btn.pinBtn.bg:SetColorTexture(unpack(THEME.pinPinnedBg))
            btn.pinBtn.border:SetColorTexture(unpack(THEME.pinPinnedBorder))
        else
            btn.pinBtn.icon:SetVertexColor(unpack(THEME.pinIcon))
            btn.pinBtn.bg:SetColorTexture(unpack(THEME.pinBg))
            btn.pinBtn.border:SetColorTexture(unpack(THEME.pinBorder))
        end

    end

    if ui.tabContent then
        local usedRows = #entries
        if columns > 1 then
            usedRows = math.min(rowsPerColumn, math.ceil(#entries / 2))
        end
        local contentHeight = math.max(1, (usedRows * TAB_ROW_HEIGHT) + 2)
        ui.tabContent:SetHeight(contentHeight)
    end

    for i = #entries + 1, #ui.tabs do
        ui.tabs[i]:Hide()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("ADDON_LOADED")

local function ensureArchaeologyHooksInstalled()
    if _G.ArchaeologyFrame and not ui.archaeologyHooksInstalled then
        _G.ArchaeologyFrame:HookScript("OnShow", refreshSideTabs)
        _G.ArchaeologyFrame:HookScript("OnHide", refreshSideTabs)
        ui.archaeologyHooksInstalled = true
    end
end

local function ensureArchaeologyHooksWithRetry(attempt)
    attempt = attempt or 1
    ensureArchaeologyHooksInstalled()
    if ui.archaeologyHooksInstalled then
        return
    end

    if attempt >= 20 or not (C_Timer and C_Timer.After) then
        return
    end

    C_Timer.After(0.2, function()
        ensureArchaeologyHooksWithRetry(attempt + 1)
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        ensureArchaeologyHooksInstalled()
        if arg1 == "Blizzard_ArchaeologyUI" then
            C_Timer.After(0, refreshSideTabs)
            return
        end
    end

    if event == "ADDON_LOADED" and arg1 == "Blizzard_Professions" then
        if _G.ProfessionsFrame and not ui.hooksInstalled then
            _G.ProfessionsFrame:HookScript("OnShow", refreshSideTabs)
            _G.ProfessionsFrame:HookScript("OnHide", refreshSideTabs)
            ui.hooksInstalled = true
        end
        C_Timer.After(0, refreshSideTabs)
        return
    end

    if event == "PLAYER_LOGIN" then
        if _G.ProfessionsFrame and not ui.hooksInstalled then
            _G.ProfessionsFrame:HookScript("OnShow", refreshSideTabs)
            _G.ProfessionsFrame:HookScript("OnHide", refreshSideTabs)
            ui.hooksInstalled = true
        end
        ensureArchaeologyHooksWithRetry(1)
        C_Timer.After(0, refreshSideTabs)
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        ui.hideUntilNextTradeSkillOpen = false
    end

    C_Timer.After(0, refreshSideTabs)
end)

SLASH_PROFESSIONUIPINS1 = "/puipins"
SLASH_PROFESSIONUIPINS2 = "/puiclearpins"
SlashCmdList["PROFESSIONUIPINS"] = function(msg)
    local arg = string.lower(strtrim(msg or ""))
    if arg == "" or arg == "help" then
        print("|cff33ff99ProfessionUI pins:|r")
        print("  /puipins clear      - Clear all saved expansion pins")
        print("  /puiclearpins       - Alias for /puipins clear")
        print("  Tip: Click the pin toggle on an expansion row to pin/unpin it")
        return
    end

    if arg == "clear" then
        local removed = clearAllPinnedExpansions()
        C_Timer.After(0, refreshSideTabs)
        print("|cff33ff99ProfessionUI:|r Cleared " .. tostring(removed) .. " saved pin(s).")
        return
    end

    print("|cffff6666ProfessionUI:|r Unknown pins command. Use /puipins help")
end
