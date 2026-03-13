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
    213399, -- Weavercloth (The War Within)

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
    13463,  -- Golden Sansam
    13464,  -- Dreamfoil
    13466,  -- Mountain Silversage
    13467,  -- Plaguebloom
    13468,  -- Black Lotus
    -- The Burning Crusade
    22785,  -- Felweed
    22786,  -- Dreaming Glory
    22787,  -- Ragveil
    22789,  -- Terocone
    22790,  -- Ancient Lichen
    22792,  -- Netherbloom
    22793,  -- Nightmare Vine
    22794,  -- Mana Thistle
    -- Wrath of the Lich King
    36901,  -- Goldclover
    36903,  -- Adder's Tongue
    36905,  -- Tiger Lily
    36906,  -- Lichbloom
    36907,  -- Talandra's Rose
    36908,  -- Icethorn
    39970,  -- Frost Lotus
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
    72237,  -- Snow Lily
    79010,  -- Fool's Cap
    79011,  -- Rain Poppy
    -- Warlords of Draenor
    109124, -- Frostweed
    109125, -- Fireweed
    109126, -- Starflower
    109127, -- Nagrand Arrowbloom
    109128, -- Talador Orchid
    109129, -- Gorgrond Flytrap
    -- Legion
    124101, -- Aethril
    124102, -- Dreamleaf
    124103, -- Foxflower
    124104, -- Fjarnskaggl
    124105, -- Starlight Rose
    128304, -- Felwort
    -- Battle for Azeroth
    152505, -- Riverbud
    152510, -- Anchor Weed
    152511, -- Sea Stalk
    152512, -- Siren's Pollen
    152513, -- Star Moss
    152514, -- Winter's Kiss
    152515, -- Akunda's Bite
    -- Shadowlands
    168487, -- Nightshade
    168583, -- Rising Glory
    168586, -- Death Blossom
    169699, -- Widowbloom
    169700, -- Marrowroot
    169701, -- Vigil's Torch
    -- Dragonflight
    191460, -- Hochenblume
    191461, -- Saxifrage
    191462, -- Bubble Poppy
    191463, -- Writhebark
    194255, -- Abyssal Lotus
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
    52183,  -- Obsidium Ore
    52185,  -- Elementium Ore
    52186,  -- Pyrite Ore
    -- Mists of Pandaria
    72092,  -- Ghost Iron Ore
    72093,  -- Kyparite
    72094,  -- Black Trillium Ore
    72095,  -- White Trillium Ore
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

BankMatsViewerDB = BankMatsViewerDB or {}

local state = {
    bankOpen = false,
    warbandBagIDs = {},
    items = {},
    totalItemTypes = 0,
    totalCount = 0,
    lastScan = 0,
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
    ["Classic"] = 1,
    ["The Burning Crusade"] = 2,
    ["Wrath of the Lich King"] = 3,
    ["Cataclysm"] = 4,
    ["Mists of Pandaria"] = 5,
    ["Warlords of Draenor"] = 6,
    ["Legion"] = 7,
    ["Battle for Azeroth"] = 8,
    ["Shadowlands"] = 9,
    ["Dragonflight"] = 10,
    ["The War Within"] = 11,
    ["Midnight"] = 12,
    ["Unknown"] = 99,
}

