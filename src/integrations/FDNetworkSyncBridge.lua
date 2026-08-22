-- =========================================================
-- FS25 Fertilizer Depot - NetworkSync bridge
-- =========================================================
-- Optional bridge to FS25_NetworkSync. Routes all client-initiated
-- writes (purchase, sell, silo fill, product order, delivery
-- actions, settings) through NetworkSync's server-authoritative
-- action channel (Path 3). Server->client state (storage,
-- deliveries, settings) flows through a single state-sync module
-- (FULL snapshot at 1Hz batch).
--
-- Delegate-when-present:
--   NetworkSync installed -> all networking via NS
--   NetworkSync absent    -> no networking (single-player only;
--                            the old event classes are removed)
-- =========================================================

FDNetworkSyncBridge = FDNetworkSyncBridge or {}

-- ─── Action IDs ──────────────────────────────────────────

FDNetworkSyncBridge.ACTION_PURCHASE          = "FertilizerDepot_Purchase"
FDNetworkSyncBridge.ACTION_SELL              = "FertilizerDepot_Sell"
FDNetworkSyncBridge.ACTION_SILO_FILL         = "FertilizerDepot_SiloFill"
FDNetworkSyncBridge.ACTION_PRODUCT_ORDER     = "FertilizerDepot_ProductOrder"
FDNetworkSyncBridge.ACTION_DELIVERY_ORDER    = "FertilizerDepot_DeliveryOrder"
FDNetworkSyncBridge.ACTION_DELIVERY_PICKUP   = "FertilizerDepot_DeliveryPickup"
FDNetworkSyncBridge.ACTION_DELIVERY_COMPLETE = "FertilizerDepot_DeliveryComplete"
FDNetworkSyncBridge.ACTION_DELIVERY_CANCEL   = "FertilizerDepot_DeliveryCancel"
FDNetworkSyncBridge.ACTION_SETTINGS          = "FertilizerDepot_Settings"

-- ─── State sync module ───────────────────────────────────

FDNetworkSyncBridge.STATE_MODULE_ID = "FS25_FertilizerDepot"
FDNetworkSyncBridge.STATE_CHANNEL   = "FertilizerDepot_Sync"

FDNetworkSyncBridge.active      = false
FDNetworkSyncBridge.stateActive = false
FDNetworkSyncBridge._ns         = nil

-- =========================================================
-- Server-side action handlers
-- =========================================================

