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
    tabs = {},
    hooksInstalled = false,
}

local refreshSideTabs

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

local function getActiveBaseProfessionID()
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local info = C_TradeSkillUI.GetBaseProfessionInfo()
        if type(info) == "table" and type(info.professionID) == "number" then
            return info.professionID
        end
    end
    return nil
end

local function getExpansionEntriesForCurrentProfession()
    local entries = {}

    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID) then
        return entries
    end

    local baseProfessionID = getActiveBaseProfessionID()
    if not baseProfessionID then
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
                local isChildLine = info.parentProfessionID ~= nil
                local belongsToBase = info.parentProfessionID == baseProfessionID

                if isChildLine and belongsToBase then
                    local expansionName = resolveExpansionName(info) or (info.professionName or info.skillLineName or tostring(skillLineID))
                    local rank = tonumber(info.skillLevel) or 0
                    local maxRank = tonumber(info.maxSkillLevel) or 0

                    local prev = byExpansion[expansionName]
                    if not prev or rank > (prev.rank or 0) then
                        byExpansion[expansionName] = {
                            skillLineID = skillLineID,
                            expansionName = expansionName,
                            rank = rank,
                            maxRank = maxRank,
                        }
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

    return entries
end

local function acquireTab(index)
    local btn = ui.tabs[index]
    if btn then
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, ui.panel, "UIPanelButtonTemplate")
    btn:SetSize(196, 22)
    btn:SetScript("OnClick", function(self)
        if not self.skillLineID then
            return
        end

        if addon.OpenTradeSkillForLine then
            addon.OpenTradeSkillForLine(self.skillLineID)
        elseif C_TradeSkillUI and C_TradeSkillUI.SetProfessionChildSkillLineID then
            C_TradeSkillUI.SetProfessionChildSkillLineID(self.skillLineID)
        end

        C_Timer.After(0, refreshSideTabs)
    end)

    ui.tabs[index] = btn
    return btn
end

local function ensurePanel()
    local professionsFrame = _G.ProfessionsFrame
    if not professionsFrame then
        return nil
    end

    if ui.panel then
        return ui.panel
    end

    local panel = CreateFrame("Frame", "ProfessionUIExpansionSideTabs", professionsFrame, "BackdropTemplate")
    panel:SetWidth(212)
    panel:SetPoint("TOPLEFT", professionsFrame, "TOPRIGHT", 10, -26)
    panel:SetPoint("BOTTOMLEFT", professionsFrame, "BOTTOMRIGHT", 10, 26)
    panel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.06, 0.9)
    panel:SetBackdropBorderColor(0.35, 0.35, 0.4, 0.95)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    title:SetJustifyH("LEFT")
    title:SetText("Expansions")

    ui.panel = panel
    ui.title = title

    return panel
end

refreshSideTabs = function()
    local panel = ensurePanel()
    if not panel then
        return
    end

    local professionsFrame = _G.ProfessionsFrame
    if not (professionsFrame and professionsFrame:IsShown()) then
        panel:Hide()
        return
    end

    local entries = getExpansionEntriesForCurrentProfession()
    if #entries == 0 then
        panel:Hide()
        return
    end

    panel:Show()

    local currentChildSkillLineID = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionChildSkillLineID then
        currentChildSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
    end

    local y = -34
    for i, entry in ipairs(entries) do
        local btn = acquireTab(i)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)

        local label = entry.expansionName
        if entry.maxRank and entry.maxRank > 0 then
            label = string.format("%s  %d/%d", entry.expansionName, entry.rank or 0, entry.maxRank)
        end
        btn:SetText(label)
        btn.skillLineID = entry.skillLineID

        local isSelected = (currentChildSkillLineID == entry.skillLineID)
        if isSelected then
            btn:GetFontString():SetTextColor(1, 0.92, 0.35)
        else
            btn:GetFontString():SetTextColor(1, 1, 1)
        end

        y = y - 26
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

eventFrame:SetScript("OnEvent", function(_, event, arg1)
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
        C_Timer.After(0, refreshSideTabs)
        return
    end

    C_Timer.After(0, refreshSideTabs)
end)
