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
}

local function getExpansionSort(expansionName)
    return expansionOrderIndex[expansionName] or 999
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
                    local rawName = info.professionName or info.skillLineName or tostring(skillLineID)
                    local expansionName = addon.NormalizeExpansionName(rawName) or rawName
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
    btn:SetSize(150, 24)
    btn:SetScript("OnClick", function(self)
        if not self.skillLineID then
            return
        end

        if C_TradeSkillUI and C_TradeSkillUI.SetProfessionChildSkillLineID then
            C_TradeSkillUI.SetProfessionChildSkillLineID(self.skillLineID)
        elseif C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill then
            C_TradeSkillUI.OpenTradeSkill(self.skillLineID)
        end
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
    panel:SetSize(164, 440)
    panel:SetPoint("TOPLEFT", professionsFrame, "TOPRIGHT", 8, -28)
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

local function refreshSideTabs()
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
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, y)
        btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, y)

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
        C_Timer.After(0, refreshSideTabs)
        return
    end

    if event == "PLAYER_LOGIN" then
        if _G.ProfessionsFrame then
            _G.ProfessionsFrame:HookScript("OnShow", refreshSideTabs)
            _G.ProfessionsFrame:HookScript("OnHide", refreshSideTabs)
        end
        C_Timer.After(0, refreshSideTabs)
        return
    end

    C_Timer.After(0, refreshSideTabs)
end)
