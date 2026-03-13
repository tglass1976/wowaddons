local ADDON_NAME = ...
local TRADEGOODS_CLASS_ID = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or LE_ITEM_CLASS_TRADEGOODS

-- Master catalog of tracked crafting material item IDs.
-- Items in this list that are not in your Warband Bank show greyed out.
-- Items found in the bank but not here are added to the catalog dynamically.
-- Add new expansion items here as they become available in-game.
local TRACKED_MATERIAL_ITEM_IDS = {
    -- ================== CLOTH ==================
    2589,   -- Linen Cloth (Classic)
    2592,   -- Wool Cloth (Classic)
    4306,   -- Silk Cloth (Classic)
    4338,   -- Mageweave Cloth (Classic)
    14047,  -- Runecloth (Classic)
    21877,  -- Netherweave Cloth (TBC)
    33470,  -- Frostweave Cloth (WotLK)
    53010,  -- Embersilk Cloth (Cata)
    72988,  -- Windwool Cloth (MoP)
    111557, -- Sumptuous Fur (WoD)
    124437, -- Shal'dorei Silk (Legion)
    152576, -- Tidespray Linen (BfA)
    167738, -- Gilded Seaweave (BfA 8.3)
    173202, -- Shrouded Cloth (Shadowlands)
    193922, -- Wildercloth (Dragonflight)
    -- The War Within cloth discovered dynamically via bank scan

    -- ================== HERBS ==================
    -- Classic
    765,    -- Silverleaf
    785,    -- Mageroyal
    2447,   -- Peacebloom
    2450,   -- Briarthorn
    2452,   -- Swiftthistle
    2453,   -- Bruiseweed
    3355,   -- Wild Steelbloom
    3356,   -- Kingsblood
    3357,   -- Liferoot
    3358,   -- Khadgar's Whisker
    3818,   -- Fadeleaf
    3821,   -- Goldthorn
    6924,   -- Firebloom
    8831,   -- Purple Lotus
    8836,   -- Arthas' Tears
    8838,   -- Sungrass
    8839,   -- Blindweed
    8845,   -- Ghost Mushroom
    8846,   -- Gromsblood
    13463,  -- Dreamfoil
    13464,  -- Golden Sansam
    13466,  -- Sorrowmoss
    13467,  -- Icecap
    13468,  -- Black Lotus
    -- The Burning Crusade
    22785,  -- Felweed
    22786,  -- Dreaming Glory
    22787,  -- Ragveil
    22789,  -- Terocone
    22790,  -- Ancient Lichen
    22792,  -- Nightmare Vine
    22793,  -- Mana Thistle
    22794,  -- Fel Lotus
    -- Wrath of the Lich King
    36901,  -- Goldclover
    36903,  -- Adder's Tongue
    36904,  -- Tiger Lily
    36905,  -- Lichbloom
    36906,  -- Icethorn
    36907,  -- Talandra's Rose
    36908,  -- Frost Lotus
    -- Cataclysm
    52983,  -- Cinderbloom
    52984,  -- Stormvine
    52985,  -- Azshara's Veil
    52986,  -- Heartblossom
    52987,  -- Twilight Jasmine
    52988,  -- Whiptail
    -- Mists of Pandaria
    72234,  -- Green Tea Leaf
    72235,  -- Silkweed
    72237,  -- Rain Poppy
    79010,  -- Snow Lily
    79011,  -- Fool's Cap
    -- Warlords of Draenor
    109124, -- Frostweed
    109125, -- Fireweed
    109126, -- Gorgrond Flytrap
    109127, -- Starflower
    109128, -- Nagrand Arrowbloom
    109129, -- Talador Orchid
    -- Legion
    124101, -- Aethril
    124102, -- Dreamleaf
    124103, -- Foxflower
    124104, -- Fjarnskaggl
    124105, -- Starlight Rose
    128304, -- Felwort
    -- Battle for Azeroth
    152505, -- Riverbud
    152506, -- Star Moss
    152507, -- Akunda's Bite
    152508, -- Winter's Kiss
    152509, -- Siren's Pollen
    152510, -- Anchor Weed
    152511, -- Sea Stalk
    168487, -- Zin'anthid
    -- Shadowlands
    168583, -- Widowbloom
    168586, -- Rising Glory
    169699, -- Vigil's Torch Petal
    169700, -- Death Blossom Petal
    169701, -- Death Blossom
    -- Dragonflight
    191460, -- Hochenblume
    191461, -- Hochenblume (quality variant)
    191462, -- Hochenblume (quality variant)
    194255, -- Abyssal Lotus
    -- Dragonflight herb quality variants and other herbs are discovered dynamically via bank scan
    -- The War Within: herbs discovered dynamically via bank scan

    -- ================== ORES / METALS ==================
    -- Classic
    2770,   -- Copper Ore
    2771,   -- Tin Ore
    2772,   -- Iron Ore
    2775,   -- Silver Ore
    2776,   -- Gold Ore
    3858,   -- Mithril Ore
    7911,   -- Truesilver Ore
    10620,  -- Thorium Ore
    -- The Burning Crusade
    23424,  -- Fel Iron Ore
    23425,  -- Adamantite Ore
    23426,  -- Eternium Ore
    23427,  -- Khorium Ore
    -- Wrath of the Lich King
    36909,  -- Cobalt Ore
    36910,  -- Titanium Ore
    36912,  -- Saronite Ore
    -- Cataclysm
    52183,  -- Pyrite Ore
    52185,  -- Elementium Ore
    52186,  -- Elementium Bar
    -- Mists of Pandaria
    72092,  -- Ghost Iron Ore
    72093,  -- Kyparite
    72094,  -- Black Trillium Ore
    72095,  -- Trillium Bar
    -- Warlords of Draenor
    109118, -- True Iron Ore
    109119, -- Blackrock Ore
    -- Legion
    123915, -- Leystone Ore
    -- BfA through TWW: ores discovered dynamically via bank scan

    -- ================== LEATHER ==================
    -- Classic
    2318,   -- Light Leather
    2319,   -- Medium Leather
    4234,   -- Heavy Leather
    4304,   -- Thick Leather
    8170,   -- Rugged Leather
    -- The Burning Crusade
    21887,  -- Knothide Leather
    -- Wrath of the Lich King
    33568,  -- Borean Leather
    -- Cataclysm
    52976,  -- Savage Leather
    -- Mists of Pandaria
    72436,  -- Exotic Leather
    -- WoD through TWW: leather discovered dynamically via bank scan
}

