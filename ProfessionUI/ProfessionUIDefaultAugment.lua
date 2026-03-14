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
    pinAppliedForProfessionID = nil,
}

local refreshSideTabs

local PIN_ICON_LOCKED = "Interface\\Buttons\\LockButton-Locked-Up"
local PIN_ICON_UNLOCKED = "Interface\\Buttons\\LockButton-Unlocked-Up"
local ARCHAEOLOGY_SKILL_LINE_ID = 794
local DEFAULT_PROFESSION_ICON = 134400
local DEFAULT_PANEL_WIDTH = 238
local ARCHAEOLOGY_PANEL_WIDTH = 468
local TAB_ROW_HEIGHT = 30

local function getExpansionSort(expansionName)
    return expansionOrderIndex[expansionName] or 999
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
            if type(baseInfo.professionID) == "number" then
                context.professionID = baseInfo.professionID
            elseif type(baseInfo.parentProfessionID) == "number" then
                context.professionID = baseInfo.parentProfessionID
            end
            if type(baseInfo.skillLineID) == "number" then
                context.currentSkillLineID = baseInfo.skillLineID
            end
            if type(baseInfo.professionName) == "string" and baseInfo.professionName ~= "" then
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

    if not context.professionID and context.currentSkillLineID and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local activeInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(context.currentSkillLineID)
        if type(activeInfo) == "table" then
            if type(activeInfo.parentProfessionID) == "number" then
                context.professionID = activeInfo.parentProfessionID
            elseif type(activeInfo.professionID) == "number" then
                context.professionID = activeInfo.professionID
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
        if type(data) == "table" and type(data.skillLineID) == "number" then
            entries[#entries + 1] = {
                skillLineID = data.skillLineID,
                expansionName = expansionName,
                rank = tonumber(data.rank) or 0,
                maxRank = tonumber(data.maxRank) or 0,
                isChildSkillLine = true,
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
    return db.ui.pinnedExpansionByProfessionID
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

local function getPinnedExpansion(professionID)
    local storage = getPinStorage()
    if not storage or not professionID then
        return nil
    end
    return storage[tostring(professionID)]
end

local function setPinnedExpansion(professionID, expansionName)
    local storage = getPinStorage()
    if not storage or not professionID then
        return
    end
    storage[tostring(professionID)] = expansionName
end

local function clearPinnedExpansion(professionID)
    local storage = getPinStorage()
    if not storage or not professionID then
        return
    end
    storage[tostring(professionID)] = nil
end

local function clearAllPinnedExpansions()
    local storage = getPinStorage()
    if type(storage) ~= "table" then
        return 0
    end

    local removed = 0
    for key in pairs(storage) do
        storage[key] = nil
        removed = removed + 1
    end
    return removed
end

local function getExpansionEntriesForCurrentProfession()
    local entries = {}

    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID) then
        return entries
    end

    local activeContext = getActiveProfessionContext()
    if not activeContext.professionID and not activeContext.professionName then
        return entries
    end

    local lines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
    if type(lines) ~= "table" then
        return entries
    end

    local byExpansion = {}

    for _, skillLineID in ipairs(lines) do
        if type(skillLineID) == "number" then
            local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
            if type(info) == "table" then
                if lineBelongsToActiveProfession(info, activeContext) then
                    local expansionName = resolveExpansionName(info)
                    if expansionName then
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
                            }
                        end
                    end
                end
            end
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

    if #entries == 0 then
        return buildFallbackEntries(activeContext)
    end

    return entries
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
        local switched = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, skillLineID)
        if switched then
            local pf = _G.ProfessionsFrame
            if pf and type(pf.SetProfessionInfo) == "function" and _G.Professions and type(_G.Professions.GetProfessionInfo) == "function" then
                local professionInfo = _G.Professions.GetProfessionInfo()
                local useLastSkillLine = false
                pcall(pf.SetProfessionInfo, pf, professionInfo, useLastSkillLine)
            end
            return true
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
    ui.pinAppliedForProfessionID = nil
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

    table.sort(entries, function(a, b)
        if (a.section or "") ~= (b.section or "") then
            return a.section == "Primary"
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
    btn:SetSize(32, 32)
    btn:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.16, 0.10, 0.10, 0.90)
    btn:SetBackdropBorderColor(0.42, 0.24, 0.24, 0.95)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(26, 26)
    btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.text:SetJustifyH("CENTER")
    btn.text:SetWordWrap(false)
    btn.text:Hide()

    btn:SetScript("OnClick", function(self)
        if not self.skillLineID then
            return
        end
        ui.pinAppliedForProfessionID = nil
        switchProfessionSkillLine(self.skillLineID, false)
        C_Timer.After(0, refreshSideTabs)
    end)

    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)

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
    local columns = 6
    local x = 8
    local y = -48

    local primary = {}
    local secondary = {}
    local archaeology = {}
    for _, entry in ipairs(entries) do
        if entry.section == "Archaeology" then
            archaeology[#archaeology + 1] = entry
        elseif entry.section == "Secondary" then
            secondary[#secondary + 1] = entry
        else
            primary[#primary + 1] = entry
        end
    end

    local buttonIndex = 0
    local headerIndex = 0
    local cursor = 0
    local rowHeight = 34
    local headerHeight = 12
    local sectionGap = 4

    local function renderSection(sectionName, sectionEntries)
        if #sectionEntries == 0 then
            return
        end

        headerIndex = headerIndex + 1
        local header = acquireProfessionSectionHeader(headerIndex)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", x, y - cursor)
        header:SetText(sectionName)
        cursor = cursor + headerHeight

        for i = 1, #sectionEntries do
            local entry = sectionEntries[i]
            buttonIndex = buttonIndex + 1
            local btn = acquireProfessionButton(buttonIndex)
            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", x + (col * 36), y - cursor - (row * rowHeight))
            btn:SetPoint("TOPRIGHT", ui.panel, "TOPLEFT", x + (col * 36) + 32, y - cursor - (row * rowHeight))

            btn.text:SetText("")
            btn.fullLabel = entry.label
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
                btn:SetBackdropColor(0.29, 0.18, 0.14, 0.96)
                btn:SetBackdropBorderColor(0.78, 0.58, 0.18, 0.95)
                btn.text:SetTextColor(1, 0.92, 0.35)
            else
                btn:SetBackdropColor(0.16, 0.10, 0.10, 0.90)
                btn:SetBackdropBorderColor(0.42, 0.24, 0.24, 0.95)
                btn.text:SetTextColor(0.95, 0.95, 0.95)
            end
        end

        local sectionRows = math.ceil(#sectionEntries / columns)
        cursor = cursor + (sectionRows * rowHeight) + sectionGap
    end

    renderSection("Primary", primary)
    renderSection("Secondary", secondary)
    renderSection("Archaeology", archaeology)

    for i = buttonIndex + 1, #ui.professionButtons do
        ui.professionButtons[i]:Hide()
    end

    for i = headerIndex + 1, #ui.professionSectionHeaders do
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
    btn:SetBackdropColor(0.17, 0.10, 0.10, 0.86)
    btn:SetBackdropBorderColor(0.42, 0.24, 0.24, 0.95)
    btn.leftAccent = btn:CreateTexture(nil, "ARTWORK")
    btn.leftAccent:SetColorTexture(0.88, 0.72, 0.24, 0.95)
    btn.leftAccent:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
    btn.leftAccent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 3, 3)
    btn.leftAccent:SetWidth(2)
    btn.leftAccent:Hide()
    btn.pinBtn = CreateFrame("Button", nil, btn)
    btn.pinBtn:SetSize(18, 18)
    btn.pinBtn:SetPoint("LEFT", btn, "LEFT", 7, 0)
    btn.pinBtn.bg = btn.pinBtn:CreateTexture(nil, "BACKGROUND")
    btn.pinBtn.bg:SetAllPoints(btn.pinBtn)
    btn.pinBtn.bg:SetColorTexture(0.12, 0.08, 0.08, 0.95)
    btn.pinBtn.border = btn.pinBtn:CreateTexture(nil, "BORDER")
    btn.pinBtn.border:SetAllPoints(btn.pinBtn)
    btn.pinBtn.border:SetColorTexture(0.48, 0.34, 0.20, 0.55)
    btn.pinBtn.icon = btn.pinBtn:CreateTexture(nil, "OVERLAY")
    btn.pinBtn.icon:SetAllPoints(btn.pinBtn)
    btn.pinBtn.icon:SetTexture(PIN_ICON_UNLOCKED)
    btn.pinBtn.icon:SetVertexColor(0.88, 0.88, 0.88, 0.95)
    btn.pinBtn:SetScript("OnClick", function(pinButton)
        local owner = pinButton:GetParent()
        if not owner or not owner.baseProfessionID or not owner.expansionName then
            return
        end

        if owner.isPinned then
            clearPinnedExpansion(owner.baseProfessionID)
            print("|cff33ff99ProfessionUI:|r Unpinned " .. tostring(owner.expansionName))
        else
            setPinnedExpansion(owner.baseProfessionID, owner.expansionName)
            setLastSelectedExpansion(owner.expansionName)
            print("|cff33ff99ProfessionUI:|r Pinned " .. tostring(owner.expansionName) .. " for this profession")
        end
        ui.pinAppliedForProfessionID = nil
        C_Timer.After(0, refreshSideTabs)
    end)
    btn.pinBtn:SetScript("OnEnter", nil)
    btn.pinBtn:SetScript("OnLeave", nil)
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
            return
        end

        if self.expansionName then
            setLastSelectedExpansion(self.expansionName)
        end

        switchProfessionSkillLine(self.skillLineID, self.isChildSkillLine == true)

        C_Timer.After(0, refreshSideTabs)
    end)

    btn:SetScript("OnEnter", function(self)
        if not self.isSelected then
            self:SetBackdropColor(0.24, 0.14, 0.14, 0.92)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if self.isSelected then
            self:SetBackdropColor(0.29, 0.18, 0.14, 0.96)
        else
            if self.isEvenRow then
                self:SetBackdropColor(0.19, 0.12, 0.12, 0.86)
            else
                self:SetBackdropColor(0.16, 0.10, 0.10, 0.86)
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
        local rightGap = 0
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
    panel:SetBackdropColor(0.09, 0.08, 0.07, 0.94)
    panel:SetBackdropBorderColor(0.45, 0.38, 0.26, 0.95)

    local headerBar = panel:CreateTexture(nil, "ARTWORK")
    headerBar:SetColorTexture(0.18, 0.14, 0.09, 0.92)
    headerBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    headerBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    headerBar:SetHeight(36)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -9)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Expansions")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    subtitle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -12)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Click lock icon to pin")
    subtitle:SetTextColor(0.78, 0.78, 0.68)

    -- Seam lines to visually attach this panel to the default professions frame.
    local joinSeam = panel:CreateTexture(nil, "BORDER")
    joinSeam:SetColorTexture(0.56, 0.46, 0.30, 0.65)
    joinSeam:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -1)
    joinSeam:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 1)
    joinSeam:SetWidth(1)

    local topSeam = panel:CreateTexture(nil, "BORDER")
    topSeam:SetColorTexture(0.56, 0.46, 0.30, 0.45)
    topSeam:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, 0)
    topSeam:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, 0)
    topSeam:SetHeight(1)

    local bottomSeam = panel:CreateTexture(nil, "BORDER")
    bottomSeam:SetColorTexture(0.56, 0.46, 0.30, 0.45)
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
        ui.subtitle:SetText("Solve-ready races are highlighted")
        ui.pinAppliedForProfessionID = nil
    else
        ui.title:SetText("Expansions")
        ui.subtitle:SetText("Click lock icon to pin")
    end

    local pinnedExpansion = archaeologyMode and nil or getPinnedExpansion(activeProfessionID)
    local desiredExpansion = archaeologyMode and nil or (pinnedExpansion or getLastSelectedExpansion())
    if not archaeologyMode and desiredExpansion then
        for _, entry in ipairs(entries) do
            if entry.expansionName == desiredExpansion then
                if currentChildSkillLineID ~= entry.skillLineID then
                    switchProfessionSkillLine(entry.skillLineID, entry.isChildSkillLine == true)
                    ui.pinAppliedForProfessionID = activeProfessionID
                    C_Timer.After(0, refreshSideTabs)
                    return
                end
            end
        end
    end

    if archaeologyMode then
        ui.pinAppliedForProfessionID = nil
    end

    local switcherHeight = refreshProfessionSwitcher(activeContext)
    local listTop = -48 - switcherHeight - 8
    local listBottom = 10

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

        local label = entry.expansionName
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
        btn.expansionName = entry.expansionName
        btn.baseProfessionID = activeProfessionID
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
            btn.label:SetTextColor(1, 0.92, 0.35)
            btn.rankText:SetTextColor(1, 0.92, 0.35)
            btn:SetBackdropColor(0.29, 0.18, 0.14, 0.96)
            btn:SetBackdropBorderColor(0.78, 0.58, 0.18, 0.95)
            btn.leftAccent:Show()
            btn.leftAccent:SetColorTexture(0.88, 0.72, 0.24, 0.95)
        else
            btn.label:SetTextColor(0.95, 0.95, 0.95)
            btn.rankText:SetTextColor(0.86, 0.86, 0.86)
            if btn.isEvenRow then
                btn:SetBackdropColor(0.19, 0.12, 0.12, 0.86)
            else
                btn:SetBackdropColor(0.16, 0.10, 0.10, 0.86)
            end
            btn:SetBackdropBorderColor(0.42, 0.24, 0.24, 0.95)
            btn.leftAccent:Hide()
        end
        if archaeologyMode then
            btn.pinBtn.icon:SetVertexColor(0.88, 0.88, 0.88, 0.95)
            btn.pinBtn.bg:SetColorTexture(0.12, 0.08, 0.08, 0.95)
            btn.pinBtn.border:SetColorTexture(0.48, 0.34, 0.20, 0.55)
        elseif isPinned then
            btn.pinBtn.icon:SetVertexColor(1, 0.92, 0.35, 1)
            btn.pinBtn.bg:SetColorTexture(0.18, 0.14, 0.08, 0.98)
            btn.pinBtn.border:SetColorTexture(0.82, 0.64, 0.22, 0.80)
        else
            btn.pinBtn.icon:SetVertexColor(0.88, 0.88, 0.88, 0.95)
            btn.pinBtn.bg:SetColorTexture(0.12, 0.08, 0.08, 0.95)
            btn.pinBtn.border:SetColorTexture(0.48, 0.34, 0.20, 0.55)
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
        ui.pinAppliedForProfessionID = nil
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
        print("  Tip: Click the lock icon on an expansion row to pin/unpin it")
        return
    end

    if arg == "clear" then
        local removed = clearAllPinnedExpansions()
        ui.pinAppliedForProfessionID = nil
        C_Timer.After(0, refreshSideTabs)
        print("|cff33ff99ProfessionUI:|r Cleared " .. tostring(removed) .. " saved pin(s).")
        return
    end

    print("|cffff6666ProfessionUI:|r Unknown pins command. Use /puipins help")
end