local function handlePurchase(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, fillTypeName, fillTypeIndex, liters, farmId =
        args[1], args[2], args[3], args[4], args[5]
    if not g_DepotManager then return end
    local success = g_DepotManager.depotSystem:buyFillType(
        depotId, fillTypeName, fillTypeIndex, liters, farmId)
    if success then
        FDNetworkSyncBridge.markDirty()
    end
end

local function handleSell(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, fillTypeName, fillTypeIndex, liters, farmId =
        args[1], args[2], args[3], args[4], args[5]
    if not g_DepotManager then return end
    g_DepotManager.depotSystem:sellFillType(
        depotId, fillTypeName, fillTypeIndex, liters, farmId)
    FDNetworkSyncBridge.markDirty()
end

local function handleSiloFill(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, siloId, fillTypeName, fillTypeIndex, requestedLiters, farmId =
        args[1], args[2], args[3], args[4], args[5], args[6]
    if not g_DepotManager then return end
    local siloNode = g_DepotManager.siloNodes[siloId]
    local ok = g_DepotManager.depotSystem:buyFromSilo(
        depotId, siloNode, fillTypeName, fillTypeIndex, requestedLiters, farmId)
    if ok then
        g_DepotManager:clearPendingOrder(farmId)
    end
    FDNetworkSyncBridge.markDirty()
end

local function handleProductOrder(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, fillTypeName, fillTypeIndex, quantity, farmId =
        args[1], args[2], args[3], args[4], args[5]
    if not g_DepotManager then return end
    local placeable = g_DepotManager.depots[depotId]
    local spawnX, spawnZ = 0, 0
    local spawnNode = g_DepotManager.depotProductSpawnNodes[depotId]
                   or g_DepotManager.depotUnloadNodes[depotId]
    if spawnNode then
        local wx, _, wz = getWorldTranslation(spawnNode)
        spawnX, spawnZ = wx, wz
    elseif placeable and placeable.rootNode then
        local wx, _, wz = getWorldTranslation(placeable.rootNode)
        spawnX, spawnZ = wx, wz
    end
    g_DepotManager.depotSystem:orderProduct(
        depotId, fillTypeName, fillTypeIndex, quantity, spawnX, spawnZ, farmId)
    FDNetworkSyncBridge.markDirty()
end

local function handleDeliveryOrder(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, farmId = args[1], args[2]
    if not g_DepotManager or not g_DepotManager.deliverySystem then return end
    g_DepotManager.deliverySystem:placeOrder(depotId, farmId)
    FDNetworkSyncBridge.markDirty()
end

local function handleDeliveryPickup(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, farmId = args[1], args[2]
    if not g_DepotManager or not g_DepotManager.deliverySystem then return end
    g_DepotManager.deliverySystem:confirmPickup(depotId, farmId)
    FDNetworkSyncBridge.markDirty()
end

local function handleDeliveryComplete(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, farmId = args[1], args[2]
    if not g_DepotManager or not g_DepotManager.deliverySystem then return end
    g_DepotManager.deliverySystem:completeDelivery(depotId, farmId)
    FDNetworkSyncBridge.markDirty()
end

local function handleDeliveryCancel(_userId, args)
    if type(args) ~= "table" then return end
    local depotId, farmId = args[1], args[2]
    if not g_DepotManager or not g_DepotManager.deliverySystem then return end
    g_DepotManager.deliverySystem:cancelDelivery(depotId, farmId)
    FDNetworkSyncBridge.markDirty()
end

local function handleSettings(userId, args)
    if type(args) ~= "table" then return end
    local key, value = args[1], args[2]
    if not g_DepotManager then return end

    -- Admin/farm-manager gate (mirrors old DepotSettingsEvent authorization)
    if userId ~= nil then
        local user = g_currentMission.userManager
                    and g_currentMission.userManager:getUserByUserId(userId)
        local isAdmin = user ~= nil and user:getIsMasterUser()
        local isFarmManager = false
        if user then
            local farm = g_farmManager:getFarmByUserId(userId)
            isFarmManager = farm ~= nil and farm:isUserFarmManager(userId)
        end
        if not isAdmin and not isFarmManager then
            DepotLogger.warning("FDNetworkSyncBridge: non-admin settings change blocked (userId=%s)", tostring(userId))
            return
        end
    end

    local s = g_DepotManager.settings
    if key == "seasonalPricing" then
        s.seasonalPricing = (value == "true")
    elseif key == "storageCapacity" then
        s.storageCapacity = tonumber(value) or s.storageCapacity
    elseif key == "sellRatio" then
        s.sellRatio = tonumber(value) or s.sellRatio
    elseif key == "buyMultiplier" then
        s.buyMultiplier = tonumber(value) or s.buyMultiplier
    elseif key == "debugLogging" then
        s.debugLogging = (value == "true")
        DepotLogger._debug = s.debugLogging
    end

    FDNetworkSyncBridge.syncNow()
end

-- =========================================================
-- State serialization (server -> client full snapshot)
-- =========================================================

local function buildStateArray()
    local arr = {}
    local dm = g_DepotManager
    if not dm then return arr end

    -- Depot storage
    local depotCount = 0
    for _ in pairs(dm.depots) do depotCount = depotCount + 1 end
    arr[#arr + 1] = depotCount
    for depotId, _ in pairs(dm.depots) do
        local depot = dm.depotSystem:getDepot(depotId)
        arr[#arr + 1] = depotId
        if depot then
            local ftCount = 0
            for _ in pairs(depot.storageLevel) do ftCount = ftCount + 1 end
            arr[#arr + 1] = ftCount
            for name, liters in pairs(depot.storageLevel) do
                arr[#arr + 1] = tostring(name or "")
                arr[#arr + 1] = liters or 0
            end
        else
            arr[#arr + 1] = 0
        end
    end

    -- Deliveries
    local ds = dm.deliverySystem
    local delCount = 0
    if ds then
        for _ in pairs(ds.deliveries) do delCount = delCount + 1 end
    end
    arr[#arr + 1] = delCount
    if ds then
        for depotId, rec in pairs(ds.deliveries) do
            arr[#arr + 1] = depotId
            arr[#arr + 1] = rec.status or 0
            arr[#arr + 1] = rec.farmId or 1
            arr[#arr + 1] = rec.baseCost or 0
            arr[#arr + 1] = rec.deliveryCost or 0
            local itemCount = rec.items and #rec.items or 0
            arr[#arr + 1] = itemCount
            for j = 1, itemCount do
                local item = rec.items[j]
                arr[#arr + 1] = tostring(item.fillTypeName or "")
                arr[#arr + 1] = item.needed or 0
                arr[#arr + 1] = item.baseCost or 0
            end
        end
    end

    -- Settings
    local s = dm.settings
    arr[#arr + 1] = s.seasonalPricing == true
    arr[#arr + 1] = s.storageCapacity or DepotConstants.STORAGE_CAPACITY
    arr[#arr + 1] = s.sellRatio or 0.80
    arr[#arr + 1] = s.buyMultiplier or 1.00
    arr[#arr + 1] = s.debugLogging == true

    return arr
end

-- =========================================================
-- State deserialization (client: apply full snapshot)
-- =========================================================

local function applyStateArray(arr)
    if type(arr) ~= "table" then return end
    local dm = g_DepotManager
    if not dm then return end
    local idx = 1

    -- Depot storage
    local depotCount = tonumber(arr[idx]) or 0; idx = idx + 1
    for _ = 1, depotCount do
        local depotId = arr[idx]; idx = idx + 1
        local ftCount = tonumber(arr[idx]) or 0; idx = idx + 1
        local depot = dm.depotSystem:getDepot(depotId)
        if depot then
            depot.storageLevel = {}
            for _ = 1, ftCount do
                local name   = arr[idx]; idx = idx + 1
                local liters = arr[idx]; idx = idx + 1
                depot.storageLevel[name] = liters
            end
        else
            for _ = 1, ftCount do idx = idx + 2 end
        end
    end

    -- Deliveries
    local ds = dm.deliverySystem
    local delCount = tonumber(arr[idx]) or 0; idx = idx + 1
    if ds then
        ds.deliveries = {}
        for _ = 1, delCount do
            local depId   = arr[idx]; idx = idx + 1
            local status  = arr[idx]; idx = idx + 1
            local farmId  = arr[idx]; idx = idx + 1
            local baseCost= arr[idx]; idx = idx + 1
            local delCost = arr[idx]; idx = idx + 1
            local itemCnt = arr[idx]; idx = idx + 1
            local items = {}
            for _ = 1, itemCnt do
                local name   = arr[idx]; idx = idx + 1
                local needed = arr[idx]; idx = idx + 1
                local cost   = arr[idx]; idx = idx + 1
                local ftIdx  = 0
                if g_fillTypeManager then
                    ftIdx = g_fillTypeManager:getFillTypeIndexByName(name) or 0
                end
                table.insert(items, {
                    fillTypeName  = name,
                    fillTypeIndex = ftIdx,
                    displayName   = name,
                    needed        = needed,
                    baseCost      = cost,
                })
            end
            ds.deliveries[depId] = {
                status       = status,
                depotId      = depId,
                farmId       = farmId,
                baseCost     = baseCost,
                deliveryCost = delCost,
                items        = items,
                vehicle      = nil,
            }
        end
    else
        for _ = 1, delCount do
            idx = idx + 6
            local itemCnt = arr[idx - 1] or 0
            for _ = 1, itemCnt do idx = idx + 3 end
        end
    end

    -- Settings
    dm.settings.seasonalPricing = arr[idx] == true; idx = idx + 1
    dm.settings.storageCapacity = arr[idx] or DepotConstants.STORAGE_CAPACITY; idx = idx + 1
    dm.settings.sellRatio       = arr[idx] or 0.80; idx = idx + 1
    dm.settings.buyMultiplier   = arr[idx] or 1.00; idx = idx + 1
    dm.settings.debugLogging    = arr[idx] == true; idx = idx + 1
    DepotLogger._debug = dm.settings.debugLogging

    -- Refresh open UI
    DepotSettingsDialog.refreshIfOpen()
    if dm.activeDialog and dm.activeDialog.refresh then
        dm.activeDialog:refresh()
    end
end

-- =========================================================
-- Public API
-- =========================================================

---Mark the state module dirty (queued for next 1Hz batch).
function FDNetworkSyncBridge.markDirty()
    if FDNetworkSyncBridge.stateActive and FDNetworkSyncBridge._ns then
        FDNetworkSyncBridge._ns:markDirty(FDNetworkSyncBridge.STATE_MODULE_ID)
    end
end

---Immediate full broadcast (for admin settings changes).
function FDNetworkSyncBridge.syncNow()
    if FDNetworkSyncBridge.stateActive and FDNetworkSyncBridge._ns then
        FDNetworkSyncBridge._ns:syncNow(FDNetworkSyncBridge.STATE_MODULE_ID)
    end
end

---Send a client action to the server via NS, or execute directly on host.
---@param actionId string
---@param args table
---@return boolean handled
function FDNetworkSyncBridge.sendAction(actionId, args)
    if not FDNetworkSyncBridge.active or not FDNetworkSyncBridge._ns then
        return false
    end
    if g_currentMission ~= nil and g_currentMission:getIsServer() then
        FDNetworkSyncBridge._ns:_applyAction(actionId, args, nil)
    else
        FDNetworkSyncBridge._ns:requestAction(actionId, args)
    end
    return true
end

-- =========================================================
-- Registration (called from onMissionLoadFinished)
-- =========================================================

function FDNetworkSyncBridge.register()
    FDNetworkSyncBridge.active      = false
    FDNetworkSyncBridge.stateActive = false
    FDNetworkSyncBridge._ns         = nil

    local ns = (g_currentMission ~= nil and g_currentMission.networkSync) or g_networkSync
    if ns == nil then
        DepotLogger.warning("FertilizerDepot: NetworkSync not detected; no MP sync")
        return
    end

    local ok, err = pcall(function()
        ns:registerAction(FDNetworkSyncBridge.ACTION_PURCHASE, {
            adminOnly = false, onAction = handlePurchase })
        ns:registerAction(FDNetworkSyncBridge.ACTION_SELL, {
            adminOnly = false, onAction = handleSell })
        ns:registerAction(FDNetworkSyncBridge.ACTION_SILO_FILL, {
            adminOnly = false, onAction = handleSiloFill })
        ns:registerAction(FDNetworkSyncBridge.ACTION_PRODUCT_ORDER, {
            adminOnly = false, onAction = handleProductOrder })
        ns:registerAction(FDNetworkSyncBridge.ACTION_DELIVERY_ORDER, {
            adminOnly = false, onAction = handleDeliveryOrder })
        ns:registerAction(FDNetworkSyncBridge.ACTION_DELIVERY_PICKUP, {
            adminOnly = false, onAction = handleDeliveryPickup })
        ns:registerAction(FDNetworkSyncBridge.ACTION_DELIVERY_COMPLETE, {
            adminOnly = false, onAction = handleDeliveryComplete })
        ns:registerAction(FDNetworkSyncBridge.ACTION_DELIVERY_CANCEL, {
            adminOnly = false, onAction = handleDeliveryCancel })
        ns:registerAction(FDNetworkSyncBridge.ACTION_SETTINGS, {
            adminOnly = false, onAction = handleSettings })

        ns:registerModule(FDNetworkSyncBridge.STATE_MODULE_ID, {
            channel      = FDNetworkSyncBridge.STATE_CHANNEL,
            onWriteState = buildStateArray,
            onReadState  = applyStateArray,
        })
    end)

    if ok then
        FDNetworkSyncBridge.active      = true
        FDNetworkSyncBridge.stateActive = true
        FDNetworkSyncBridge._ns         = ns
        DepotLogger.info("FertilizerDepot: NetworkSync bridge registered (9 actions + state module)")
    else
        DepotLogger.error("FertilizerDepot: NetworkSync registration failed: %s", tostring(err))
    end
end
