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
--   NetworkSync absent    -> no networking; a host (SP / listen
--                            server) runs the action handlers
--                            directly, a remote client cannot act
--                            (the old event classes are removed)
-- =========================================================

FDNetworkSyncBridge = FDNetworkSyncBridge or {}

-- ─── Action IDs ──────────────────────────────────────────

FDNetworkSyncBridge.ACTION_PURCHASE          = "FertilizerDepot_Purchase"
FDNetworkSyncBridge.ACTION_SELL              = "FertilizerDepot_Sell"
FDNetworkSyncBridge.ACTION_PRODUCT_ORDER     = "FertilizerDepot_ProductOrder"
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
-- RSF-F230: each transaction handler validates its positional payload before
-- the owner is called, binds the acting farm to something the server trusts,
-- and returns the owner's result tuple at the owner's own width so the host
-- dialog can say what the depot actually did. The wire slot args[5] is what
-- the client CLAIMED its farm was; it is never used for admission or charging.

local SPECTATOR_FARM_ID = 0

local function isFiniteNumber(x)
    return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

--- Exactly five positional slots, each of the type the owner reads. Checks the
--- individual slots rather than #args, which lies on a sparse array. The
--- quantity rule is per action: litres and unit counts both just need to be a
--- finite number above zero; the owner clamps them to its own bounds.
local function validTransactionArgs(args)
    if type(args) ~= "table" then return false end
    if args[5] == nil or args[6] ~= nil then return false end
    if type(args[1]) ~= "number" then return false end
    if type(args[2]) ~= "string" then return false end
    if type(args[3]) ~= "number" then return false end
    if not isFiniteNumber(args[4]) or args[4] <= 0 then return false end
    return true
end

--- The farm that pays and receives. On the host paths sendAction supplies the
--- local player's farm as `localFarmId`; on the remote path NetworkSync supplies
--- a non-nil `userId` and the farm is what the server resolves for that user.
--- A nil user with no local farm is nobody, and nobody is charged. The native
--- lookup returns the spectator farm OBJECT for an unmatched user, so a nil
--- test alone is not a rejection: the spectator id and flag are checked too.
---@return number|nil farmId
local function resolveActorFarm(userId, localFarmId)
    if localFarmId ~= nil then
        if type(localFarmId) ~= "number" or localFarmId == SPECTATOR_FARM_ID then return nil end
        return localFarmId
    end
    if userId == nil then return nil end
    if g_farmManager == nil or type(g_farmManager.getFarmByUserId) ~= "function" then return nil end
    local farm = g_farmManager:getFarmByUserId(userId)
    if farm == nil or farm.isSpectator then return nil end
    local id = nil
    if type(farm.getId) == "function" then id = farm:getId() else id = farm.farmId end
    if type(id) ~= "number" or id == SPECTATOR_FARM_ID then return nil end
    return id
end

local function handlePurchase(userId, args, localFarmId)
    if not validTransactionArgs(args) then return false, "fd_error_server", 0 end
    local depotId, fillTypeName, fillTypeIndex, liters = args[1], args[2], args[3], args[4]
    if not g_DepotManager then return false, "fd_error_server", 0 end
    local farmId = resolveActorFarm(userId, localFarmId)
    if farmId == nil then return false, "fd_error_farm", 0 end
    local success, reason, actualLiters = g_DepotManager.depotSystem:buyFillType(
        depotId, fillTypeName, fillTypeIndex, liters, farmId)
    if success then
        FDNetworkSyncBridge.markDirty()
    end
    return success, reason, actualLiters
end

local function handleSell(userId, args, localFarmId)
    if not validTransactionArgs(args) then return false, "fd_error_server", 0, 0 end
    local depotId, fillTypeName, fillTypeIndex, liters = args[1], args[2], args[3], args[4]
    if not g_DepotManager then return false, "fd_error_server", 0, 0 end
    local farmId = resolveActorFarm(userId, localFarmId)
    if farmId == nil then return false, "fd_error_farm", 0, 0 end
    local success, reason, soldLiters, revenue = g_DepotManager.depotSystem:sellFillType(
        depotId, fillTypeName, fillTypeIndex, liters, farmId)
    if success then
        FDNetworkSyncBridge.markDirty()
    end
    return success, reason, soldLiters, revenue
end

