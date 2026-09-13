--!load: src/config/Constants.lua, src/config/DepotSettings.lua, src/DepotLogger.lua, src/integrations/FDNetworkSyncBridge.lua, src/ui/DepotDialog.lua, src/ui/DepotSettingsDialog.lua, src/DepotManager.lua
--
-- F230: every FD sendAction call must hand its handler the POSITIONAL array the
-- handler reads (FDNetworkSyncBridge.lua handlePurchase/handleSell/handleProductOrder
-- read args[1..5], handleSettings reads args[1..2]). Three transport paths are
-- exercised for each of the four registered actions:
--
--   host    NetworkSync present, listen host / SP: NetworkSync:_applyAction passes
--           the table through untouched (NetworkSync.lua:310-333).
--   wire    NetworkSync present, remote client: RealisticFarmingActionEvent
--           writeStream sends n = #args then args[1..n] (RealisticFarmingSyncEvent.lua
--           :209-231). The event is mirrored below with the prelude's mock stream.
--   absent  NetworkSync not installed. On a host (g_server set) sendAction must
--           run the handler directly; on a client it must return false and the
--           dialog must say so instead of "Filling...".
--
-- Control: on origin/development 31e2c04 every caller sends a NAMED table, so the
-- host path delivers nil for every field and the wire path sends zero args. This
-- file must FAIL against that code and PASS after the fix.

-- ── stand-ins ─────────────────────────────────────────────
DepotLogger.info    = function() end
DepotLogger.warning = function() end
DepotLogger.error   = function() end
DepotLogger.debug   = function() end

local received = {}   -- last args each depotSystem method saw
local depotSystem = {}
function depotSystem:buyFillType(depotId, name, idx, liters, farmId)
    received.buy = { depotId, name, idx, liters, farmId }
    return true, "fd_depot_buy_success", liters
end
function depotSystem:sellFillType(depotId, name, idx, liters, farmId)
    received.sell = { depotId, name, idx, liters, farmId }
    return true, "fd_depot_sell_success", liters, 0
end
function depotSystem:orderProduct(depotId, name, idx, quantity, sx, sz, farmId)
    received.order = { depotId, name, idx, quantity, farmId }
    return true, "ok"
end
function depotSystem:findCompatibleVehicle() return { typeName = "trailer" }, 1 end
function depotSystem:getStorageLevel() return 100000 end

local function freshManager()
    g_DepotManager = {
        depotSystem           = depotSystem,
        depots                = { [7] = { rootNode = 1 } },
        depotProductSpawnNodes = {},
        depotUnloadNodes      = {},
        settings              = DepotSettings.new(),
    }
    received = {}
end

-- Mirror of RealisticFarmingActionEvent write/read (NetworkSync origin/development,
-- RealisticFarmingSyncEvent.lua:49-90 writeValue/readValue, :209-231 the event).
local T_BOOL, T_INT, T_FLOAT, T_STRING = 1, 2, 3, 4
local function writeValue(s, v)
    local t = type(v)
    if t == "boolean" then
        streamWriteUInt8(s, T_BOOL); streamWriteBool(s, v)
    elseif t == "number" then
        if math.floor(v) == v and v >= -2147483648 and v <= 2147483647 then
            streamWriteUInt8(s, T_INT); streamWriteInt32(s, v)
        else
            streamWriteUInt8(s, T_FLOAT); streamWriteFloat32(s, v)
        end
    elseif t == "string" then
        streamWriteUInt8(s, T_STRING); streamWriteString(s, v)
    else
        streamWriteUInt8(s, T_FLOAT); streamWriteFloat32(s, 0)
    end
end
local function readValue(s)
    local tag = streamReadUInt8(s)
    if tag == T_BOOL then return streamReadBool(s)
    elseif tag == T_INT then return streamReadInt32(s)
    elseif tag == T_STRING then return streamReadString(s)
    else return streamReadFloat32(s) end
end
local function wireRoundTrip(actionId, args)
    local s = _fdMockStream()
    args = args or {}
    streamWriteString(s, actionId)
    local n = #args
    streamWriteInt32(s, n)
    for i = 1, n do writeValue(s, args[i]) end

    local outId = streamReadString(s)
    local outN  = streamReadInt32(s)
    local out = {}
    for i = 1, outN do out[i] = readValue(s) end
    return outId, out, s
end

-- Fake NetworkSync core, enough of NetworkSync:registerAction/_applyAction/requestAction.
local function fakeNS(mode)
    local ns = { actions = {}, handlerErr = nil }
    function ns:registerAction(id, def) self.actions[id] = def end
    function ns:registerModule() end
    function ns:markDirty() end
    function ns:syncNow() end
    function ns:_applyAction(id, args, _conn)
        local a = self.actions[id]
        if a == nil then self.handlerErr = "unregistered " .. tostring(id); return end
        local ok, err = pcall(a.onAction, nil, args)
        if not ok then self.handlerErr = err end
    end
    function ns:requestAction(id, args)
        local outId, out, s = wireRoundTrip(id, args)
        self.lastStream = s
        self:_applyAction(outId, out, "conn")
        return true
    end
    return ns