-- Some legacy items occasionally report surprising expansion IDs in GetItemInfo.
-- Keep explicit overrides for high-confidence catalog items.
local EXPANSION_OVERRIDES = {
    [13468] = "Classic", -- Black Lotus
    [6924]  = "Classic", -- Firebloom (slow to cache in modern client)
}

BankMatsViewerDB = BankMatsViewerDB or {}

local state = {
    bankOpen = false,
    warbandBagIDs = {},
    items = {},
    totalItemTypes = 0,
    totalCount = 0,
    lastScan = 0,
    showUnowned = true,
    collapsedExpansions = {},
}

local EXPANSION_NAMES = {
    [0] = "Classic",
    [1] = "The Burning Crusade",
    [2] = "Wrath of the Lich King",
    [3] = "Cataclysm",
    [4] = "Mists of Pandaria",
    [5] = "Warlords of Draenor",
    [6] = "Legion",
    [7] = "Battle for Azeroth",
    [8] = "Shadowlands",
    [9] = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
    [12] = "Midnight",
}

local EXPANSION_SORT = {
    ["Midnight"] = 1,
    ["The War Within"] = 2,
    ["Dragonflight"] = 3,
    ["Shadowlands"] = 4,
    ["Battle for Azeroth"] = 5,
    ["Legion"] = 6,
    ["Warlords of Draenor"] = 7,
    ["Mists of Pandaria"] = 8,
    ["Cataclysm"] = 9,
    ["Wrath of the Lich King"] = 10,
    ["The Burning Crusade"] = 11,
    ["Classic"] = 12,
    ["Unknown"] = 99,
}

local EXPANSION_SECTION_ORDER = {
    "Midnight",
    "The War Within",
    "Dragonflight",
    "Shadowlands",
    "Battle for Azeroth",
    "Legion",
    "Warlords of Draenor",
    "Mists of Pandaria",
    "Cataclysm",
    "Wrath of the Lich King",
    "The Burning Crusade",
    "Classic",
    "Unknown",
}

local QUALITY_LABELS = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
}

local QUALITY_SORT = {
    ["Poor"] = 1,
    ["Common"] = 2,
    ["Uncommon"] = 3,
    ["Rare"] = 4,
    ["Epic"] = 5,
    ["Legendary"] = 6,
    ["Unknown"] = 7,
}

local MATERIAL_SORT = {
    ["Cloth"] = 1,
    ["Herbs"] = 2,
    ["Metals and Stone"] = 3,
    ["Leather"] = 4,
    ["Enchantment"] = 5,
    ["Pigments and Ink"] = 6,
    ["Gems"] = 7,
    ["Parts"] = 8,
    ["Elemental"] = 9,
    ["Cooking"] = 10,
    ["Other Reagents"] = 11,
}

local ui = {
    frame = nil,
    summaryText = nil,
    showUnownedCheck = nil,
    showUnownedLabel = nil,
    expandAllButton = nil,
    collapseAllButton = nil,
    scrollFrame = nil,
    content = nil,
    itemButtons = {},
    groupHeaders = {},
    expansionHeaders = {},
    separators = {},
}

local TRACKED_MATERIAL_ITEM_ID_LOOKUP = {}
for _, itemID in ipairs(TRACKED_MATERIAL_ITEM_IDS) do
    TRACKED_MATERIAL_ITEM_ID_LOOKUP[itemID] = true
end

local function getItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then
        return name
    end

    local fallbackName, link = GetItemInfo(itemID)
    if fallbackName and fallbackName ~= "" then
        return fallbackName
    end

    if link and link ~= "" then
        return link
    end

    return "item:" .. tostring(itemID)
end

local function getItemIcon(itemID)
    local icon = C_Item.GetItemIconByID(itemID)
    if icon and icon > 0 then
        return icon
    end

    local _, _, _, _, iconFromInfo = GetItemInfoInstant(itemID)
    return iconFromInfo or 134400
end

local function isCraftingMaterial(itemID, bagID, slotID)
    if not itemID then
        return false
    end

    if C_Item and C_Item.IsCraftingReagentItem and ItemLocation then
        local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
        if location and location:IsValid() and C_Item.IsCraftingReagentItem(location) then
            return true
        end
    end

    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    return TRADEGOODS_CLASS_ID and classID == TRADEGOODS_CLASS_ID
end