local EXPANSION_SECTION_ORDER = {
    "Classic",
    "The Burning Crusade",
    "Wrath of the Lich King",
    "Cataclysm",
    "Mists of Pandaria",
    "Warlords of Draenor",
    "Legion",
    "Battle for Azeroth",
    "Shadowlands",
    "Dragonflight",
    "The War Within",
    "Midnight",
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

local ui = {
    frame = nil,
    summaryText = nil,
    scrollFrame = nil,
    content = nil,
    itemButtons = {},
    groupHeaders = {},
}

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

local function getItemExpansionName(itemID)
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

local function buildRows(itemsTable)
    local rows = {}
    local catalogLookup = getCatalogLookup(itemsTable)

    for itemID in pairs(catalogLookup) do
        local count = itemsTable[itemID] or 0
        if isCraftingMaterialByItemID(itemID) then
            local materialType, professionLabel = classifyItem(itemID)
            local expansion = getItemExpansionName(itemID)
            local quality = getItemQualityLabel(itemID)

            rows[#rows + 1] = {
                itemID = itemID,
                count = count,
                name = getItemName(itemID),
                icon = getItemIcon(itemID),
                isMissing = count == 0,
                expansion = expansion,
                expansionSort = EXPANSION_SORT[expansion] or 99,
                quality = quality,
                qualitySort = QUALITY_SORT[quality] or 99,
                profession = professionLabel,
                materialType = materialType,
                groupKey = professionLabel .. "||" .. materialType,
            }
        end
    end

    table.sort(rows, function(a, b)
        if a.expansionSort ~= b.expansionSort then
            return a.expansionSort < b.expansionSort
        end
        if a.qualitySort ~= b.qualitySort then
            return a.qualitySort < b.qualitySort
        end
        if a.groupKey ~= b.groupKey then
            return a.groupKey < b.groupKey
        end
        if a.name == b.name then
            return a.itemID < b.itemID
        end
        return a.name < b.name
    end)

    return rows
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
    ui.groupHeaders[index] = header
    return header
end

local function acquireItemButton(index)
    local btn = ui.itemButtons[index]
    if btn then
        btn:Show()
        return btn
    end

    btn = CreateFrame("Button", nil, ui.content, "BackdropTemplate")
    btn:SetSize(42, 42)
    btn:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.1, 0.1, 0.12, 0.95)
    btn:SetBackdropBorderColor(0.25, 0.25, 0.3, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

    btn.countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)

    btn:SetScript("OnEnter", function(self)
        if not self.itemID then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:AddLine(" ")
        if self.expansion then
            GameTooltip:AddLine("Expansion: " .. self.expansion, 0.7, 0.85, 1)
        end
        if self.qualityLabel then
            GameTooltip:AddLine("Quality: " .. self.qualityLabel, 0.85, 0.85, 0.95)
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
    local rows = buildRows(itemsTable)

    local ownedTypes = 0
    for _, row in ipairs(rows) do
        if row.count > 0 then
            ownedTypes = ownedTypes + 1
        end
    end

    local summary = tostring(ownedTypes) .. " / " .. tostring(#rows) .. " material types in Warband Bank | " .. tostring(totalCount) .. " total units"
    if lastScan and lastScan > 0 then
        summary = summary .. " | Last scan: " .. date("%Y-%m-%d %H:%M:%S", lastScan)
    end
    ui.summaryText:SetText(summary)

    for _, header in ipairs(ui.groupHeaders) do
        header:Hide()
    end
    for _, btn in ipairs(ui.itemButtons) do
        btn:Hide()
    end

    local y = -8
    local headerIndex = 0
    local buttonIndex = 0
    local columns = 11
    local cell = 48

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

    local function emitHeader(text, r, g, b)
        headerIndex = headerIndex + 1
        local header = acquireHeader(headerIndex)
        header:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 8, y)
        header:SetText(text)
        header:SetTextColor(r or 0.95, g or 0.82, b or 0.24)
        y = y - 22
    end

    for _, expansionName in ipairs(EXPANSION_SECTION_ORDER) do
        emitHeader("Expansion: " .. expansionName, 0.9, 0.78, 0.2)

        local expansionRows = rowsByExpansion[expansionName] or {}
        if #expansionRows == 0 then
            emitHeader("  No tracked materials", 0.55, 0.6, 0.68)
            y = y - 4
        else
            local col = 0

            for _, row in ipairs(expansionRows) do
                buttonIndex = buttonIndex + 1
                local btn = acquireItemButton(buttonIndex)
                local x = 8 + (col * cell)
                btn:SetPoint("TOPLEFT", ui.content, "TOPLEFT", x, y)
                btn.icon:SetTexture(row.icon)
                btn.icon:SetDesaturated(row.isMissing)
                btn.icon:SetVertexColor(row.isMissing and 0.45 or 1, row.isMissing and 0.45 or 1, row.isMissing and 0.45 or 1)
                btn.countText:SetText(BreakUpLargeNumbers(row.count))
                btn.countText:SetTextColor(row.isMissing and 0.7 or 1, row.isMissing and 0.7 or 0.82, row.isMissing and 0.7 or 0)
                btn:SetBackdropColor(row.isMissing and 0.06 or 0.1, row.isMissing and 0.06 or 0.1, row.isMissing and 0.08 or 0.12, row.isMissing and 0.75 or 0.95)
                btn:SetBackdropBorderColor(row.isMissing and 0.18 or 0.25, row.isMissing and 0.18 or 0.25, row.isMissing and 0.2 or 0.3, 1)
                btn.itemID = row.itemID
                btn.itemCount = row.count
                btn.isMissing = row.isMissing
                btn.expansion = row.expansion
                btn.qualityLabel = row.quality
                btn.groupLabel = row.profession .. " / " .. row.materialType

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
    subtitle:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 14, -34)
    subtitle:SetText("Warband Bank Inventory Grid")
    subtitle:SetTextColor(0.65, 0.85, 1.0)

    ui.summaryText = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ui.summaryText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -6)
    ui.summaryText:SetPoint("TOPRIGHT", ui.frame, "TOPRIGHT", -14, -40)
    ui.summaryText:SetJustifyH("LEFT")
    ui.summaryText:SetText("No scan data yet")

    ui.scrollFrame = CreateFrame("ScrollFrame", nil, ui.frame, "UIPanelScrollFrameTemplate")
    ui.scrollFrame:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", 12, -78)
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
    local arg = string.lower(strtrim(msg or ""))
    if arg == "scan" then
        runScan()
        refreshWindow()
        print("|cff33ff99Bank Mats Viewer:|r scan complete.")
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