end

local function setup(mode)
    freshManager()
    g_currentMission.getIsServer = function() return mode ~= "wire" end
    g_currentMission.networkSync = nil
    g_networkSync = nil
    if mode == "absent-host" then
        g_server = {}
    elseif mode == "absent-client" then
        g_server = nil
    else
        g_server = {}
        g_networkSync = fakeNS(mode)
    end
    FDNetworkSyncBridge.register()
    return g_networkSync
end

-- Fake UI objects
local lastStatus
local function fakeDialog()
    return setmetatable({
        depotId          = 7,
        orderAmount      = 1500,
        selectedFillType = { name = "FERTILIZER", fillTypeIndex = 12, displayName = "Fertilizer" },
        selectedProduct  = { name = "FERTILIZER", fillTypeIndex = 12, displayName = "Fertilizer",
                             litresPerUnit = 1000, productLabel = "bag" },
        productQuantity  = 2,
        sellList         = { { ft = { name = "LIME", fillTypeIndex = 9, displayName = "Lime" }, liters = 800 } },
        statusText       = { setText = function(_, t) lastStatus = t end },
    }, { __index = DepotDialog })
end
local function fakeSettingsDialog()
    local opt = function(state) return { getState = function() return state end } end
    return setmetatable({
        optSeasonalPricing = opt(2),   -- true
        optStorageCapacity = opt(3),   -- 50000
        optSellRatio       = opt(4),   -- 0.80
        optBuyMultiplier   = opt(2),   -- 1.00
        optDebugLogging    = opt(1),   -- false
        close              = function() end,
    }, { __index = DepotSettingsDialog })
end
local function fakeManager()
    return setmetatable({
        _pendingDepotSell = { depotId = 7, fillTypeName = "LIME", fillTypeIndex = 9,
                              amount = 640, farmId = 3 },
    }, { __index = DepotManager })
end
g_localPlayer = { farmId = 3 }

local function checkFive(name, got, want)
    if got == nil then T.ok(name, false, "handler never ran"); return end
    for i = 1, 5 do
        T.eq(name .. "[" .. i .. "]", got[i], want[i])
    end
end

-- ── the four actions, three transports ─────────────────────
for _, mode in ipairs({ "host", "wire", "absent-host" }) do
    local ns = setup(mode)

    lastStatus = nil
    fakeDialog():onConfirmOrder()
    checkFive(mode .. " purchase", received.buy, { 7, "FERTILIZER", 12, 1500, 3 })
    T.ok(mode .. " purchase status is Filling", lastStatus ~= nil and lastStatus:find("^Filling") ~= nil,
        "status was " .. tostring(lastStatus))

    fakeDialog():onProductConfirm()
    checkFive(mode .. " product order", received.order, { 7, "FERTILIZER", 12, 2, 3 })

    fakeDialog():executeSell(1)
    checkFive(mode .. " dialog sell", received.sell, { 7, "LIME", 9, 800, 3 })

    received.sell = nil
    fakeManager():_onDepotSellConfirm(true)
    checkFive(mode .. " vehicle sell", received.sell, { 7, "LIME", 9, 640, 3 })

    local s = g_DepotManager.settings
    s.seasonalPricing, s.storageCapacity, s.sellRatio, s.buyMultiplier, s.debugLogging = false, 0, 0, 0, true
    fakeSettingsDialog():onApplySettings()
    T.eq(mode .. " settings seasonalPricing", s.seasonalPricing, true)
    T.eq(mode .. " settings storageCapacity", s.storageCapacity, 50000)
    T.eq(mode .. " settings sellRatio", s.sellRatio, 0.80)
    T.eq(mode .. " settings buyMultiplier", s.buyMultiplier, 1.00)
    T.eq(mode .. " settings debugLogging", s.debugLogging, false)

    if ns ~= nil then
        T.eq(mode .. " no handler error", ns.handlerErr, nil)
    end
    if mode == "wire" then
        T.eq("wire stream type errors", ns.lastStream.typeErrors, 0)
        T.eq("wire stream underflows", ns.lastStream.underflows, 0)
    end
end

-- ── NetworkSync absent on a remote client: nothing can be sent ──
setup("absent-client")
lastStatus = nil
fakeDialog():onConfirmOrder()
T.eq("absent-client purchase handler not run", received.buy, nil)
T.ok("absent-client purchase does not claim Filling",
    lastStatus ~= nil and lastStatus:find("^Filling") == nil, "status was " .. tostring(lastStatus))
T.eq("absent-client sendAction returns false",
    FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PURCHASE, { 7, "X", 1, 1, 1 }), false)