local function getWarbandBagIDs()
    local ids = {}
    local seen = {}

    if Enum and Enum.BagIndex then
        for key, value in pairs(Enum.BagIndex) do
            if type(key) == "string" and type(value) == "number" and string.find(key, "AccountBankTab_") == 1 then
                if not seen[value] then
                    ids[#ids + 1] = value
                    seen[value] = true
                end
            end
        end
    end

    if #ids == 0 then
        -- Fallback for clients where bag constants are not exposed.
        for bagID = 13, 17 do
            ids[#ids + 1] = bagID
        end
    end

    table.sort(ids)
    return ids
end

local function clearScan()
    wipe(state.items)
    state.totalItemTypes = 0
    state.totalCount = 0
end

local function addItem(itemID, count)
    if not state.items[itemID] then
        state.items[itemID] = 0
        state.totalItemTypes = state.totalItemTypes + 1
    end

    state.items[itemID] = state.items[itemID] + count
    state.totalCount = state.totalCount + count
end

local function persistScan()
    BankMatsViewerDB.items = {}
    BankMatsViewerDB.catalogItemIDs = BankMatsViewerDB.catalogItemIDs or {}

    for itemID, count in pairs(state.items) do
        BankMatsViewerDB.items[itemID] = count
        BankMatsViewerDB.catalogItemIDs[itemID] = true
    end

    BankMatsViewerDB.totalItemTypes = state.totalItemTypes
    BankMatsViewerDB.totalCount = state.totalCount
    BankMatsViewerDB.lastScan = state.lastScan
end

local function classifyItem(itemID)
    local _, _, itemSubType, _, _, classID, subClassID = GetItemInfoInstant(itemID)

    if classID ~= TRADEGOODS_CLASS_ID then
        return "Other Reagents", "Multi-Profession"
    end

    if subClassID == LE_ITEM_TRADEGOODS_HERB then
        return "Herbs", "Multi-Profession"
    end
    if subClassID == LE_ITEM_TRADEGOODS_METAL_AND_STONE then
        return "Metals and Stone", "Multi-Profession"
    end
    if subClassID == LE_ITEM_TRADEGOODS_LEATHER then
        return "Leather", "Leatherworking"
    end
    if subClassID == LE_ITEM_TRADEGOODS_CLOTH then
        return "Cloth", "Tailoring"
    end
    if subClassID == LE_ITEM_TRADEGOODS_ENCHANTING then
        return "Enchantment", "Enchanting"
    end
    if subClassID == LE_ITEM_TRADEGOODS_INSCRIPTION then
        return "Pigments and Ink", "Inscription"
    end
    if subClassID == LE_ITEM_TRADEGOODS_JEWELCRAFTING then
        return "Gems", "Jewelcrafting"
    end
    if subClassID == LE_ITEM_TRADEGOODS_PARTS or subClassID == LE_ITEM_TRADEGOODS_DEVICES or subClassID == LE_ITEM_TRADEGOODS_EXPLOSIVES then
        return "Parts", "Engineering"
    end
    if subClassID == LE_ITEM_TRADEGOODS_ELEMENTAL then
        return "Elemental", "Multi-Profession"
    end
    if subClassID == LE_ITEM_TRADEGOODS_COOKING or subClassID == LE_ITEM_TRADEGOODS_MEAT then
        return "Cooking", "Cooking"
    end

    return itemSubType or "Other", "Multi-Profession"
end

local function canonicalizeMaterialFamily(materialType, professionLabel)
    local raw = string.lower(strtrim(materialType or "other reagents"))

    if raw == "metal & stone" or raw == "metal and stone" or raw == "metals and stone" then
        return "Metals and Stone"
    end
    if raw == "pigments and ink" or raw == "pigment" or raw == "ink" or raw == "inscription" then
        return "Pigments and Ink"
    end
    if raw == "enchanting" or raw == "enchantment" then
        return "Enchantment"
    end
    if raw == "gem" or raw == "gems" or raw == "jewelcrafting" then
        return "Gems"
    end
    if raw == "herb" or raw == "herbs" then
        return "Herbs"
    end
    if raw == "cloth" then
        return "Cloth"
    end
    if raw == "leather" then
        return "Leather"
    end
    if raw == "parts" or raw == "devices" or raw == "explosives" or raw == "engineering" then
        return "Parts"
    end
    if raw == "elemental" then
        return "Elemental"
    end
    if raw == "cooking" or raw == "meat" then
        return "Cooking"
    end

    -- Profession-aware fallback to keep families stable.
    if professionLabel == "Inscription" then
        return "Pigments and Ink"
    end
    if professionLabel == "Jewelcrafting" then
        return "Gems"
    end
    if professionLabel == "Enchanting" then
        return "Enchantment"
    end
    if professionLabel == "Engineering" then
        return "Parts"
    end

    return materialType or "Other Reagents"
end

local function getTrackedMaterialsLookup(itemsTable)
    local lookup = {}

    for _, itemID in ipairs(TRACKED_MATERIAL_ITEM_IDS) do
        lookup[itemID] = true
    end

    for itemID in pairs(itemsTable) do
        lookup[itemID] = true
    end

    return lookup
end

local function getTrackedOnlyLookup()
    local lookup = {}
    for _, itemID in ipairs(TRACKED_MATERIAL_ITEM_IDS) do
        lookup[itemID] = true
    end
    return lookup
end

local function getCatalogLookup(itemsTable)
    local lookup = getTrackedMaterialsLookup(itemsTable)

    if BankMatsViewerDB.catalogItemIDs then
        for itemID in pairs(BankMatsViewerDB.catalogItemIDs) do
            lookup[itemID] = true
        end
    end

    for itemID in pairs(itemsTable) do
        lookup[itemID] = true
    end

    return lookup
end

local function getKnownDBLookup(itemsTable)
    local lookup = {}

    if BankMatsViewerDB.catalogItemIDs then
        for itemID in pairs(BankMatsViewerDB.catalogItemIDs) do
            lookup[itemID] = true
        end
    end

    for itemID in pairs(itemsTable) do
        lookup[itemID] = true
    end

    return lookup
end

local function seedCatalogFromTrackedList()
    BankMatsViewerDB.catalogItemIDs = BankMatsViewerDB.catalogItemIDs or {}
    for _, itemID in ipairs(TRACKED_MATERIAL_ITEM_IDS) do
        BankMatsViewerDB.catalogItemIDs[itemID] = true
    end
end

local function getOwnedLookup(itemsTable)
    local lookup = {}
    for itemID in pairs(itemsTable) do
        lookup[itemID] = true
    end
    return lookup
end

local function getItemExpansionName(itemID)
    if EXPANSION_OVERRIDES[itemID] then
        return EXPANSION_OVERRIDES[itemID]
    end

    -- expacID is the 15th return value of GetItemInfo (not GetItemInfoInstant which has only 7)
    local expacID = select(15, GetItemInfo(itemID))
    if type(expacID) == "number" and EXPANSION_NAMES[expacID] then
        return EXPANSION_NAMES[expacID]
    end
    return "Unknown"
end

local function getItemQualityLabel(itemID)
    local quality = select(3, GetItemInfo(itemID))
    if type(quality) == "number" and QUALITY_LABELS[quality] then
        return QUALITY_LABELS[quality]
    end
    return "Unknown"
end

local function getItemQualityNumber(itemID)
    local quality = select(3, GetItemInfo(itemID))
    if type(quality) == "number" then
        return quality
    end
    return nil
end

local function getReagentQualityInfo(itemID)
    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo then
        local info = C_TradeSkillUI.GetItemReagentQualityInfo(itemID)
        if info and type(info.quality) == "number" and info.quality > 0 then
            return info
        end
    end

    return nil
end

local function getReagentQualityTier(itemID)
    local info = getReagentQualityInfo(itemID)
    if info then
        return info.quality
    end

    if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        local tier = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
        if type(tier) == "number" and tier > 0 then
            return tier
        end
    end

    return nil
end

local function isCraftingMaterialByItemID(itemID)
    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    return TRADEGOODS_CLASS_ID and classID == TRADEGOODS_CLASS_ID
end

local function scanBag(bagID)
    local slots = C_Container.GetContainerNumSlots(bagID)
    if not slots or slots <= 0 then
        return
    end

    for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID and info.stackCount and info.stackCount > 0 then
            if isCraftingMaterial(info.itemID, bagID, slot) then
                addItem(info.itemID, info.stackCount)
            end
        end
    end
end

local function runScan()
    clearScan()

    for _, bagID in ipairs(state.warbandBagIDs) do
        scanBag(bagID)
    end

    state.lastScan = time()
    persistScan()
end

local function getActiveItems()
    if next(state.items) ~= nil then
        return state.items, state.totalItemTypes, state.totalCount, state.lastScan
    end

    if BankMatsViewerDB.items and next(BankMatsViewerDB.items) ~= nil then
        return BankMatsViewerDB.items, BankMatsViewerDB.totalItemTypes or 0, BankMatsViewerDB.totalCount or 0, BankMatsViewerDB.lastScan or 0
    end

    return {}, 0, 0, 0
end

local function buildRowsFromLookup(itemsTable, catalogLookup)
    local rows = {}

    for itemID in pairs(catalogLookup) do
        local count = itemsTable[itemID] or 0
        if isCraftingMaterialByItemID(itemID) or TRACKED_MATERIAL_ITEM_ID_LOOKUP[itemID] then
            local reagentQualityInfo = getReagentQualityInfo(itemID)
            local materialType, professionLabel = classifyItem(itemID)
            local materialFamily = canonicalizeMaterialFamily(materialType, professionLabel)
            local expansion = getItemExpansionName(itemID)
            local itemQuality = getItemQualityNumber(itemID)
            local quality = getItemQualityLabel(itemID)

            rows[#rows + 1] = {
                itemID = itemID,
                count = count,
                name = getItemName(itemID),
                icon = getItemIcon(itemID),
                reagentQualityTier = reagentQualityInfo and reagentQualityInfo.quality or getReagentQualityTier(itemID),
                reagentQualityIconInventory = reagentQualityInfo and reagentQualityInfo.iconInventory or nil,
                reagentQualityIconSmall = reagentQualityInfo and reagentQualityInfo.iconSmall or nil,
                isMissing = count == 0,
                expansion = expansion,
                expansionSort = EXPANSION_SORT[expansion] or 99,
                itemQuality = itemQuality,
                quality = quality,
                qualitySort = QUALITY_SORT[quality] or 99,
                profession = professionLabel,
                materialType = materialFamily,
                materialSort = MATERIAL_SORT[materialFamily] or 99,
                reagentQualitySort = (reagentQualityInfo and reagentQualityInfo.quality) or 99,
                groupKey = professionLabel .. "||" .. materialFamily,
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.expansionSort ~= b.expansionSort then
            return a.expansionSort < b.expansionSort
        end
        if a.materialSort ~= b.materialSort then
            return a.materialSort < b.materialSort
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        if a.reagentQualitySort ~= b.reagentQualitySort then
            return a.reagentQualitySort < b.reagentQualitySort
        end
        if a.qualitySort ~= b.qualitySort then
            return a.qualitySort < b.qualitySort
        end
        return a.itemID < b.itemID
    end)

    return rows
end

local function buildRows(itemsTable)
    return buildRowsFromLookup(itemsTable, getCatalogLookup(itemsTable))
end

local function buildDisplayRows(itemsTable)
    if state.showUnowned then
        return buildRowsFromLookup(itemsTable, getKnownDBLookup(itemsTable))
    end

    return buildRowsFromLookup(itemsTable, getOwnedLookup(itemsTable))
end

local function buildTrackedRows(itemsTable)
    return buildRowsFromLookup(itemsTable, getTrackedOnlyLookup())
end

local function summarizeRows(rows)
    local ownedTypes = 0
    local missingTypes = 0
    local unknownExpansion = 0
    local unknownQuality = 0
    local ownedUnits = 0
    local missingByExpansion = {}

    for _, row in ipairs(rows) do
        if row.count > 0 then
            ownedTypes = ownedTypes + 1
            ownedUnits = ownedUnits + row.count
        else
            missingTypes = missingTypes + 1
            missingByExpansion[row.expansion] = (missingByExpansion[row.expansion] or 0) + 1
        end

        if row.expansion == "Unknown" then
            unknownExpansion = unknownExpansion + 1
        end
        if row.quality == "Unknown" then
            unknownQuality = unknownQuality + 1
        end
    end

    return {
        total = #rows,
        ownedTypes = ownedTypes,
        missingTypes = missingTypes,
        unknownExpansion = unknownExpansion,
        unknownQuality = unknownQuality,
        ownedUnits = ownedUnits,
        missingByExpansion = missingByExpansion,
    }
end

local function printAuditReport()
    local itemsTable = getActiveItems()
    local trackedRows = buildTrackedRows(itemsTable)
    local allRows = buildRows(itemsTable)
    local tracked = summarizeRows(trackedRows)
    local all = summarizeRows(allRows)

    print("|cff33ff99Bank Mats Viewer Audit|r")
    print("  Tracked catalog:")
    print("    Item types:       " .. tostring(tracked.total))
    print("    Owned item types: " .. tostring(tracked.ownedTypes))
    print("    Missing types:    " .. tostring(tracked.missingTypes))
    print("    Total units:      " .. tostring(tracked.ownedUnits))
    print("    Unknown expansion:" .. tostring(tracked.unknownExpansion))
    print("    Unknown quality:  " .. tostring(tracked.unknownQuality))
    print("  Full catalog (includes discovered history):")
    print("    Item types:       " .. tostring(all.total))
    print("    Owned item types: " .. tostring(all.ownedTypes))
    print("    Missing types:    " .. tostring(all.missingTypes))

    print("  Tracked missing by expansion:")
    for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
        local missing = tracked.missingByExpansion[expansionName] or 0
        if missing > 0 then
            print("    - " .. expansionName .. ": " .. tostring(missing))
        end
    end
end

local function printMissingItems(limit, includeDiscoveredHistory)
    local itemsTable = getActiveItems()
    local rows = includeDiscoveredHistory and buildRows(itemsTable) or buildTrackedRows(itemsTable)
    local maxItems = tonumber(limit) or 40
    local shown = 0

    if includeDiscoveredHistory then
        print("|cff33ff99Bank Mats Viewer Missing Items (full catalog)|r")
    else
        print("|cff33ff99Bank Mats Viewer Missing Items (tracked catalog)|r")
    end

    for _, row in ipairs(rows) do
        if row.count == 0 then
            print("  [" .. row.expansion .. "] " .. row.name .. " (item:" .. tostring(row.itemID) .. ")")
            shown = shown + 1
            if shown >= maxItems then
                break
            end
        end
    end

    if shown == 0 then
        print("  No missing items in selected catalog.")
    else
        print("  Showing " .. tostring(shown) .. " missing items.")
    end
end

local function acquireSeparator(index)
    local sep = ui.separators[index]
    if sep then
        sep:Show()
        return sep
    end
    sep = ui.content:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetColorTexture(0.3, 0.3, 0.35, 0.6)
    ui.separators[index] = sep
    return sep
end

local function acquireHeader(index)
    local header = ui.groupHeaders[index]
    if header then
        header:Show()
        return header
    end

    header = ui.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetJustifyH("LEFT")
    header:SetTextColor(0.95, 0.82, 0.24)
    if header.EnableMouse then
        header:EnableMouse(false)
    end
    ui.groupHeaders[index] = header
    return header
end

local function acquireExpansionHeader(index)
    local header = ui.expansionHeaders[index]
    if header then
        header:Show()
        return header
    end

    header = CreateFrame("Button", nil, ui.content, "BackdropTemplate")
    header:SetSize(540, 22)

    header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header.label:SetPoint("LEFT", header, "LEFT", 0, 0)
    header.label:SetJustifyH("LEFT")
    header.label:SetTextColor(0.92, 0.8, 0.3)

    header.toggle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header.toggle:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    header.toggle:SetJustifyH("RIGHT")
    header.toggle:SetTextColor(0.86, 0.86, 0.86)

    header:SetScript("OnEnter", function(self)
        self.toggle:SetTextColor(1, 1, 1)
    end)

    header:SetScript("OnLeave", function(self)
        self.toggle:SetTextColor(0.86, 0.86, 0.86)
    end)

    ui.expansionHeaders[index] = header
    return header
end

local function acquireItemButton(index)
    local btn = ui.itemButtons[index]
    if btn then
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, ui.content)
    btn:SetSize(40, 40)

    -- Slot background, named SlotTexture so SetItemButtonSlotVertexColor works
    local slotTex = btn:CreateTexture(nil, "BACKGROUND")
    slotTex:SetTexture("Interface/PaperDoll/UI-Backpack-EmptySlot")
    slotTex:SetAllPoints(btn)
    btn.SlotTexture = slotTex

    -- Item icon, named Icon so SetItemButtonTexture / SetItemButtonTextureVertexColor work
    local iconTex = btn:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.Icon = iconTex
    btn.icon = iconTex  -- some helpers use lowercase

    -- Quality border, named IconBorder so SetItemButtonQuality works
    local borderTex = btn:CreateTexture(nil, "OVERLAY")
    borderTex:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    borderTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    borderTex:SetTexture("Interface/Common/WhiteIconFrame")
    borderTex:SetBlendMode("ADD")
    borderTex:Hide()
    btn.IconBorder = borderTex

    -- Count text, named Count so SetItemButtonCount works
    local countStr = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    countStr:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
    btn.Count = countStr
    btn.count = countStr  -- some helpers use lowercase

    btn:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

    btn:SetScript("OnEnter", function(self)
        if not self.itemID then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local itemName = GetItemInfo(self.itemID)
        if itemName then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:AddLine("Unknown Item", 1, 0.3, 0.3)
            GameTooltip:AddLine("Item ID: " .. tostring(self.itemID), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Not in client cache - may be an invalid ID", 0.7, 0.7, 0.5)
        end
        GameTooltip:AddLine(" ")
        if self.expansion then
            GameTooltip:AddLine("Expansion: " .. self.expansion, 0.7, 0.85, 1)
        end
        if self.qualityLabel then
            GameTooltip:AddLine("Quality: " .. self.qualityLabel, 0.85, 0.85, 0.95)
        end
        if self.reagentQualityTier then
            local qualityLine = "Reagent Quality Tier: " .. tostring(self.reagentQualityTier)
            if self.reagentQualityIconSmall and CreateAtlasMarkup then
                qualityLine = CreateAtlasMarkup(self.reagentQualityIconSmall, 16, 16) .. " " .. qualityLine
            end
            GameTooltip:AddLine(qualityLine, 1, 0.92, 0.35)
        end
        if self.groupLabel then
            GameTooltip:AddLine("Type: " .. self.groupLabel, 0.8, 0.95, 0.8)
        end
        GameTooltip:AddLine("Count in Warband Bank: " .. tostring(self.itemCount), 0.6, 0.9, 0.6)
        if self.isMissing then
            GameTooltip:AddLine("Missing from Warband Bank (catalog item)", 0.9, 0.4, 0.4)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ui.itemButtons[index] = btn
    return btn
end

local function refreshWindow()
    if not ui.frame or not ui.frame:IsShown() then
        return
    end

    local itemsTable, _, totalCount, lastScan = getActiveItems()
    local rows = buildDisplayRows(itemsTable)

    local ownedTypes = 0
    for _, row in ipairs(rows) do
        if row.count > 0 then
            ownedTypes = ownedTypes + 1
        end
    end

    local modeText = state.showUnowned and "All known" or "Owned only"
    local summary = tostring(ownedTypes) .. " / " .. tostring(#rows) .. " material types | " .. modeText .. " | " .. tostring(totalCount) .. " total units"
    if lastScan and lastScan > 0 then
        summary = summary .. " | Last scan: " .. date("%Y-%m-%d %H:%M:%S", lastScan)
    end
    ui.summaryText:SetText(summary)

    for _, header in ipairs(ui.groupHeaders) do
        header:Hide()
    end
    for _, header in ipairs(ui.expansionHeaders) do
        header:Hide()
    end
    for _, btn in ipairs(ui.itemButtons) do
        btn:Hide()
    end
    for _, sep in ipairs(ui.separators) do
        sep:Hide()
    end

    if ui.showUnownedCheck then
        ui.showUnownedCheck:SetChecked(state.showUnowned)
    end

    local y = -8
    local headerIndex = 0
    local buttonIndex = 0
    local columns = 11
    local cell = 42

    if #rows == 0 then
        headerIndex = headerIndex + 1
        local header = acquireHeader(headerIndex)
        header:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 8, y)
        header:SetText("No crafting materials found. Open your Warband Bank or use /bmats scan.")
        ui.content:SetHeight(60)
        return
    end

    local rowsByExpansion = {}
    for _, row in ipairs(rows) do
        rowsByExpansion[row.expansion] = rowsByExpansion[row.expansion] or {}
        rowsByExpansion[row.expansion][#rowsByExpansion[row.expansion] + 1] = row
    end

    local separatorIndex = 0
    local function emitSeparator()
        separatorIndex = separatorIndex + 1
        local sep = acquireSeparator(separatorIndex)
        sep:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 10, y + 1)
        sep:SetPoint("TOPRIGHT", ui.content, "TOPRIGHT", -14, y + 1)
        y = y - 8
    end

    local function emitHeader(text, r, g, b)
        headerIndex = headerIndex + 1
        local header = acquireHeader(headerIndex)
        header:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 10, y)

        header:SetFontObject(GameFontHighlight)
        header:SetText(text)
        header:SetTextColor(r or 0.95, g or 0.82, b or 0.24)
        if header.EnableMouse then
            header:EnableMouse(false)
        end
        header:SetScript("OnMouseUp", nil)

        y = y - 22
    end

    local expansionHeaderIndex = 0
    local function emitExpansionHeader(expansionName, count)
        expansionHeaderIndex = expansionHeaderIndex + 1
        local header = acquireExpansionHeader(expansionHeaderIndex)
        header:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 8, y)

        local isCollapsed = state.collapsedExpansions[expansionName] == true
        header.label:SetText("Expansion: " .. expansionName .. " (" .. tostring(count) .. ")")
        header.toggle:SetText(isCollapsed and "+" or "-")

        header:SetScript("OnClick", function()
            state.collapsedExpansions[expansionName] = not state.collapsedExpansions[expansionName]
            BankMatsViewerDB.collapsedExpansions = BankMatsViewerDB.collapsedExpansions or {}
            BankMatsViewerDB.collapsedExpansions[expansionName] = state.collapsedExpansions[expansionName]
            refreshWindow()
        end)

        y = y - 26
    end

    for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
        local expansionRows = rowsByExpansion[expansionName] or {}
        emitExpansionHeader(expansionName, #expansionRows)

        if state.collapsedExpansions[expansionName] then
            y = y - 6
        else
        if #expansionRows == 0 then
            emitHeader("  No tracked materials", 0.55, 0.6, 0.68)
            y = y - 4
        else
            local col = 0
            local currentMaterial = nil

            for _, row in ipairs(expansionRows) do
                if row.materialType ~= currentMaterial then
                    if col > 0 then
                        y = y - cell
                        col = 0
                    end
                    if currentMaterial ~= nil then
                        y = y - 4
                        emitSeparator()
                    end
                    currentMaterial = row.materialType
                    emitHeader(currentMaterial, 0.72, 0.88, 0.98)
                end

                buttonIndex = buttonIndex + 1
                local btn = acquireItemButton(buttonIndex)
                local x = 10 + (col * cell)
                btn:SetPoint("TOPLEFT", ui.content, "TOPLEFT", x, y)
                SetItemButtonTexture(btn, row.icon)
                SetItemButtonCount(btn, row.count)
                SetItemButtonQuality(btn, row.itemQuality, row.itemID)
                if row.isMissing then
                    SetItemButtonTextureVertexColor(btn, 0.45, 0.45, 0.45)
                    SetItemButtonSlotVertexColor(btn, 0.65, 0.65, 0.65)
                    if btn.IconBorder then
                        btn.IconBorder:SetAlpha(0.55)
                    end
                    if btn.ProfessionQualityOverlay then
                        btn.ProfessionQualityOverlay:SetAlpha(0.55)
                    end
                    btn:SetAlpha(0.85)
                else
                    SetItemButtonTextureVertexColor(btn, 1, 1, 1)
                    SetItemButtonSlotVertexColor(btn, 1, 1, 1)
                    if btn.IconBorder then
                        btn.IconBorder:SetAlpha(1)
                    end
                    if btn.ProfessionQualityOverlay then
                        btn.ProfessionQualityOverlay:SetAlpha(1)
                    end
                    btn:SetAlpha(1)
                end
                btn.itemID = row.itemID
                btn.itemCount = row.count
                btn.isMissing = row.isMissing
                btn.expansion = row.expansion
                btn.itemQuality = row.itemQuality
                btn.qualityLabel = row.quality
                btn.reagentQualityTier = row.reagentQualityTier
                btn.reagentQualityIconInventory = row.reagentQualityIconInventory
                btn.reagentQualityIconSmall = row.reagentQualityIconSmall
                btn.groupLabel = row.materialType

                col = col + 1
                if col >= columns then
                    col = 0
                    y = y - cell
                end
            end

            if col > 0 then
                y = y - cell
            end
        end

        end

        y = y - 6
    end

    ui.content:SetHeight(math.max(80, -y + 8))
end

local function createWindow()
    if ui.frame then
        return
    end

    ui.frame = CreateFrame("Frame", "BankMatsViewerFrame", UIParent, "BasicFrameTemplateWithInset")
    ui.frame:SetSize(620, 500)
    ui.frame:SetPoint("CENTER")
    ui.frame:SetMovable(true)
    ui.frame:EnableMouse(true)
    ui.frame:RegisterForDrag("LeftButton")
    ui.frame:SetScript("OnDragStart", ui.frame.StartMoving)
    ui.frame:SetScript("OnDragStop", ui.frame.StopMovingOrSizing)
    ui.frame:Hide()

    ui.frame.TitleText:SetText("Bank Mats Viewer")

    local subtitle = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 14, -52)
    subtitle:SetText("Warband Bank Inventory Grid")
    subtitle:SetTextColor(0.65, 0.85, 1.0)

    ui.expandAllButton = CreateFrame("Button", nil, ui.frame, "UIPanelButtonTemplate")
    ui.expandAllButton:SetSize(60, 20)
    ui.expandAllButton:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -14, -34)
    ui.expandAllButton:SetText("Open")
    ui.expandAllButton:SetScript("OnClick", function()
        for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
            state.collapsedExpansions[expansionName] = false
        end
        BankMatsViewerDB.collapsedExpansions = BankMatsViewerDB.collapsedExpansions or {}
        for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
            BankMatsViewerDB.collapsedExpansions[expansionName] = false
        end
        refreshWindow()
    end)

    ui.collapseAllButton = CreateFrame("Button", nil, ui.frame, "UIPanelButtonTemplate")
    ui.collapseAllButton:SetSize(60, 20)
    ui.collapseAllButton:SetPoint("RIGHT", ui.expandAllButton, "LEFT", -6, 0)
    ui.collapseAllButton:SetText("Close")
    ui.collapseAllButton:SetScript("OnClick", function()
        for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
            state.collapsedExpansions[expansionName] = true
        end
        BankMatsViewerDB.collapsedExpansions = BankMatsViewerDB.collapsedExpansions or {}
        for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
            BankMatsViewerDB.collapsedExpansions[expansionName] = true
        end
        refreshWindow()
    end)

    ui.showUnownedCheck = CreateFrame("CheckButton", nil, ui.frame, "UICheckButtonTemplate")
    ui.showUnownedCheck:SetPoint("RIGHT", ui.collapseAllButton, "LEFT", -24, -2)
    if ui.showUnownedCheck.Text then
        ui.showUnownedCheck.Text:SetText("")
        ui.showUnownedCheck.Text:Hide()
    end

    ui.showUnownedLabel = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.showUnownedLabel:SetPoint("RIGHT", ui.showUnownedCheck, "LEFT", -4, -1)
    ui.showUnownedLabel:SetJustifyH("RIGHT")
    ui.showUnownedLabel:SetText("Show Unowned")
    ui.showUnownedLabel:SetTextColor(0.95, 0.82, 0.24)

    ui.showUnownedCheck:SetChecked(state.showUnowned)
    ui.showUnownedCheck:SetScript("OnClick", function(self)
        state.showUnowned = self:GetChecked() == true
        BankMatsViewerDB.showUnowned = state.showUnowned
        refreshWindow()
    end)

    ui.summaryText = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.summaryText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -8)
    ui.summaryText:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -14, -66)
    ui.summaryText:SetJustifyH("LEFT")
    ui.summaryText:SetText("No scan data yet")

    ui.scrollFrame = CreateFrame("ScrollFrame", nil, ui.frame, "UIPanelScrollFrameTemplate")
    ui.scrollFrame:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 12, -102)
    ui.scrollFrame:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", -30, 12)

    ui.content = CreateFrame("Frame", nil, ui.scrollFrame)
    ui.content:SetSize(560, 80)
    ui.scrollFrame:SetScrollChild(ui.content)
