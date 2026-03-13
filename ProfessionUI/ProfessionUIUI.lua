local addonName, addon = ...

local constants = addon.constants
local theme = addon.theme
local state = addon.state
local pools = addon.pools
local EXPANSION_ORDER = addon.expansionOrder
local L = addon.GetString

local ui = {}
addon.ui = ui

local UpdateRecipeList
local UpdateArchaeologyView
local SelectProfession
local ResetMinimapButtonPosition

local function IsArchaeologyProfessionSafe(prof)
    if type(addon.IsArchaeologyProfession) == "function" then
        return addon.IsArchaeologyProfession(prof)
    end

    if not prof then
        return false
    end
    if prof.name and prof.name:lower() == "archaeology" then
        return true
    end
    return (prof.skillLine or 0) == 794
end

local function GetProfessionCacheKey(prof)
    if not prof then
        return nil
    end

    if prof.cacheKey and prof.cacheKey ~= "" then
        return prof.cacheKey
    end

    return string.format("%s:%s", tostring(prof.skillLine or 0), tostring(prof.name or ""))
end

local function MergeCachedExpansionData(previousExpansionData, rebuiltExpansionData)
    if type(previousExpansionData) ~= "table" or type(rebuiltExpansionData) ~= "table" then
        return
    end

    for expansion, prev in pairs(previousExpansionData) do
        local nextInfo = rebuiltExpansionData[expansion]
        if prev and not nextInfo then
            rebuiltExpansionData[expansion] = {
                rank = prev.rank or 0,
                maxRank = prev.maxRank or 0,
                skillLineID = prev.skillLineID,
                recipes = prev.recipes,
                recipeError = prev.recipeError,
            }
        elseif prev and nextInfo then
            if (prev.maxRank or 0) > (nextInfo.maxRank or 0) then
                nextInfo.rank = prev.rank or 0
                nextInfo.maxRank = prev.maxRank or 0
            end
            if not nextInfo.skillLineID and prev.skillLineID then
                nextInfo.skillLineID = prev.skillLineID
            end
            if prev.recipes then
                nextInfo.recipes = prev.recipes
                nextInfo.recipeError = prev.recipeError
            end
        end
    end
end

local function InvalidateRecipeCacheForExpansionData(expansionData)
    if type(expansionData) ~= "table" then
        return
    end

    for _, info in pairs(expansionData) do
        if type(info) == "table" then
            info.recipes = nil
            info.recipeError = nil
        end
    end
end

local function ApplyPanelStyle(panel)
    if not panel or not panel.SetBackdrop then
        return
    end

    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 11,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(unpack(theme.panelBg))
    panel:SetBackdropBorderColor(unpack(theme.panelBorder))
end

local function CreateListTabButton(parent, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(height)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)
    btn.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)

    btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.hl:SetAllPoints(btn)
    btn.hl:SetColorTexture(1.0, 0.82, 0.0, 0.12)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.label:SetPoint("LEFT", btn, "LEFT", 8, 0)
    btn.label:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    btn.label:SetJustifyH("LEFT")

    btn.SetSelected = function(self, selected)
        if selected then
            self.bg:SetColorTexture(1.0, 0.82, 0.0, 0.20)
        else
            self.bg:SetColorTexture(0.12, 0.12, 0.12, 0.35)
        end
    end

    return btn
end

local function GetCollapsedBucketKey()
    local selected = state.professions[state.selectedProfession]
    local cacheKey = GetProfessionCacheKey(selected) or "global"
    return cacheKey .. "|" .. tostring(state.selectedExpansion or "")
end

local function IsCategoryCollapsed(categoryKey)
    local bucket = state.collapsedCategories[GetCollapsedBucketKey()]
    return bucket and bucket[categoryKey] or false
end

local function ToggleCategoryCollapsed(categoryKey)
    if not categoryKey then
        return
    end

    local bucketKey = GetCollapsedBucketKey()
    if type(state.collapsedCategories[bucketKey]) ~= "table" then
        state.collapsedCategories[bucketKey] = {}
    end
    state.collapsedCategories[bucketKey][categoryKey] = not state.collapsedCategories[bucketKey][categoryKey]
end

local function GetVisibleRecipeRows()
    return math.max(1, math.floor((ui.recipeListContainer:GetHeight() or 0) / constants.RECIPE_ROW_HEIGHT))
end

local function GetVisibleArchRows()
    return math.max(1, math.floor((ui.archContainer:GetHeight() or 0) / constants.ARCH_ROW_HEIGHT))
end

local function BuildRecipeDisplayRows(recipes)
    local rows = {}
    local lastCategoryKey

    for _, recipe in ipairs(recipes) do
        local categoryKey = recipe.categoryKey or "uncategorized"
        if categoryKey ~= lastCategoryKey then
            table.insert(rows, {
                type = "header",
                text = recipe.categoryLabel or "Uncategorized",
                categoryKey = categoryKey,
                collapsed = IsCategoryCollapsed(categoryKey),
            })
            lastCategoryKey = categoryKey
        end

        if not IsCategoryCollapsed(categoryKey) then
            table.insert(rows, {
                type = "recipe",
                recipe = recipe,
            })
        end
    end

    return rows
end

