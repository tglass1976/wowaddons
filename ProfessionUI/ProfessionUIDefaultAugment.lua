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
    joinSeam = nil,
    topSeam = nil,
    bottomSeam = nil,
    tabs = {},
    hooksInstalled = false,
    pinAppliedForProfessionID = nil,
}

local refreshSideTabs

local PIN_ICON_LOCKED = "Interface\\Buttons\\LockButton-Locked-Up"
local PIN_ICON_UNLOCKED = "Interface\\Buttons\\LockButton-Unlocked-Up"

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

local function getPinStorage()
    local db = addon.GetDB and addon.GetDB() or nil
    if type(db) ~= "table" then
        return nil
    end
    db.ui = db.ui or {}
    db.ui.pinnedExpansionByProfessionID = db.ui.pinnedExpansionByProfessionID or {}
    return db.ui.pinnedExpansionByProfessionID
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

    btn = CreateFrame("Button", nil, ui.panel, "BackdropTemplate")
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
            print("|cff33ff99ProfessionUI:|r Pinned " .. tostring(owner.expansionName) .. " for this profession")
        end
        ui.pinAppliedForProfessionID = nil
        C_Timer.After(0, refreshSideTabs)
    end)
    btn.pinBtn:SetScript("OnEnter", function(pinButton)
        local owner = pinButton:GetParent()
        local isPinned = owner and owner.isPinned
        GameTooltip:SetOwner(pinButton, "ANCHOR_RIGHT")
        if isPinned then
            GameTooltip:AddLine("Pinned Expansion", 1, 0.92, 0.35)
            GameTooltip:AddLine("Click to unpin this expansion for this profession.", 0.9, 0.9, 0.9, true)
        else
            GameTooltip:AddLine("Pin Expansion", 1, 0.92, 0.35)
            GameTooltip:AddLine("Click to always open this profession on this expansion.", 0.9, 0.9, 0.9, true)
        end
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
        if not self.skillLineID then
            return
        end

        local switched = false
        if C_TradeSkillUI and C_TradeSkillUI.SetProfessionChildSkillLineID then
            switched = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, self.skillLineID)
        end

        local pf = _G.ProfessionsFrame
        if switched and pf and type(pf.SetProfessionInfo) == "function" and _G.Professions and type(_G.Professions.GetProfessionInfo) == "function" then
            local professionInfo = _G.Professions.GetProfessionInfo()
            local useLastSkillLine = false
            pcall(pf.SetProfessionInfo, pf, professionInfo, useLastSkillLine)
        elseif addon.OpenTradeSkillForLine then
            -- Fallback for clients where direct frame method path is unavailable.
            addon.OpenTradeSkillForLine(self.skillLineID)
        end

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

local function ensurePanel()
    local professionsFrame = _G.ProfessionsFrame
    if not professionsFrame then
        return nil
    end

    if ui.panel then
        return ui.panel
    end

    local panel = CreateFrame("Frame", "ProfessionUIExpansionSideTabs", professionsFrame, "BackdropTemplate")
    panel:SetWidth(238)
    panel:SetPoint("TOPLEFT", professionsFrame, "TOPRIGHT", 0, 0)
    panel:SetPoint("BOTTOMLEFT", professionsFrame, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameStrata(professionsFrame:GetFrameStrata())
    panel:SetFrameLevel(professionsFrame:GetFrameLevel() + 1)
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

    ui.panel = panel
    ui.title = title
    ui.subtitle = subtitle
    ui.joinSeam = joinSeam
    ui.topSeam = topSeam
    ui.bottomSeam = bottomSeam

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

    local baseProfessionID = getActiveBaseProfessionID()
    local currentChildSkillLineID = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetProfessionChildSkillLineID then
        currentChildSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID()
    end

    local pinnedExpansion = getPinnedExpansion(baseProfessionID)
    if pinnedExpansion and ui.pinAppliedForProfessionID ~= baseProfessionID then
        for _, entry in ipairs(entries) do
            if entry.expansionName == pinnedExpansion then
                if currentChildSkillLineID ~= entry.skillLineID and C_TradeSkillUI and C_TradeSkillUI.SetProfessionChildSkillLineID then
                    local switched = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, entry.skillLineID)
                    if switched then
                        local pf = _G.ProfessionsFrame
                        if pf and type(pf.SetProfessionInfo) == "function" and _G.Professions and type(_G.Professions.GetProfessionInfo) == "function" then
                            local professionInfo = _G.Professions.GetProfessionInfo()
                            pcall(pf.SetProfessionInfo, pf, professionInfo, false)
                        end
                    end
                end
                ui.pinAppliedForProfessionID = baseProfessionID
                C_Timer.After(0, refreshSideTabs)
                return
            end
        end
    end

    if not pinnedExpansion then
        ui.pinAppliedForProfessionID = nil
    end

    local y = -48
    for i, entry in ipairs(entries) do
        local btn = acquireTab(i)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
        btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, y)

        local label = entry.expansionName
        local rankLabel = ""
        if entry.maxRank and entry.maxRank > 0 then
            rankLabel = string.format("%d/%d", entry.rank or 0, entry.maxRank)
        end
        local isPinned = (pinnedExpansion ~= nil and pinnedExpansion == entry.expansionName)
        btn.label:SetText(label)
        btn.rankText:SetText(rankLabel)
        btn.skillLineID = entry.skillLineID
        btn.expansionName = entry.expansionName
        btn.baseProfessionID = baseProfessionID
        btn.isPinned = isPinned
        btn.isEvenRow = (i % 2 == 0)
        btn.pinBtn.icon:SetTexture(isPinned and PIN_ICON_LOCKED or PIN_ICON_UNLOCKED)

        local isSelected = (currentChildSkillLineID == entry.skillLineID)
        btn.isSelected = isSelected
        if isSelected then
            btn.label:SetTextColor(1, 0.92, 0.35)
            btn.rankText:SetTextColor(1, 0.92, 0.35)
            btn:SetBackdropColor(0.29, 0.18, 0.14, 0.96)
            btn:SetBackdropBorderColor(0.78, 0.58, 0.18, 0.95)
            btn.leftAccent:Show()
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
        if isPinned then
            btn.pinBtn.icon:SetVertexColor(1, 0.92, 0.35, 1)
            btn.pinBtn.bg:SetColorTexture(0.18, 0.14, 0.08, 0.98)
            btn.pinBtn.border:SetColorTexture(0.82, 0.64, 0.22, 0.80)
        else
            btn.pinBtn.icon:SetVertexColor(0.88, 0.88, 0.88, 0.95)
            btn.pinBtn.bg:SetColorTexture(0.12, 0.08, 0.08, 0.95)
            btn.pinBtn.border:SetColorTexture(0.48, 0.34, 0.20, 0.55)
        end

        y = y - 30
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
