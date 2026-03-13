local ADDON_NAME = ...
local BANK_CONTAINER_ID = _G.BANK_CONTAINER or -1
local REAGENT_BANK_CONTAINER_ID = _G.REAGENTBANK_CONTAINER or -3
local BANK_BAG_START = 5
local BANK_BAG_END = 11
local TRADEGOODS_CLASS_ID = (Enum and Enum.ItemClass and Enum.ItemClass.Tradegoods) or LE_ITEM_CLASS_TRADEGOODS

BankMatsViewerDB = BankMatsViewerDB or {}

local state = {
    bankOpen = false,
    items = {},
    totalItemTypes = 0,
    totalCount = 0,
    lastScan = 0,
}

local function getItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then
        return name
    end

    local _, link = GetItemInfo(itemID)
    if link then
        return link
    end

    return "item:" .. tostring(itemID)
end

local function isCraftingMaterial(itemID, bagID, slotID)
    if not itemID then
        return false
    end

    if C_Item and C_Item.IsCraftingReagentItem and ItemLocation then
        local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
        if location and location:IsValid() then
            return C_Item.IsCraftingReagentItem(location)
        end
    end

    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    if TRADEGOODS_CLASS_ID and classID == TRADEGOODS_CLASS_ID then
        return true
    end

    return false
end

local function addItem(itemID, count)
    if not state.items[itemID] then
        state.items[itemID] = 0
        state.totalItemTypes = state.totalItemTypes + 1
    end

    state.items[itemID] = state.items[itemID] + count
    state.totalCount = state.totalCount + count
end

local function scanBag(bagID)
    local slots = C_Container.GetContainerNumSlots(bagID)
    for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo(bagID, slot)
        if info and info.itemID and info.stackCount and info.stackCount > 0 then
            if isCraftingMaterial(info.itemID, bagID, slot) then
                addItem(info.itemID, info.stackCount)
            end
        end
    end
end

local function clearScan()
    wipe(state.items)
    state.totalItemTypes = 0
    state.totalCount = 0
end

local function persistScan()
    BankMatsViewerDB.items = {}
    for itemID, count in pairs(state.items) do
        BankMatsViewerDB.items[itemID] = count
    end

    BankMatsViewerDB.totalItemTypes = state.totalItemTypes
    BankMatsViewerDB.totalCount = state.totalCount
    BankMatsViewerDB.lastScan = state.lastScan
end

local function runScan()
    clearScan()

    scanBag(BANK_CONTAINER_ID)
    scanBag(REAGENT_BANK_CONTAINER_ID)

    for bagID = BANK_BAG_START, BANK_BAG_END do
        scanBag(bagID)
    end

    state.lastScan = time()
    persistScan()
end

local function buildSortedList(itemsTable)
    local rows = {}

    for itemID, count in pairs(itemsTable) do
        rows[#rows + 1] = {
            itemID = itemID,
            count = count,
            name = getItemName(itemID),
        }
    end

    table.sort(rows, function(a, b)
        if a.name == b.name then
            return a.itemID < b.itemID
        end
        return a.name < b.name
    end)

    return rows
end

local function printFromTable(itemsTable, totalTypes, totalCount, lastScan)
    if not itemsTable or next(itemsTable) == nil then
        print("|cff33ff99Bank Mats Viewer:|r No crafting materials found yet. Open your bank and try again.")
        return
    end

    print("|cff33ff99Bank Mats Viewer:|r " .. tostring(totalTypes) .. " material types, " .. tostring(totalCount) .. " total items.")

    local sorted = buildSortedList(itemsTable)
    for _, row in ipairs(sorted) do
        print(string.format("  - %s: %d", row.name, row.count))
    end

    if lastScan and lastScan > 0 then
        print("|cff33ff99Bank Mats Viewer:|r Last scan: " .. date("%Y-%m-%d %H:%M:%S", lastScan))
    end
end

local function printCurrentResults()
    if next(state.items) ~= nil then
        printFromTable(state.items, state.totalItemTypes, state.totalCount, state.lastScan)
        return
    end

    if BankMatsViewerDB.items and next(BankMatsViewerDB.items) ~= nil then
        printFromTable(
            BankMatsViewerDB.items,
            BankMatsViewerDB.totalItemTypes or 0,
            BankMatsViewerDB.totalCount or 0,
            BankMatsViewerDB.lastScan or 0
        )
        return
    end

    print("|cff33ff99Bank Mats Viewer:|r No cached data. Open your bank to scan materials.")
end

SLASH_BANKMATSVIEWER1 = "/bmats"
SLASH_BANKMATSVIEWER2 = "/bankmats"
SlashCmdList.BANKMATSVIEWER = function()
    printCurrentResults()
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
        return
    end

    if event == "BANKFRAME_OPENED" then
        state.bankOpen = true
        runScan()
        return
    end

    if event == "BANKFRAME_CLOSED" then
        state.bankOpen = false
        return
    end

    if event == "BAG_UPDATE_DELAYED" and state.bankOpen then
        runScan()
    end
end)
