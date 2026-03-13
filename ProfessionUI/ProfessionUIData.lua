local _, addon = ...

local state = addon.state
local EXPANSION_ORDER = addon.expansionOrder
local EXPANSION_ALIASES = addon.expansionAliases
local L = addon.GetString

function addon.NormalizeExpansionName(name)
    if not name or name == "" then
        return nil
    end

    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "Unknown" then
        return nil
    end

    return EXPANSION_ALIASES[name] or name
end

function addon.ExtractExpansionName(line, parentName)
    if line.expansionName then
        return addon.NormalizeExpansionName(line.expansionName)
    end

    local lineName = line.professionName
    if not lineName or lineName == "" then
        return nil
    end

    return addon.NormalizeExpansionName(lineName)
end

function addon.OpenTradeSkillForLine(skillLineID)
    if not (skillLineID and C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then
        return false, L("ERR_MISSING_TRADE_SKILL")
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, L("ERR_COMBAT_LOCKDOWN")
    end

    local function IsRequestedLineAlreadyActive()
        local currentChildSkillLineID = C_TradeSkillUI.GetProfessionChildSkillLineID and C_TradeSkillUI.GetProfessionChildSkillLineID() or nil
        if currentChildSkillLineID and currentChildSkillLineID == skillLineID then
            return true
        end

        if C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetProfessionSkillLineID then
            local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
            local baseProfession = type(baseInfo) == "table" and baseInfo.profession or nil
            if baseProfession ~= nil then
                local okBase, baseSkillLineID = pcall(C_TradeSkillUI.GetProfessionSkillLineID, baseProfession)
                if okBase and baseSkillLineID == skillLineID then
                    return true
                end
            end
        end

        return false
    end

    local function FindSkillLineIDForProfessionID(professionID)
        if not (professionID and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID) then
            return nil
        end

        local lines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
        if type(lines) ~= "table" then
            return nil
        end

        for _, line in ipairs(lines) do
            if type(line) == "number" then
                local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(line)
                if type(info) == "table" and info.professionID == professionID and not info.parentProfessionID then
                    return line
                end
            end
        end

        return nil
    end

    local requestedInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID) or nil
    local isChildSkillLine = type(requestedInfo) == "table" and requestedInfo.parentProfessionID ~= nil

    if isChildSkillLine then
        local parentSkillLineID = FindSkillLineIDForProfessionID(requestedInfo.parentProfessionID)
        if parentSkillLineID then
            local okParent, openedParent = pcall(C_TradeSkillUI.OpenTradeSkill, parentSkillLineID)
            if not okParent then
                return false, openedParent
            end

            if C_TradeSkillUI.SetProfessionChildSkillLineID then
                local okChild, childErr = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, skillLineID)
                if not okChild then
                    return false, childErr
                end

                if IsRequestedLineAlreadyActive() then
                    return true, nil
                end
            end
        end
    end

    local ok, opened = pcall(C_TradeSkillUI.OpenTradeSkill, skillLineID)
    if not ok then
        return false, opened
    end

    if not opened then
        if IsRequestedLineAlreadyActive() then
            return true, nil
        end

        if type(requestedInfo) == "table" and requestedInfo.parentProfessionID and C_TradeSkillUI.SetProfessionChildSkillLineID then
            local setOk, setErr = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, skillLineID)
            if not setOk then
                return false, setErr
            end

            if IsRequestedLineAlreadyActive() then
                return true, nil
            end
        end

        if type(requestedInfo) == "table" and requestedInfo.parentProfessionID and C_TradeSkillUI.GetBaseProfessionInfo then
            local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
            if type(baseInfo) == "table" and baseInfo.professionID == requestedInfo.parentProfessionID then
                if C_TradeSkillUI.SetProfessionChildSkillLineID then
                    local setOk, setErr = pcall(C_TradeSkillUI.SetProfessionChildSkillLineID, skillLineID)
                    if not setOk then
                        return false, setErr
                    end

                    if IsRequestedLineAlreadyActive() then
                        return true, nil
                    end
                end
            end
        end

        return false, L("ERR_MISSING_TRADE_SKILL")
    end

    return true, nil
end