local function GetOrCreateRecipeRow(index)
    if pools.recipeRows[index] then
        return pools.recipeRows[index]
    end

    local row = CreateFrame("Button", nil, ui.recipeListContainer)
    row:SetHeight(constants.RECIPE_ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row._quantity = 1

    row.statusIcon = row:CreateTexture(nil, "ARTWORK")
    row.statusIcon:SetSize(8, 8)
    row.statusIcon:SetPoint("LEFT", row, "LEFT", 5, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("TOP")

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.detail:SetJustifyH("LEFT")
    row.detail:SetJustifyV("TOP")

    row.availableLabel = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.availableLabel:SetWidth(30)
    row.availableLabel:SetPoint("RIGHT", row, "RIGHT", -140, 0)
    row.availableLabel:SetJustifyH("RIGHT")

    row.qtyDecBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.qtyDecBtn:SetSize(20, 20)
    row.qtyDecBtn:SetPoint("RIGHT", row, "RIGHT", -108, 0)
    row.qtyDecBtn:SetText("-")

    row.qtyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.qtyLabel:SetWidth(24)
    row.qtyLabel:SetPoint("RIGHT", row, "RIGHT", -82, 0)
    row.qtyLabel:SetJustifyH("CENTER")

    row.qtyIncBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.qtyIncBtn:SetSize(20, 20)
    row.qtyIncBtn:SetPoint("RIGHT", row, "RIGHT", -60, 0)
    row.qtyIncBtn:SetText("+")

    row.craftBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.craftBtn:SetSize(56, 20)
    row.craftBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetWidth(16)
    row.status:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.status:SetJustifyH("RIGHT")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(1.0, 0.82, 0.0, 0.12)

    local divider = row:CreateTexture(nil, "BACKGROUND")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    divider:SetColorTexture(0.26, 0.36, 0.52, 0.45)

    pools.recipeRows[index] = row
    return row
end

local function GetOrCreateArchRow(index)
    if pools.archRaceRows[index] then
        return pools.archRaceRows[index]
    end

    local row = CreateFrame("Frame", nil, ui.archContainer)
    row:SetHeight(constants.ARCH_ROW_HEIGHT)

    row.raceIcon = row:CreateTexture(nil, "ARTWORK")
    row.raceIcon:SetSize(34, 34)
    row.raceIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

    row.raceName = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.raceName:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -4)
    row.raceName:SetPoint("RIGHT", row, "RIGHT", -90, 0)

    row.completed = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.completed:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)

    row.artName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.artName:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -22)
    row.artName:SetPoint("RIGHT", row, "RIGHT", -90, 0)

    row.fragBarBg = row:CreateTexture(nil, "BACKGROUND")
    row.fragBarBg:SetHeight(8)
    row.fragBarBg:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -40)
    row.fragBarBg:SetPoint("RIGHT", row, "RIGHT", -90, 0)
    row.fragBarBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

    row.fragBarFill = row:CreateTexture(nil, "ARTWORK")
    row.fragBarFill:SetHeight(8)
    row.fragBarFill:SetPoint("LEFT", row.fragBarBg, "LEFT", 0, 0)

    row.fragText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.fragText:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -51)

    row.solveBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.solveBtn:SetSize(70, 22)
    row.solveBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.solveBtn:SetText(L("ARCH_SOLVE"))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)

    local divider = row:CreateTexture(nil, "BACKGROUND")
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    divider:SetColorTexture(0.26, 0.36, 0.52, 0.45)

    pools.archRaceRows[index] = row
    return row
end