end

local function toggleWindow()
    createWindow()

    if ui.frame:IsShown() then
        ui.frame:Hide()
        return
    end

    ui.frame:Show()
    refreshWindow()
end

SLASH_BANKMATSVIEWER1 = "/bmats"
SLASH_BANKMATSVIEWER2 = "/bankmats"
SlashCmdList.BANKMATSVIEWER = function(msg)
    local trimmed = strtrim(msg or "")
    local arg, rest = string.match(trimmed, "^(%S+)%s*(.-)$")
    arg = string.lower(arg or "")

    if arg == "scan" then
        runScan()
        refreshWindow()
        print("|cff33ff99Bank Mats Viewer:|r scan complete.")
        return
    end

    if arg == "audit" then
        printAuditReport()
        return
    end

    if arg == "missing" then
        local includeDiscoveredHistory = false
        local maxItems = 40

        for token in string.gmatch(rest or "", "%S+") do
            local tokenLower = string.lower(token)
            local n = tonumber(token)
            if n then
                maxItems = n
            elseif tokenLower == "all" then
                includeDiscoveredHistory = true
            end
        end

        printMissingItems(maxItems, includeDiscoveredHistory)
        return
    end

    if arg == "help" then
        print("|cff33ff99Bank Mats Viewer commands:|r")
        print("  /bmats            - Toggle window")
        print("  /bmats scan       - Scan Warband Bank now")
        print("  /bmats audit      - Tracked vs full-catalog diagnostics")
        print("  /bmats missing N  - List up to N missing tracked items (default 40)")
        print("  /bmats missing N all - List up to N missing full-catalog items")
        return
    end

    toggleWindow()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        BankMatsViewerDB = BankMatsViewerDB or {}
        BankMatsViewerDB.items = BankMatsViewerDB.items or {}
        BankMatsViewerDB.catalogItemIDs = BankMatsViewerDB.catalogItemIDs or {}
        if BankMatsViewerDB.showUnowned == nil then
            BankMatsViewerDB.showUnowned = true
        end
        BankMatsViewerDB.collapsedExpansions = BankMatsViewerDB.collapsedExpansions or {}
        seedCatalogFromTrackedList()
        state.showUnowned = BankMatsViewerDB.showUnowned
        state.collapsedExpansions = BankMatsViewerDB.collapsedExpansions
        state.warbandBagIDs = getWarbandBagIDs()
        createWindow()
        return
    end

    if event == "BANKFRAME_OPENED" then
        state.bankOpen = true
        runScan()
        refreshWindow()
        return
    end

    if event == "BANKFRAME_CLOSED" then
        state.bankOpen = false
        return
    end

    if event == "BAG_UPDATE_DELAYED" and state.bankOpen then
        runScan()
        refreshWindow()
    end
end)