function addon.CollectLearnedProfessions()
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    local profs = {}

    for slotIndex, profIndex in ipairs({ prof1, prof2 }) do
        if profIndex then
            local name, texture, rank, maxRank, _, _, skillLine = GetProfessionInfo(profIndex)
            if name then
                table.insert(profs, {
                    name = name,
                    texture = texture,
                    rank = rank or 0,
                    maxRank = maxRank or 0,
                    profIndex = profIndex,
                    skillLine = skillLine,
                    sortOrder = slotIndex,
                    cacheKey = "primary:" .. tostring(slotIndex),
                })
            end
        end
    end

    local secondaryProfessions = {
        {
            profIndex = cooking,
            fallbackName = "Cooking",
            fallbackTexture = "Interface\\Icons\\INV_Misc_Food_15",
            fallbackSkillLine = 185,
            sortOrder = 3,
            cacheKey = "secondary:cooking",
        },
        {
            profIndex = fishing,
            fallbackName = "Fishing",
            fallbackTexture = "Interface\\Icons\\Trade_Fishing",
            fallbackSkillLine = 356,
            sortOrder = 4,
            cacheKey = "secondary:fishing",
        },
        {
            profIndex = archaeology,
            fallbackName = "Archaeology",
            fallbackTexture = "Interface\\Icons\\Trade_Archaeology",
            fallbackSkillLine = 794,
            sortOrder = 5,
            cacheKey = "secondary:archaeology",
        },
    }

    for _, secondary in ipairs(secondaryProfessions) do
        local name, texture, rank, maxRank, _, _, skillLine
        if secondary.profIndex then
            name, texture, rank, maxRank, _, _, skillLine = GetProfessionInfo(secondary.profIndex)
        end

        table.insert(profs, {
            name = name or secondary.fallbackName,
            texture = texture or secondary.fallbackTexture,
            rank = rank or 0,
            maxRank = maxRank or 0,
            profIndex = secondary.profIndex,
            skillLine = skillLine or secondary.fallbackSkillLine,
            sortOrder = secondary.sortOrder,
            cacheKey = secondary.cacheKey,
        })
    end

    table.sort(profs, function(a, b)
        return (a.sortOrder or 999) < (b.sortOrder or 999)
    end)

    return profs
end

function addon.BuildExpansionDataForProfession(prof)
    local data = {}

    local function UpsertExpansionData(expansion, rank, maxRank, skillLineID)
        if not expansion then
            return
        end

        local newRank = rank or 0
        local newMaxRank = maxRank or 0
        local existing = data[expansion]

        if not existing then
            data[expansion] = {
                rank = newRank,
                maxRank = newMaxRank,
                skillLineID = skillLineID,
                recipes = nil,
                recipeError = nil,
            }
            return
        end

        if newMaxRank > (existing.maxRank or 0) then
            existing.rank = newRank
            existing.maxRank = newMaxRank
        end

        if skillLineID and not existing.skillLineID then
            existing.skillLineID = skillLineID
        end
    end

    local function MatchesSelectedProfession(info)
        if type(info) ~= "table" then
            return false
        end

        if prof.name and info.professionName == prof.name then
            return true
        end

        if prof.skillLine and info.professionID and info.professionID == prof.skillLine then
            return true
        end

        return false
    end

    local function MatchesParentProfession(info)
        if type(info) ~= "table" then
            return false
        end

        if prof.name and info.parentProfessionName and info.parentProfessionName == prof.name then
            return true
        end

        if prof.skillLine and info.parentProfessionID and info.parentProfessionID == prof.skillLine then
            return true
        end

        return false
    end

    local function AddProfessionInfo(info, skillLineID)
        if type(info) ~= "table" then
            return false
        end

        local expansion = addon.ExtractExpansionName(info, info.parentProfessionName or prof.name)
        if not expansion then
            return false
        end

        UpsertExpansionData(expansion, info.skillLevel, info.maxSkillLevel, skillLineID or info.professionID)
        return true
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local lines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
        if type(lines) == "table" then
            for _, line in ipairs(lines) do
                local lineSkillLineID = type(line) == "number" and line or nil
                local lineInfo = lineSkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(lineSkillLineID) or nil
                if type(lineInfo) == "table" then
                    if MatchesSelectedProfession(lineInfo) or MatchesParentProfession(lineInfo) then
                        AddProfessionInfo(lineInfo, lineSkillLineID)
                    end
                end
            end
        end
    end

    if not next(data) and C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetChildProfessionInfos then
        local baseInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if MatchesSelectedProfession(baseInfo) then
            AddProfessionInfo(baseInfo, prof.skillLine)

            local childInfo = C_TradeSkillUI.GetChildProfessionInfo and C_TradeSkillUI.GetChildProfessionInfo() or nil
            if type(childInfo) == "table" and MatchesParentProfession(childInfo) then
                AddProfessionInfo(childInfo)
            end

            local children = C_TradeSkillUI.GetChildProfessionInfos()
            if type(children) == "table" then
                for _, child in ipairs(children) do
                    if MatchesParentProfession(child) then
                        AddProfessionInfo(child)
                    end
                end
            end
        end
    end

    if not next(data) then
        data["Classic"] = {
            rank = prof.rank or 0,
            maxRank = prof.maxRank or 0,
            skillLineID = prof.skillLine,
            recipes = nil,
            recipeError = nil,
        }
    end

    return data