local function ScrollRecipeList(delta)
    local rows = BuildRecipeDisplayRows(state.currentRecipes or {})
    local maxOffset = math.max(0, #rows - GetVisibleRecipeRows())
    local currentOffset = FauxScrollFrame_GetOffset(ui.recipeScrollFrame) or 0
    local newOffset = math.max(0, math.min(maxOffset, currentOffset - delta))
    if newOffset ~= currentOffset then
        FauxScrollFrame_SetOffset(ui.recipeScrollFrame, newOffset)
        UpdateRecipeList(nil)
    end
end

local function ScrollArchList(delta)
    local races = state.archRaces or {}
    local maxOffset = math.max(0, #races - GetVisibleArchRows())
    local currentOffset = FauxScrollFrame_GetOffset(ui.archScrollFrame) or 0
    local newOffset = math.max(0, math.min(maxOffset, currentOffset - delta))
    if newOffset ~= currentOffset then
        FauxScrollFrame_SetOffset(ui.archScrollFrame, newOffset)
        UpdateArchaeologyView()
    end
end

UpdateArchaeologyView = function()
    for _, row in pairs(pools.archRaceRows) do
        row:Hide()
    end

    local races = state.archRaces or {}
    local visibleRows = GetVisibleArchRows()

    if #races == 0 then
        ui.archNoDataLabel:SetText(L("ARCH_NO_DATA"))
        ui.archNoDataLabel:Show()
        FauxScrollFrame_Update(ui.archScrollFrame, 0, visibleRows, constants.ARCH_ROW_HEIGHT)
        ui.summaryLabel:SetText("")
        return
    end

    ui.archNoDataLabel:Hide()

    local offset = FauxScrollFrame_GetOffset(ui.archScrollFrame) or 0
    local maxOffset = math.max(0, #races - visibleRows)
    if offset > maxOffset then
        offset = maxOffset
        FauxScrollFrame_SetOffset(ui.archScrollFrame, offset)
    end
    FauxScrollFrame_Update(ui.archScrollFrame, #races, visibleRows, constants.ARCH_ROW_HEIGHT)

    local solvable = 0
    for _, race in ipairs(races) do
        if race.canSolve then
            solvable = solvable + 1
        end
    end

    for i = 1, visibleRows do
        local race = races[i + offset]
        local row = GetOrCreateArchRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.archContainer, "TOPLEFT", 0, -((i - 1) * constants.ARCH_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", ui.archContainer, "TOPRIGHT", 0, -((i - 1) * constants.ARCH_ROW_HEIGHT))

        if race then
            row:Show()
            local stripe = (i % 2 == 0) and 0.16 or 0.10
            row.bg:SetColorTexture(stripe, stripe, stripe, 0.28)
            row.raceIcon:SetTexture(race.raceTexture)
            row.raceName:SetText(race.raceName)
            row.completed:SetText(L("ARCH_COMPLETED", race.numCompleted or 0))

            if race.artifactName and race.artifactName ~= "" then
                row.artName:SetText(race.artifactName)
                row.artName:SetTextColor(0.92, 0.82, 0.60)
            else
                row.artName:SetText(L("ARCH_NO_ARTIFACT"))
                row.artName:SetTextColor(0.55, 0.55, 0.55)
            end

            local req = race.numFragRequired or 0
            local used = race.numFragUsed or 0
            if req > 0 then
                row.fragBarBg:Show()
                row.fragBarFill:Show()
                row.fragText:Show()
                row.fragText:SetText(L("ARCH_FRAGMENTS", used, req))
                local pct = math.min(1.0, used / req)
                local barW = row.fragBarBg:GetWidth() or 1
                row.fragBarFill:SetWidth(math.max(1, barW * pct))
                if race.canSolve then
                    row.fragBarFill:SetColorTexture(0.35, 0.90, 0.35, 0.9)
                else
                    row.fragBarFill:SetColorTexture(0.82, 0.60, 0.20, 0.9)
                end
            else
                row.fragBarBg:Hide()
                row.fragBarFill:Hide()
                row.fragText:SetText("")
            end

            if race.canSolve then
                row.solveBtn:Show()
                row.solveBtn:Enable()
                row.solveBtn:SetScript("OnClick", function()
                    if InCombatLockdown and InCombatLockdown() then
                        print(L("ERR_PREFIX", L("ERR_COMBAT_LOCKDOWN")))
                        return
                    end
                    if C_Archaeology and C_Archaeology.SolveArtifact then
                        pcall(C_Archaeology.SolveArtifact)
                    elseif SolveArtifact then
                        pcall(SolveArtifact)
                    end
                    C_Timer.After(0.15, function()
                        state.archRaces = addon.LoadArchaeologyData()
                        UpdateArchaeologyView()
                    end)
                end)
            else
                row.solveBtn:Hide()
                row.solveBtn:SetScript("OnClick", nil)
            end
        else
            row:Hide()
        end
    end

    ui.summaryLabel:SetText(L("ARCH_SUMMARY", #races, solvable))
end

UpdateRecipeList = function(recipeErr)
    for _, row in pairs(pools.recipeRows) do
        row:Hide()
    end

    local visibleRows = GetVisibleRecipeRows()
    local expansionInfo = state.expansionData[state.selectedExpansion]
    local hasLearnedExpansionSkill = expansionInfo and expansionInfo.maxRank and expansionInfo.maxRank > 0

    if not hasLearnedExpansionSkill then
        ui.noRecipesLabel:SetText(L("EXPANSION_NOT_LEARNED"))
        ui.noRecipesLabel:Show()
        FauxScrollFrame_Update(ui.recipeScrollFrame, 0, visibleRows, constants.RECIPE_ROW_HEIGHT)
        return
    end

    if recipeErr then
        ui.noRecipesLabel:SetText(L("RECIPES_LOAD_ERROR", tostring(recipeErr)))
        ui.noRecipesLabel:Show()
        FauxScrollFrame_Update(ui.recipeScrollFrame, 0, visibleRows, constants.RECIPE_ROW_HEIGHT)
        return
    end

    if expansionInfo and expansionInfo.recipes == nil then
        ui.noRecipesLabel:SetText(L("LABEL_RECIPES_HINT"))
        ui.noRecipesLabel:Show()
        FauxScrollFrame_Update(ui.recipeScrollFrame, 0, visibleRows, constants.RECIPE_ROW_HEIGHT)
        return
    end

    local recipes = state.currentRecipes or {}
    if #recipes == 0 then
        ui.noRecipesLabel:SetText(L("NO_RECIPES"))
        ui.noRecipesLabel:Show()
        FauxScrollFrame_Update(ui.recipeScrollFrame, 0, visibleRows, constants.RECIPE_ROW_HEIGHT)
        return
    end

    ui.noRecipesLabel:Hide()

    local learnedCount = 0
    local unlearnedCount = 0
    local skillLockedCount = 0
    local unavailableCount = 0
    for _, recipe in ipairs(recipes) do
        if recipe.recipeState == "learned" then
            learnedCount = learnedCount + 1
        elseif recipe.recipeState == "skill-locked" then
            skillLockedCount = skillLockedCount + 1
        elseif recipe.recipeState == "unavailable" then
            unavailableCount = unavailableCount + 1
        else
            unlearnedCount = unlearnedCount + 1
        end
    end

    local displayRows = BuildRecipeDisplayRows(recipes)
    local offset = FauxScrollFrame_GetOffset(ui.recipeScrollFrame) or 0
    local maxOffset = math.max(0, #displayRows - visibleRows)
    if offset > maxOffset then
        offset = maxOffset
        FauxScrollFrame_SetOffset(ui.recipeScrollFrame, offset)
    end
    FauxScrollFrame_Update(ui.recipeScrollFrame, #displayRows, visibleRows, constants.RECIPE_ROW_HEIGHT)

    for i = 1, visibleRows do
        local entry = displayRows[i + offset]
        local row = GetOrCreateRecipeRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", ui.recipeListContainer, "TOPLEFT", 0, -((i - 1) * constants.RECIPE_ROW_HEIGHT))
        row:SetPoint("TOPRIGHT", ui.recipeListContainer, "TOPRIGHT", 0, -((i - 1) * constants.RECIPE_ROW_HEIGHT))

        if entry and entry.type == "header" then
            row:Show()
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.name:SetPoint("RIGHT", row, "RIGHT", -28, 0)
            row.name:SetText(entry.text)
            row.name:SetFontObject(GameFontHighlight)
            row.name:SetTextColor(1.0, 0.82, 0.00)

            row.status:SetText(entry.collapsed and "+" or "-")
            row.status:SetFontObject(GameFontHighlight)
            row.status:SetTextColor(1.0, 0.82, 0.00)
            row.status:Show()

            row.detail:SetText("")
            row.statusIcon:Hide()
            row.availableLabel:Hide()
            row.qtyDecBtn:Hide()
            row.qtyLabel:Hide()
            row.qtyIncBtn:Hide()
            row.craftBtn:Hide()
            row.bg:SetColorTexture(0.22, 0.18, 0.08, 0.28)

            row:SetScript("OnClick", function()
                ToggleCategoryCollapsed(entry.categoryKey)
                UpdateRecipeList(nil)
            end)
        elseif entry and entry.type == "recipe" then
            local recipe = entry.recipe
            local stripe = (i % 2 == 0) and 0.16 or 0.10
            row:Show()
            row.status:Hide()
            row.statusIcon:Show()
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -4)
            row.name:SetFontObject(GameFontHighlightSmall)
            row.name:SetText(recipe.name)
            row.name:SetTextColor(0.92, 0.92, 0.92)
            row.detail:SetText("")
            row:SetScript("OnClick", nil)

            if recipe.recipeState == "learned" then
                local numAvail = recipe.numAvailable or 0
                row.name:SetPoint("RIGHT", row, "RIGHT", -170, 0)
                row.detail:ClearAllPoints()
                row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
                row.detail:SetPoint("RIGHT", row, "RIGHT", -170, 0)
                row.statusIcon:SetColorTexture(0.35, 0.90, 0.35, 0.95)
                row.bg:SetColorTexture(stripe, stripe, stripe, 0.28)

                row.availableLabel:Show()
                row.qtyDecBtn:Show()
                row.qtyLabel:Show()
                row.qtyIncBtn:Show()
                row.craftBtn:Show()

                row.availableLabel:SetText("x" .. numAvail)
                if numAvail > 0 then
                    row.availableLabel:SetTextColor(0.35, 0.90, 0.35, 1)
                else
                    row.availableLabel:SetTextColor(0.55, 0.55, 0.55, 1)
                end

                row._quantity = 1
                row.qtyLabel:SetText("1")
                local maxQty = math.max(1, numAvail)

                row.qtyDecBtn:SetScript("OnClick", function()
                    if row._quantity > 1 then
                        row._quantity = row._quantity - 1
                        row.qtyLabel:SetText(tostring(row._quantity))
                    end
                end)

                row.qtyIncBtn:SetScript("OnClick", function()
                    if row._quantity < maxQty then
                        row._quantity = row._quantity + 1
                        row.qtyLabel:SetText(tostring(row._quantity))
                    end
                end)

                if numAvail > 0 and not recipe.disabled then
                    row.craftBtn:SetText(L("BUTTON_CRAFT"))
                    row.craftBtn:Enable()
                    row.qtyDecBtn:Enable()
                    row.qtyIncBtn:Enable()
                    row.craftBtn:SetScript("OnClick", function()
                        addon.CraftRecipeByID(recipe.recipeID, row._quantity)
                    end)
                else
                    row.craftBtn:SetText(L("BUTTON_CRAFT"))
                    row.craftBtn:Disable()
                    row.qtyDecBtn:Disable()
                    row.qtyIncBtn:Disable()
                    row.craftBtn:SetScript("OnClick", nil)
                end
            else
                row.name:SetPoint("RIGHT", row, "RIGHT", -64, 0)
                row.detail:ClearAllPoints()
                row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
                row.detail:SetPoint("RIGHT", row, "RIGHT", -64, 0)
                row.availableLabel:Hide()
                row.qtyDecBtn:Hide()
                row.qtyLabel:Hide()
                row.qtyIncBtn:Hide()
                row.craftBtn:Show()
                row.craftBtn:SetText(L("BUTTON_LOCKED"))
                row.craftBtn:Disable()
                row.craftBtn:SetScript("OnClick", nil)

                if recipe.recipeState == "skill-locked" then
                    row.statusIcon:SetColorTexture(1.0, 0.82, 0.0, 0.95)
                    row.bg:SetColorTexture(stripe, stripe, stripe, 0.28)
                    if recipe.unlockedRecipeLevel then
                        row.detail:SetText(L("LABEL_UNLOCKED_AT", recipe.unlockedRecipeLevel))
                    end
                elseif recipe.recipeState == "unavailable" then
                    row.statusIcon:SetColorTexture(0.88, 0.54, 0.54, 0.95)
                    row.bg:SetColorTexture(stripe, stripe, stripe, 0.28)
                    if recipe.disabledReason and recipe.disabledReason ~= "" then
                        row.detail:SetText(L("LABEL_DISABLED_REASON", recipe.disabledReason))
                    end
                else
                    row.statusIcon:SetColorTexture(0.74, 0.74, 0.74, 0.95)
                    row.bg:SetColorTexture(stripe, stripe, stripe, 0.28)
                end
            end
        else
            row:Hide()
        end
    end

    ui.summaryLabel:SetText(L("RECIPES_SUMMARY", #recipes, learnedCount, unlearnedCount, skillLockedCount, unavailableCount))
end

local function UpdateContentPanel(recipeErr)
    local prof = state.professions[state.selectedProfession]
    local isArch = IsArchaeologyProfessionSafe(prof)

    ui.recipeListContainer:SetShown(not isArch)
    ui.recipeScrollFrame:SetShown(not isArch)
    ui.archContainer:SetShown(isArch)
    ui.archScrollFrame:SetShown(isArch)

    if not prof then
        ui.contentIcon:SetTexture(nil)
        ui.contentTitle:SetText("")
        ui.contentExpansion:SetText("")
        ui.contentRank:SetText("")
        ui.contentBarFill:SetWidth(1)
        ui.summaryLabel:SetText(L("LABEL_RECIPES_HINT"))
        ui.openBtn:SetText(L("BUTTON_LOAD"))
        ui.openBtn:Disable()
        UpdateRecipeList(nil)
        return
    end

    ui.contentIcon:SetTexture(prof.texture)
    ui.contentTitle:SetText(prof.name)

    if isArch then
        ui.contentExpansion:SetText("")
        if (prof.maxRank or 0) > 0 then
            ui.contentRank:SetText(L("LABEL_SKILL", prof.rank or 0, prof.maxRank or 0))
            local pct = (prof.rank or 0) / (prof.maxRank or 1)
            local barWidth = ui.contentBarBg:GetWidth() * pct
            ui.contentBarFill:SetWidth(math.max(barWidth, 1))
        else
            ui.contentRank:SetText(L("LABEL_SKILL_NOT_LEARNED"))
            ui.contentBarFill:SetWidth(1)
        end
        ui.summaryLabel:SetText("")
        ui.openBtn:SetText(L("BUTTON_REFRESH"))
        ui.openBtn:Enable()
        UpdateArchaeologyView()
        return
    end

    local expansionInfo = state.expansionData[state.selectedExpansion]
    local rank = expansionInfo and expansionInfo.rank or 0
    local maxRank = expansionInfo and expansionInfo.maxRank or 0

    ui.contentExpansion:SetText(L("LABEL_EXPANSION", state.selectedExpansion))
    if maxRank > 0 then
        ui.contentRank:SetText(L("LABEL_SKILL", rank, maxRank))
        local pct = rank / maxRank
        local barWidth = ui.contentBarBg:GetWidth() * pct
        ui.contentBarFill:SetWidth(math.max(barWidth, 1))
    else
        ui.contentRank:SetText(L("LABEL_SKILL_NOT_LEARNED"))
        ui.contentBarFill:SetWidth(1)
    end

    if expansionInfo and expansionInfo.recipes ~= nil then
        ui.summaryLabel:SetText("")
    else
        ui.summaryLabel:SetText(L("LABEL_RECIPES_HINT"))
    end

    ui.openBtn:SetText(L("BUTTON_LOAD"))
    if (expansionInfo and expansionInfo.skillLineID) or (prof and prof.skillLine) then
        ui.openBtn:Enable()
    else
        ui.openBtn:Disable()
    end

    UpdateRecipeList(recipeErr)
end

local function UpdateExpansionTabs()
    local prof = state.professions[state.selectedProfession]
    local isArch = IsArchaeologyProfessionSafe(prof)

    if not ui.archLabel then
        ui.archLabel = ui.expansionTabsContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        ui.archLabel:SetPoint("TOP", ui.expansionTabsContainer, "TOP", 0, -14)
        ui.archLabel:SetPoint("LEFT", ui.expansionTabsContainer, "LEFT", 0, 0)
        ui.archLabel:SetPoint("RIGHT", ui.expansionTabsContainer, "RIGHT", 0, 0)
        ui.archLabel:SetJustifyH("CENTER")
        ui.archLabel:SetTextColor(0.92, 0.82, 0.60)
        ui.archLabel:Hide()
    end

    if isArch then
        for i = 1, #EXPANSION_ORDER do
            if pools.expansionTabs[i] then
                pools.expansionTabs[i]:Hide()
            end
        end
        ui.archLabel:SetText(L("ARCH_TAB_LABEL"))
        ui.archLabel:Show()
        return
    end

    ui.archLabel:Hide()

    for i, expansion in ipairs(EXPANSION_ORDER) do
        local btn = pools.expansionTabs[i]
        if not btn then
            btn = CreateListTabButton(ui.expansionTabsContainer, constants.EXPANSION_TAB_HEIGHT - 2)
            pools.expansionTabs[i] = btn
        end

        btn:Show()
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", ui.expansionTabsContainer, "TOPLEFT", 0, -(i - 1) * constants.EXPANSION_TAB_HEIGHT)
        btn:SetPoint("RIGHT", ui.expansionTabsContainer, "RIGHT", 0, 0)

        local info = state.expansionData[expansion]
        if info and info.maxRank and info.maxRank > 0 then
            btn.label:SetText(string.format("%s %d/%d", expansion, info.rank or 0, info.maxRank or 0))
            btn.label:SetTextColor(unpack(theme.textLearned))
        else
            btn.label:SetText(expansion)
            btn.label:SetTextColor(unpack(theme.textMuted))
        end

        btn:SetSelected(state.selectedExpansion == expansion)

        btn:SetScript("OnClick", function()
            state.selectedExpansion = expansion
            local recipeErr = addon.EnsureRecipesForExpansion(expansion, true)

            local selected = state.professions[state.selectedProfession]
            local cacheKey = GetProfessionCacheKey(selected)
            if cacheKey and state.professionStateCache[cacheKey] then
                state.professionStateCache[cacheKey].selectedExpansion = state.selectedExpansion
            end
            addon.SetStoredSelectedExpansion(cacheKey, state.selectedExpansion)

            UpdateExpansionTabs()
            UpdateContentPanel(recipeErr)
        end)
    end
end

SelectProfession = function(index)
    state.selectedProfession = index

    local selected = state.professions[index]

    if IsArchaeologyProfessionSafe(selected) then
        state.expansionData = {}
        state.selectedExpansion = EXPANSION_ORDER[1]
        state.currentRecipes = {}
        state.archRaces = addon.LoadArchaeologyData()

        for i, btn in ipairs(pools.professionTabs) do
            if btn.SetSelected then
                btn:SetSelected(i == index)
            end
        end

        addon.SetStoredSelectedProfession(index)
        UpdateExpansionTabs()
        UpdateContentPanel(nil)
        return
    end

    if selected then
        local cacheKey = GetProfessionCacheKey(selected)
        local cachedState = cacheKey and state.professionStateCache[cacheKey] or nil

        if cachedState and type(cachedState.expansionData) == "table" then
            state.expansionData = cachedState.expansionData
            state.selectedExpansion = cachedState.selectedExpansion
                or addon.GetStoredSelectedExpansion(cacheKey)
                or addon.GetFirstExpansion(state.expansionData)
        else
            state.expansionData = addon.BuildExpansionDataForProfession(selected)
            state.selectedExpansion = addon.GetStoredSelectedExpansion(cacheKey)
                or addon.GetFirstExpansion(state.expansionData)
            if cacheKey then
                state.professionStateCache[cacheKey] = {
                    expansionData = state.expansionData,
                    selectedExpansion = state.selectedExpansion,
                }
            end
        end

        if not state.expansionData[state.selectedExpansion] then
            state.selectedExpansion = addon.GetFirstExpansion(state.expansionData)
        end
    else
        state.expansionData = {}
        state.selectedExpansion = EXPANSION_ORDER[1]
    end

    state.currentRecipes = {}

    for i, btn in ipairs(pools.professionTabs) do
        if btn.SetSelected then
            btn:SetSelected(i == index)
        end
    end

    local recipeErr = addon.EnsureRecipesForExpansion(state.selectedExpansion, true)

    if selected then
        local cacheKey = GetProfessionCacheKey(selected)
        if cacheKey and state.professionStateCache[cacheKey] then
            state.professionStateCache[cacheKey].selectedExpansion = state.selectedExpansion
        end
        addon.SetStoredSelectedExpansion(cacheKey, state.selectedExpansion)
    end

    addon.SetStoredSelectedProfession(index)

    UpdateExpansionTabs()
    UpdateContentPanel(recipeErr)
end

local function UpdateProfessionTabs()
    for _, btn in ipairs(pools.professionTabs) do
        btn:Hide()
    end

    local count = #state.professions
    if count == 0 then
        return
    end

    local spacing = 4
    local available = ui.professionTabsContainer:GetWidth()
    local tabWidth = math.max(92, math.floor((available - (spacing * (count - 1))) / count))

    for i, prof in ipairs(state.professions) do
        local btn = pools.professionTabs[i]
        if not btn then
            btn = CreateListTabButton(ui.professionTabsContainer, 22)
            pools.professionTabs[i] = btn
        end

        btn:Show()
        btn:SetWidth(tabWidth)
        btn:ClearAllPoints()

        if i == 1 then
            btn:SetPoint("LEFT", ui.professionTabsContainer, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", pools.professionTabs[i - 1], "RIGHT", spacing, 0)
        end

        btn.label:SetText(prof.name)
        btn.label:SetTextColor(unpack(theme.textBright))

        btn:SetScript("OnClick", function()
            SelectProfession(i)
        end)

        btn:SetSelected(i == state.selectedProfession)
    end
end

function addon.RefreshProfessionWindow()
    state.professions = addon.CollectLearnedProfessions()
    state.selectedProfession = math.max(1, addon.GetStoredSelectedProfession() or state.selectedProfession)

    if #state.professions == 0 then
        ui.noProfsLabel:Show()
        ui.professionTabsBg:Hide()
        ui.expansionTabsBg:Hide()
        ui.contentBg:Hide()
        return
    end

    ui.noProfsLabel:Hide()
    ui.professionTabsBg:Show()
    ui.expansionTabsBg:Show()
    ui.contentBg:Show()

    if state.selectedProfession > #state.professions then
        state.selectedProfession = 1
    end

    UpdateProfessionTabs()
    SelectProfession(state.selectedProfession)
end

function addon.ToggleFrame()
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        addon.RefreshProfessionWindow()
        ui.frame:Show()
        ui.frame:Raise()

        local left = ui.frame:GetLeft()
        local right = ui.frame:GetRight()
        local top = ui.frame:GetTop()
        local bottom = ui.frame:GetBottom()
        if left and right and top and bottom then
            local parentWidth = UIParent:GetWidth() or 0
            local parentHeight = UIParent:GetHeight() or 0
            local isOutOfBounds = (right < 0) or (left > parentWidth) or (bottom < 0) or (top > parentHeight)
            if isOutOfBounds then
                ui.frame:ClearAllPoints()
                ui.frame:SetPoint("CENTER")
            end
        end
    end
end

function addon.PrintDiagnostics()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName)
    local shown = ui.frame and ui.frame:IsShown() or false
    local parent = ui.frame and ui.frame:GetParent() and ui.frame:GetParent():GetName() or "nil"
    local point, _, relPoint, x, y = ui.frame:GetPoint()
    local selectedProf = state.professions and state.professions[state.selectedProfession] or nil

    print(L("DIAG_HEADER"))
    print("  addonLoaded=" .. tostring(loaded))
    print("  frameShown=" .. tostring(shown))
    print("  frameParent=" .. tostring(parent))
    print("  framePoint=" .. tostring(point) .. ", rel=" .. tostring(relPoint) .. ", x=" .. tostring(x) .. ", y=" .. tostring(y))
    print("  professionsDetected=" .. tostring(#(state.professions or {})))
    print("  selectedProfession=" .. tostring(selectedProf and selectedProf.name or "nil") .. ", index=" .. tostring(state.selectedProfession))

    local detected = {}
    for expansion, info in pairs(state.expansionData or {}) do
        table.insert(detected, string.format("%s=%d/%d", expansion, info.rank or 0, info.maxRank or 0))
    end
    table.sort(detected)
    print("  expansionData=" .. ((#detected > 0 and table.concat(detected, "; ")) or "none"))
end

ui.frame = CreateFrame("Frame", "ProfessionUIFrame", UIParent, "BasicFrameTemplateWithInset")
ui.frame:SetSize(constants.FRAME_WIDTH, constants.FRAME_HEIGHT)
ui.frame:SetPoint("CENTER")
ui.frame:SetMovable(true)
ui.frame:EnableMouse(true)
ui.frame:RegisterForDrag("LeftButton")
ui.frame:SetScript("OnDragStart", ui.frame.StartMoving)
ui.frame:SetScript("OnDragStop", ui.frame.StopMovingOrSizing)
ui.frame:SetClampedToScreen(true)
ui.frame:Hide()
ui.frame.TitleText:SetText(L("FRAME_TITLE"))

ui.professionTabsBg = CreateFrame("Frame", nil, ui.frame, "BackdropTemplate")
ui.professionTabsBg:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 10, -30)
ui.professionTabsBg:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -10, -30)
ui.professionTabsBg:SetHeight(30)
ApplyPanelStyle(ui.professionTabsBg)

ui.professionTabsContainer = CreateFrame("Frame", nil, ui.professionTabsBg)
ui.professionTabsContainer:SetPoint("TOPLEFT", ui.professionTabsBg, "TOPLEFT", 6, -4)
ui.professionTabsContainer:SetPoint("TOPRIGHT", ui.professionTabsBg, "TOPRIGHT", -6, -4)
ui.professionTabsContainer:SetHeight(22)

ui.expansionTabsBg = CreateFrame("Frame", nil, ui.frame, "BackdropTemplate")
ui.expansionTabsBg:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 10, -66)
ui.expansionTabsBg:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 10, 44)
ui.expansionTabsBg:SetWidth(190)
ApplyPanelStyle(ui.expansionTabsBg)

ui.expansionTabsContainer = CreateFrame("Frame", nil, ui.expansionTabsBg)
ui.expansionTabsContainer:SetPoint("TOPLEFT", ui.expansionTabsBg, "TOPLEFT", 8, -8)
ui.expansionTabsContainer:SetPoint("TOPRIGHT", ui.expansionTabsBg, "TOPRIGHT", -8, -8)
ui.expansionTabsContainer:SetPoint("BOTTOM", ui.expansionTabsBg, "BOTTOM", 0, 8)

ui.contentBg = CreateFrame("Frame", nil, ui.frame, "BackdropTemplate")
ui.contentBg:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 208, -66)
ui.contentBg:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -10, 44)
ApplyPanelStyle(ui.contentBg)

ui.contentPanel = CreateFrame("Frame", nil, ui.contentBg)
ui.contentPanel:SetAllPoints(ui.contentBg)

ui.contentIcon = ui.contentPanel:CreateTexture(nil, "ARTWORK")
ui.contentIcon:SetSize(48, 48)
ui.contentIcon:SetPoint("TOPLEFT", ui.contentPanel, "TOPLEFT", 10, -10)

ui.contentTitle = ui.contentPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ui.contentTitle:SetPoint("TOPLEFT", ui.contentIcon, "TOPRIGHT", 8, -4)
ui.contentTitle:SetPoint("RIGHT", ui.contentPanel, "RIGHT", -10, 0)
ui.contentTitle:SetJustifyH("LEFT")

ui.contentExpansion = ui.contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ui.contentExpansion:SetPoint("TOPLEFT", ui.contentTitle, "BOTTOMLEFT", 0, -6)

ui.contentRank = ui.contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ui.contentRank:SetPoint("TOPLEFT", ui.contentExpansion, "BOTTOMLEFT", 0, -6)

ui.contentBarBg = ui.contentPanel:CreateTexture(nil, "BACKGROUND")
ui.contentBarBg:SetHeight(12)
ui.contentBarBg:SetPoint("TOPLEFT", ui.contentRank, "BOTTOMLEFT", 0, -8)
ui.contentBarBg:SetPoint("RIGHT", ui.contentPanel, "RIGHT", -120, 0)
ui.contentBarBg:SetColorTexture(0.15, 0.15, 0.15, 0.9)

ui.contentBarFill = ui.contentPanel:CreateTexture(nil, "ARTWORK")
ui.contentBarFill:SetHeight(12)
ui.contentBarFill:SetPoint("LEFT", ui.contentBarBg, "LEFT", 0, 0)
ui.contentBarFill:SetColorTexture(0.0, 0.7, 1.0, 0.85)

ui.summaryLabel = ui.contentPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
ui.summaryLabel:SetPoint("TOPLEFT", ui.contentBarBg, "BOTTOMLEFT", 0, -8)
ui.summaryLabel:SetPoint("RIGHT", ui.contentPanel, "RIGHT", -10, 0)
ui.summaryLabel:SetJustifyH("LEFT")
ui.summaryLabel:SetTextColor(unpack(theme.textMuted))

ui.openBtn = CreateFrame("Button", nil, ui.contentPanel, "GameMenuButtonTemplate")
ui.openBtn:SetSize(92, 24)
ui.openBtn:SetPoint("TOPRIGHT", ui.contentPanel, "TOPRIGHT", -8, -10)
ui.openBtn:SetText(L("BUTTON_LOAD"))

ui.recipeListContainer = CreateFrame("Frame", nil, ui.contentPanel)
ui.recipeListContainer:SetPoint("TOPLEFT", ui.summaryLabel, "BOTTOMLEFT", 0, -8)
ui.recipeListContainer:SetPoint("BOTTOMRIGHT", ui.contentPanel, "BOTTOMRIGHT", -30, 8)
ui.recipeListContainer:EnableMouseWheel(true)
ui.recipeListContainer:SetScript("OnMouseWheel", function(_, delta)
    ScrollRecipeList(delta)
end)

ui.recipeScrollFrame = CreateFrame("ScrollFrame", nil, ui.contentPanel, "FauxScrollFrameTemplate")
ui.recipeScrollFrame:SetPoint("TOPLEFT", ui.recipeListContainer, "TOPRIGHT", -8, 0)
ui.recipeScrollFrame:SetPoint("BOTTOMLEFT", ui.recipeListContainer, "BOTTOMRIGHT", -8, 0)
ui.recipeScrollFrame:EnableMouseWheel(true)
ui.recipeScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    ScrollRecipeList(delta)
end)
ui.recipeScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, constants.RECIPE_ROW_HEIGHT, function()
        UpdateRecipeList(nil)
    end)
end)

ui.archContainer = CreateFrame("Frame", nil, ui.contentPanel)
ui.archContainer:SetPoint("TOPLEFT", ui.summaryLabel, "BOTTOMLEFT", 0, -8)
ui.archContainer:SetPoint("BOTTOMRIGHT", ui.contentPanel, "BOTTOMRIGHT", -30, 8)
ui.archContainer:EnableMouseWheel(true)
ui.archContainer:SetScript("OnMouseWheel", function(_, delta)
    ScrollArchList(delta)
end)
ui.archContainer:Hide()

ui.archScrollFrame = CreateFrame("ScrollFrame", nil, ui.contentPanel, "FauxScrollFrameTemplate")
ui.archScrollFrame:SetPoint("TOPLEFT", ui.archContainer, "TOPRIGHT", -8, 0)
ui.archScrollFrame:SetPoint("BOTTOMLEFT", ui.archContainer, "BOTTOMRIGHT", -8, 0)
ui.archScrollFrame:EnableMouseWheel(true)
ui.archScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    ScrollArchList(delta)
end)
ui.archScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, constants.ARCH_ROW_HEIGHT, function()
        UpdateArchaeologyView()
    end)
end)
ui.archScrollFrame:Hide()

ui.noRecipesLabel = ui.recipeListContainer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
ui.noRecipesLabel:SetPoint("TOPLEFT", ui.recipeListContainer, "TOPLEFT", 4, -6)
ui.noRecipesLabel:SetText("")

ui.archNoDataLabel = ui.archContainer:CreateFontString(nil, "OVERLAY", "GameFontDisable")
ui.archNoDataLabel:SetPoint("TOPLEFT", ui.archContainer, "TOPLEFT", 4, -6)
ui.archNoDataLabel:SetText("")
ui.archNoDataLabel:Hide()

ui.refreshBtn = CreateFrame("Button", nil, ui.frame, "GameMenuButtonTemplate")
ui.refreshBtn:SetSize(90, 24)
ui.refreshBtn:SetPoint("BOTTOMLEFT", ui.frame, "BOTTOMLEFT", 10, 12)
ui.refreshBtn:SetText(L("BUTTON_REFRESH"))

ui.noProfsLabel = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ui.noProfsLabel:SetPoint("CENTER", ui.frame, "CENTER", 0, 0)
ui.noProfsLabel:SetText(L("NO_PROFESSIONS"))
ui.noProfsLabel:Hide()

ui.openBtn:SetScript("OnClick", function()
    local prof = state.professions[state.selectedProfession]
    if not prof then
        return
    end

    if IsArchaeologyProfessionSafe(prof) then
        state.archRaces = addon.LoadArchaeologyData()
        UpdateArchaeologyView()
        return
    end

    local previousExpansion = state.selectedExpansion
    local previousExpansionData = state.expansionData
    local rebuiltExpansionData = addon.LoadAllRecipesForProfession(prof)
    MergeCachedExpansionData(previousExpansionData, rebuiltExpansionData)
    state.expansionData = rebuiltExpansionData

    if not state.expansionData[previousExpansion] then
        state.selectedExpansion = addon.GetFirstExpansion(state.expansionData)
    end

    local cacheKey = GetProfessionCacheKey(prof)
    if cacheKey then
        state.professionStateCache[cacheKey] = {
            expansionData = state.expansionData,
            selectedExpansion = state.selectedExpansion,
        }
    end

    local selectedInfo = state.expansionData[state.selectedExpansion]
    local recipeErr = selectedInfo and selectedInfo.recipeError or nil
    if recipeErr then
        print(L("ERR_PREFIX", tostring(recipeErr)))
    end

    state.currentRecipes = (selectedInfo and selectedInfo.recipes) or {}
    UpdateExpansionTabs()
    UpdateContentPanel(recipeErr)
end)

ui.refreshBtn:SetScript("OnClick", addon.RefreshProfessionWindow)

SLASH_PROFESSIONUI1 = "/profui"
SLASH_PROFESSIONUI2 = "/profs"
SLASH_PROFESSIONUI3 = "/professionui"
SLASH_PROFESSIONUI4 = "/pui"
SlashCmdList["PROFESSIONUI"] = function()
    local ok, err = pcall(addon.ToggleFrame)
    if not ok then
        print(L("ERR_PREFIX", tostring(err)))
    end
end

SLASH_PROFESSIONUIDIAG1 = "/puidiag"
SlashCmdList["PROFESSIONUIDIAG"] = function()
    local ok, err = pcall(function()
        addon.RefreshProfessionWindow()
        ui.frame:Show()
        ui.frame:Raise()
        addon.PrintDiagnostics()
    end)
    if not ok then
        print(L("ERR_PREFIX", tostring(err)))
    end
end

SLASH_PROFESSIONUIRESETBTN1 = "/puiresetbtn"
SLASH_PROFESSIONUIRESETBTN2 = "/puireset"
SlashCmdList["PROFESSIONUIRESETBTN"] = function()
    local ok, err = pcall(ResetMinimapButtonPosition)
    if not ok then
        print(L("ERR_PREFIX", tostring(err)))
    end
end

-- ============================================================
-- Minimap Button
-- ============================================================
local minimapBtn
local DEFAULT_MINIMAP_ANGLE = 225

local function ForceMinimapButtonState()
    if not minimapBtn then
        return
    end

    minimapBtn:SetParent(UIParent)
    minimapBtn:SetFrameStrata("HIGH")
    minimapBtn:SetFrameLevel(8)
    minimapBtn:SetAlpha(1)
    minimapBtn:SetScale(1)
    if minimapBtn.SetIgnoreParentAlpha then
        minimapBtn:SetIgnoreParentAlpha(true)
    end
    minimapBtn:Show()
end

local function NormalizeMinimapAngle(angle)
    if type(angle) ~= "number" or angle ~= angle then
        return 315
    end
    local normalized = angle % 360
    if normalized < 0 then
        normalized = normalized + 360
    end
    return normalized
end

local function GetMinimapRadius()
    local w = Minimap and Minimap.GetWidth and Minimap:GetWidth() or nil
    if not w or w < 80 then
        -- During early load some UIs report width=0; use stable fallback radius.
        return 84
    end
    return (w / 2) + 14
end

local function UpdateMinimapPos(angle)
    local safeAngle = NormalizeMinimapAngle(angle)
    local rad = math.rad(safeAngle)
    local r = GetMinimapRadius()
    local x = math.cos(rad) * r
    local y = math.sin(rad) * r
    minimapBtn:ClearAllPoints()
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function IsMinimapButtonOffscreen()
    if not minimapBtn then
        return true
    end

    local x, y = minimapBtn:GetCenter()
    if not x or not y then
        return true
    end

    local w = UIParent:GetWidth() or 0
    local h = UIParent:GetHeight() or 0
    return x < 18 or x > (w - 18) or y < 18 or y > (h - 18)
end

local function EnsureMinimapButtonVisible()
    if type(ProfessionUIDB) ~= "table" then
        addon.GetDB()
    end

    if not minimapBtn then
        CreateMinimapButton()
    end

    ForceMinimapButtonState()

    if ProfessionUIDB.minimapAngle == nil then
        ProfessionUIDB.minimapAngle = DEFAULT_MINIMAP_ANGLE
    end

    local saved = NormalizeMinimapAngle(ProfessionUIDB.minimapAngle)
    ProfessionUIDB.minimapAngle = saved
    UpdateMinimapPos(saved)

    if IsMinimapButtonOffscreen() then
        ProfessionUIDB.minimapAngle = DEFAULT_MINIMAP_ANGLE
        UpdateMinimapPos(DEFAULT_MINIMAP_ANGLE)
    end

    ForceMinimapButtonState()
end

local function EnsureMinimapButtonVisibleWithRetry(attempt)
    attempt = attempt or 1
    EnsureMinimapButtonVisible()

    local cx, cy = Minimap:GetCenter()
    local w = Minimap and Minimap.GetWidth and Minimap:GetWidth() or 0
    local minimapReady = w and w >= 80 and cx and cy

    if (not minimapReady or IsMinimapButtonOffscreen()) and attempt < 12 and C_Timer and C_Timer.After then
        C_Timer.After(0.4, function()
            EnsureMinimapButtonVisibleWithRetry(attempt + 1)
        end)
    end
end

local function CreateMinimapButton()
    if minimapBtn and minimapBtn:IsObjectType("Button") then
        ForceMinimapButtonState()
        return
    end

    minimapBtn = CreateFrame("Button", "ProfessionUIMinimapButton", UIParent)
    minimapBtn:SetSize(31, 31)
    minimapBtn:SetFrameStrata("HIGH")
    minimapBtn:SetFrameLevel(8)
    minimapBtn:RegisterForDrag("LeftButton")
    minimapBtn:SetClampedToScreen(true)
    minimapBtn:SetHitRectInsets(0, 0, 0, 0)

    local background = minimapBtn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")

    local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = minimapBtn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local hl = minimapBtn:GetHighlightTexture()
    if hl then
        hl:SetSize(48, 48)
        hl:SetPoint("TOPLEFT", minimapBtn, "TOPLEFT", 2, -2)
        hl:SetBlendMode("ADD")
    end

    local savedAngle = NormalizeMinimapAngle((ProfessionUIDB and ProfessionUIDB.minimapAngle) or DEFAULT_MINIMAP_ANGLE)
    ProfessionUIDB.minimapAngle = savedAngle
    UpdateMinimapPos(savedAngle)

    minimapBtn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local mx, my = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            local a = math.deg(math.atan2((my / scale) - cy, (mx / scale) - cx))
            local safe = NormalizeMinimapAngle(a)
            ProfessionUIDB.minimapAngle = safe
            UpdateMinimapPos(safe)
        end)
    end)

    minimapBtn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    minimapBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            local ok, err = pcall(addon.ToggleFrame)
            if not ok then
                print(L("ERR_PREFIX", tostring(err)))
            end
        end
    end)

    minimapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ProfessionUI")
        GameTooltip:AddLine("Click to open/close", 1, 1, 1)
        GameTooltip:AddLine("Drag to reposition", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    minimapBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ForceMinimapButtonState()
end

ResetMinimapButtonPosition = function()
    if type(ProfessionUIDB) ~= "table" then
        addon.GetDB()
    end

    ProfessionUIDB.minimapAngle = DEFAULT_MINIMAP_ANGLE

    if not minimapBtn then
        CreateMinimapButton()
    end

    minimapBtn:Show()
    UpdateMinimapPos(ProfessionUIDB.minimapAngle)
    print("ProfessionUI: minimap button position reset.")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("NEW_RECIPE_LEARNED")
eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
eventFrame:RegisterEvent("ARTIFACT_COMPLETE")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        addon.GetDB()
        addon.RestoreWindowPosition(ui.frame)
        CreateMinimapButton()
        EnsureMinimapButtonVisibleWithRetry(1)
    elseif event == "PLAYER_LOGIN" then
        EnsureMinimapButtonVisibleWithRetry(1)
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, function()
                EnsureMinimapButtonVisibleWithRetry(1)
            end)
        end
        print(L("ADDON_LOADED"))
    elseif event == "PLAYER_ENTERING_WORLD" then
        EnsureMinimapButtonVisibleWithRetry(1)
        if C_Timer and C_Timer.After then
            C_Timer.After(1.5, function()
                EnsureMinimapButtonVisibleWithRetry(1)
            end)
            C_Timer.After(4.0, function()
                EnsureMinimapButtonVisibleWithRetry(1)
            end)
        end
    elseif event == "SKILL_LINES_CHANGED" then
        for _, cachedState in pairs(state.professionStateCache) do
            InvalidateRecipeCacheForExpansionData(cachedState.expansionData)
        end
        if ui.frame:IsShown() then
            addon.RefreshProfessionWindow()
        end
    elseif event == "ARTIFACT_COMPLETE" then
        if ui.frame:IsShown() then
            local selected = state.professions[state.selectedProfession]
            if IsArchaeologyProfessionSafe(selected) then
                state.archRaces = addon.LoadArchaeologyData()
                UpdateArchaeologyView()
            end
        end
    elseif event == "NEW_RECIPE_LEARNED" or event == "TRADE_SKILL_LIST_UPDATE" then
        local selected = state.professions[state.selectedProfession]
        local cacheKey = GetProfessionCacheKey(selected)
        local cachedState = cacheKey and state.professionStateCache[cacheKey] or nil
        if cachedState and type(cachedState.expansionData) == "table" then
            InvalidateRecipeCacheForExpansionData(cachedState.expansionData)
        end

        if ui.frame:IsShown() then
            SelectProfession(state.selectedProfession)
        end
    end
end)

local logoutFrame = CreateFrame("Frame")
logoutFrame:RegisterEvent("PLAYER_LOGOUT")
logoutFrame:SetScript("OnEvent", function()
    addon.SaveWindowPosition(ui.frame)
end)