local function handleProductOrder(userId, args, localFarmId)
    if not validTransactionArgs(args) then return false, "fd_error_server" end
    local depotId, fillTypeName, fillTypeIndex, quantity = args[1], args[2], args[3], args[4]
    if not g_DepotManager then return false, "fd_error_server" end
    local farmId = resolveActorFarm(userId, localFarmId)
    if farmId == nil then return false, "fd_error_farm" end
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
    local success, reason = g_DepotManager.depotSystem:orderProduct(
        depotId, fillTypeName, fillTypeIndex, quantity, spawnX, spawnZ, farmId)
    if success then
        FDNetworkSyncBridge.markDirty()
    end
    return success, reason
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

-- Action id -> handler. Used by register() and by the host-only direct path in
-- sendAction when NetworkSync is not installed.
local ACTION_HANDLERS = {
    [FDNetworkSyncBridge.ACTION_PURCHASE]      = handlePurchase,
    [FDNetworkSyncBridge.ACTION_SELL]          = handleSell,
    [FDNetworkSyncBridge.ACTION_PRODUCT_ORDER] = handleProductOrder,
    [FDNetworkSyncBridge.ACTION_SETTINGS]      = handleSettings,
}

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
---
---args is a POSITIONAL array in the order the action's handler reads
---(purchase/sell/product order: {depotId, fillTypeName, fillTypeIndex, amount, farmId};
---settings: {key, value}). RealisticFarmingActionEvent serializes args[1..#args],
---so a named table arrives on the server as an empty one.
---
---Delegate-when-present: with NetworkSync absent there is no wire, but a host
---(SP or listen server, g_server set) can still run the handler locally. A
---remote client without NetworkSync has no path and gets false back; callers
---must surface that instead of reporting success.
---
---RSF-F230: on the two HOST paths the handler runs here, through the same table
---and the same pcall, with the local player's farm as a trusted third argument
---(transaction handlers only), and its result tuple is relayed as further
---returns after `handled`. That is what NetworkSync:_applyAction does for a host
---(nil user id, pcall) minus the discarded returns, so NetworkSync itself is
---untouched. On the REMOTE path the first return still means "sent", nothing
---more: no owner result comes back over the wire and a send is never a success.
---@param actionId string
---@param args table
---@return boolean handled  true when run locally or sent; false when neither
---@return ... the owner's tuple, host paths only (buy 3, order 2, sell 4)
local TRANSACTION_ACTIONS = {
    [FDNetworkSyncBridge.ACTION_PURCHASE]      = true,
    [FDNetworkSyncBridge.ACTION_SELL]          = true,
    [FDNetworkSyncBridge.ACTION_PRODUCT_ORDER] = true,
}

local function runLocal(actionId, args)
    local handler = ACTION_HANDLERS[actionId]
    if handler == nil then
        return false
    end
    local results
    if TRANSACTION_ACTIONS[actionId] then
        local localFarmId = g_localPlayer and g_localPlayer.farmId or nil
        results = { pcall(handler, nil, args, localFarmId) }
    else
        results = { pcall(handler, nil, args) }
    end
    if not results[1] then
        DepotLogger.error("FDNetworkSyncBridge: local action '%s' failed: %s",
            tostring(actionId), tostring(results[2]))
        return false
    end
    return true, unpack(results, 2)
end

function FDNetworkSyncBridge.sendAction(actionId, args)
    if not FDNetworkSyncBridge.active or not FDNetworkSyncBridge._ns then
        if g_server == nil then
            return false
        end
        return runLocal(actionId, args)
    end
    if g_currentMission ~= nil and g_currentMission:getIsServer() then
        return runLocal(actionId, args)
    end
    return FDNetworkSyncBridge._ns:requestAction(actionId, args) ~= false
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
            adminOnly = false, onAction = ACTION_HANDLERS[FDNetworkSyncBridge.ACTION_PURCHASE] })
        ns:registerAction(FDNetworkSyncBridge.ACTION_SELL, {
            adminOnly = false, onAction = ACTION_HANDLERS[FDNetworkSyncBridge.ACTION_SELL] })
        ns:registerAction(FDNetworkSyncBridge.ACTION_PRODUCT_ORDER, {
            adminOnly = false, onAction = ACTION_HANDLERS[FDNetworkSyncBridge.ACTION_PRODUCT_ORDER] })
        ns:registerAction(FDNetworkSyncBridge.ACTION_SETTINGS, {
            adminOnly = false, onAction = ACTION_HANDLERS[FDNetworkSyncBridge.ACTION_SETTINGS] })

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
        DepotLogger.info("FertilizerDepot: NetworkSync bridge registered (4 actions + state module)")
    else
        DepotLogger.error("FertilizerDepot: NetworkSync registration failed: %s", tostring(err))
    end
end