end

function addon.GetFirstExpansion(expansionData)
    for _, expansion in ipairs(EXPANSION_ORDER) do
        if expansionData[expansion] then
            return expansion
        end
    end

    return EXPANSION_ORDER[1]
end

local function ClassifyRecipeState(recipeInfo, expansionRank)
    if recipeInfo.learned then
        return "learned"
    end

    if recipeInfo.unlockedRecipeLevel and recipeInfo.unlockedRecipeLevel > (expansionRank or 0) then
        return "skill-locked"
    end

    if recipeInfo.disabled then
        return "unavailable"
    end

    return "unlearned"
end

local function GetRecipeCategoryMetadata(categoryID)
    if not (categoryID and C_TradeSkillUI and C_TradeSkillUI.GetCategoryInfo) then
        return "uncategorized", "Uncategorized", "uncategorized"
    end

    local names = {}
    local ids = {}
    local currentID = categoryID
    local safety = 0

    while currentID and safety < 25 do
        safety = safety + 1
        local info = C_TradeSkillUI.GetCategoryInfo(currentID)
        if type(info) ~= "table" then
            break
        end

        if info.name and info.name ~= "" then
            table.insert(names, 1, info.name)
        end
        table.insert(ids, 1, tostring(currentID))
        currentID = info.parentCategoryID
    end

    if #names == 0 then
        return "uncategorized", "Uncategorized", "uncategorized"
    end

    local top = names[1]
    local leaf = names[#names]
    local label = (top ~= leaf) and (top .. " - " .. leaf) or leaf
    local key = table.concat(ids, ">")
    local sortKey = string.lower(label)
    return key, label, sortKey
end

function addon.LoadRecipesForSkillLine(skillLineID, expansionRank)
    local recipes = {}

    local opened, openErr = addon.OpenTradeSkillForLine(skillLineID)
    if not opened then
        return recipes, openErr
    end

    if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then
        return recipes, L("ERR_RECIPES_UNAVAILABLE")
    end

    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if type(recipeIDs) ~= "table" then
        return recipes, L("ERR_NO_RECIPE_DATA")
    end

    for _, recipeID in ipairs(recipeIDs) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        local recipeMatchesSkillLine = C_TradeSkillUI.IsRecipeInSkillLine and C_TradeSkillUI.IsRecipeInSkillLine(recipeID, skillLineID)
        if info and info.name and info.name ~= "" and recipeMatchesSkillLine then
            local stateKey = ClassifyRecipeState(info, expansionRank)
            local categoryKey, categoryLabel, categorySortKey = GetRecipeCategoryMetadata(info.categoryID)
            table.insert(recipes, {
                recipeID = recipeID,
                name = info.name,
                learned = info.learned and true or false,
                numSkillUps = info.numSkillUps or 0,
                numAvailable = info.numAvailable or 0,
                craftable = info.craftable and true or false,
                canSkillUp = info.canSkillUp and true or false,
                disabled = info.disabled and true or false,
                disabledReason = info.disabledReason,
                unlockedRecipeLevel = info.unlockedRecipeLevel,
                relativeDifficulty = info.relativeDifficulty,
                recipeState = stateKey,
                categoryID = info.categoryID,
                categoryKey = categoryKey,
                categoryLabel = categoryLabel,
                categorySortKey = categorySortKey,
            })
        end
    end

    table.sort(recipes, function(a, b)
        local stateOrder = {
            ["learned"] = 1,
            ["unlearned"] = 2,
            ["skill-locked"] = 3,
            ["unavailable"] = 4,
        }

        local aCategory = a.categorySortKey or "zz"
        local bCategory = b.categorySortKey or "zz"
        if aCategory ~= bCategory then
            return aCategory < bCategory
        end

        local aOrder = stateOrder[a.recipeState] or 99
        local bOrder = stateOrder[b.recipeState] or 99
        if aOrder ~= bOrder then
            return aOrder < bOrder
        end

        return a.name < b.name
    end)

    return recipes, nil
end

function addon.LoadAllRecipesForProfession(prof)
    local expansionData = addon.BuildExpansionDataForProfession(prof)

    for _, expansion in ipairs(EXPANSION_ORDER) do
        local info = expansionData[expansion]
        if info then
            if info.skillLineID and (info.maxRank or 0) > 0 then
                local recipes, recipeErr = addon.LoadRecipesForSkillLine(info.skillLineID, info.rank or 0)
                info.recipes = recipes
                info.recipeError = recipeErr
            else
                info.recipes = {}
                info.recipeError = nil
            end
        end
    end

    return expansionData
end

function addon.EnsureRecipesForExpansion(expansion, allowOpenTradeSkill)
    local expansionInfo = state.expansionData[expansion]
    if not expansionInfo then
        state.currentRecipes = {}
        return nil
    end

    if expansionInfo.recipes then
        state.currentRecipes = expansionInfo.recipes
        return expansionInfo.recipeError
    end

    if not expansionInfo.skillLineID then
        expansionInfo.recipes = {}
        expansionInfo.recipeError = nil
        state.currentRecipes = expansionInfo.recipes
        return nil
    end

    if not allowOpenTradeSkill then
        state.currentRecipes = {}
        return nil
    end

    if (expansionInfo.maxRank or 0) == 0 then
        expansionInfo.recipes = {}
        expansionInfo.recipeError = nil
        state.currentRecipes = expansionInfo.recipes
        return nil
    end

    local recipes, recipeErr = addon.LoadRecipesForSkillLine(expansionInfo.skillLineID, expansionInfo.rank or 0)
    expansionInfo.recipes = recipes
    expansionInfo.recipeError = recipeErr
    state.currentRecipes = recipes
    return recipeErr
end

function addon.CraftRecipeByID(recipeID, quantity)
    if not (recipeID and C_TradeSkillUI and C_TradeSkillUI.CraftRecipe) then
        print(L("ERR_PREFIX", L("ERR_CRAFT_API")))
        return
    end

    local expansionInfo = state.expansionData[state.selectedExpansion]
    if expansionInfo and expansionInfo.skillLineID then
        local opened, openErr = addon.OpenTradeSkillForLine(expansionInfo.skillLineID)
        if not opened then
            print(L("ERR_PREFIX", tostring(openErr)))
            return
        end
    end

    local ok, err = pcall(C_TradeSkillUI.CraftRecipe, recipeID, math.max(1, tonumber(quantity) or 1))
    if not ok then
        print(L("ERR_CRAFT", tostring(err)))
    end
end

function addon.IsArchaeologyProfession(prof)
    if not prof then
        return false
    end
    if prof.name and prof.name:lower() == "archaeology" then
        return true
    end
    if (prof.skillLine or 0) == 794 then
        return true
    end
    return false
end

function addon.LoadArchaeologyData()
    local races = {}
    local numRaces = 0

    if C_Archaeology and C_Archaeology.GetNumRaces then
        local ok, n = pcall(C_Archaeology.GetNumRaces)
        if ok and type(n) == "number" then
            numRaces = n
        end
    end
    if numRaces == 0 and GetNumArchaeologyRaces then
        local ok, n = pcall(GetNumArchaeologyRaces)
        if ok and type(n) == "number" then
            numRaces = n
        end
    end

    for i = 1, numRaces do
        local raceName, raceTexture, numCompleted, raceItemID

        if GetArchaeologyRaceInfo then
            local ok, a, b, c, d = pcall(GetArchaeologyRaceInfo, i)
            if ok then
                raceName, raceTexture, numCompleted, raceItemID = a, b, c, d
            end
        end

        if raceName and raceName ~= "" then
            local artifactName, artifactTex, numFragRequired, numFragUsed, numSockets

            if GetActiveArtifactByRace then
                -- Returns: name, description, uniqueness, rarity, icon, fragsRequired, fragsUsed, sockets
                local ok, a, _, _, _, e, f, g, h = pcall(GetActiveArtifactByRace, i)
                if ok then
                    artifactName = a
                    artifactTex = e
                    numFragRequired = f
                    numFragUsed = g
                    numSockets = h
                end
            end

            numFragRequired = numFragRequired or 0
            numFragUsed = numFragUsed or 0

            table.insert(races, {
                raceIndex = i,
                raceName = raceName,
                raceTexture = raceTexture,
                numCompleted = numCompleted or 0,
                raceItemID = raceItemID,
                artifactName = artifactName or "",
                artifactTex = artifactTex,
                numFragRequired = numFragRequired,
                numFragUsed = numFragUsed,
                numSockets = numSockets or 0,
                canSolve = numFragRequired > 0 and numFragUsed >= numFragRequired,
            })
        end
    end

    return races
end
