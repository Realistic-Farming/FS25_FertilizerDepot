--!load: src/config/Constants.lua, src/config/DepotSettings.lua, src/DepotLogger.lua, src/DepotSystem.lua, src/integrations/FDNetworkSyncBridge.lua, src/ui/DepotDialog.lua
--
-- Products tab orders work like the Buy tab (Tyson's ruling, 2026-10-12): stored litres
-- go first and the market covers the rest, so an empty depot still fills a bag or tank
-- order. Before it, DepotDialog:onProductConfirm refused any order larger than the stock
-- ("Insufficient depot stock for this order.") and DepotSystem:orderProduct returned
-- fd_products_no_stock, so a new depot could never sell one; a tester hit exactly that.
--
-- THE ENTRY-POINT BAR: every row starts at the real DepotDialog:onProductConfirm, which
-- calls the real FDNetworkSyncBridge.sendAction; on a host without NetworkSync that runs
-- the real handleProductOrder, which calls the real DepotSystem:orderProduct. Only the
-- engine is modelled (fill types, farm, money, the pallet spawn). Nothing sets depot
-- stock or an order result by hand except the stock a row starts from.
--
-- Control: against development c05fb19 rows P1 and P2 fail (the order is refused).

DepotLogger.info, DepotLogger.warning, DepotLogger.error, DepotLogger.debug =
    function() end, function() end, function() end, function() end

-- ── the engine, modelled ──────────────────────────────────
local UAN32 = 40
g_server = {}
g_localPlayer = { farmId = 3 }
local money = {}          -- every addMoney call
local balance = 1000000
g_currentMission = {
    getIsServer = function() return true end,
    addMoney = function(_, amount, farmId) money[#money + 1] = { amount = amount, farmId = farmId } end,
}
g_fillTypeManager = {
    getFillTypeIndexByName = function(_, n) return n == "UAN32" and UAN32 or nil end,
    getFillTypeByIndex = function(_, i)
        if i == UAN32 then return { palletFilename = "objects/liquidTank/uan32/liquidTank_uan32.xml" } end
        return nil
    end,
}
g_farmManager = { getFarmById = function(_, id) return { getBalance = function() return balance end } end }
MoneyType = MoneyType or {}; MoneyType.PURCHASE_FERTILIZER = MoneyType.PURCHASE_FERTILIZER or 7
ToolType = ToolType or {}; ToolType.UNDEFINED = ToolType.UNDEFINED or 0
VehicleLoadingState = { OK = 1 }
VehiclePropertyState = { OWNED = 1 }
getWorldTranslation = function() return 10, 0, 20 end

local spawns, fills = {}, {}
VehicleLoadingData = {
    new = function()
        local d = {}
        function d:setFilename(f) self.f = f end
        function d:setPosition(x, y, z) self.x, self.z = x, z end
        function d:setPropertyState() end
        function d:setOwnerFarmId(id) self.farmId = id end
        function d:load(cb)
            spawns[#spawns + 1] = self
            local veh = { typeName = "liquidTank", spec_fillUnit = { fillUnits = { {} } } }
            function veh:getFillUnitSupportsFillType() return true end
            function veh:getFillUnitCapacity() return 1000 end
            function veh:addFillUnitFillLevel(farmId, fu, amount, idx) fills[#fills + 1] = { amount = amount, idx = idx } end
            cb(nil, { veh }, VehicleLoadingState.OK)
        end
        return d
    end,
}

-- ── the depot, real ───────────────────────────────────────
local pricing = { calculateBuyCost = function(_, name, liters) return liters * 0.5 end }
local system = DepotSystem.new(pricing)
local depotId = system:registerDepot()
g_DepotManager = {
    depotSystem = system,
    depots = { [depotId] = { rootNode = 1 } },
    depotProductSpawnNodes = {},
    depotUnloadNodes = {},
    settings = DepotSettings.new(),
}

local lastStatus
local function dialog(qty)
    return setmetatable({
        depotId = depotId,
        selectedProduct = { name = "UAN32", fillTypeIndex = UAN32, displayName = "UAN 32",
                            litresPerUnit = DepotConstants.PRODUCT_LITRES_PER_UNIT, productLabel = "tank" },
        productQuantity = qty,
        statusText = { setText = function(_, t) lastStatus = t end },
    }, { __index = DepotDialog })
end
local function reset(stock, bal)
    system:setStorageLevel(depotId, "UAN32", stock)
    balance = bal or 1000000
    money, spawns, fills, lastStatus = {}, {}, {}, nil
end
local function charged() local s = 0; for _, m in ipairs(money) do s = s - m.amount end; return s end
local function noStockLine() return lastStatus ~= nil and lastStatus:find("Insufficient depot stock") ~= nil end

-- P1: an empty depot fills a two-tank order from the market.
reset(0)
dialog(2):onProductConfirm()
T.ok("P1 an empty depot does not refuse the order", not noStockLine())
T.eq("P1 two tanks spawn", #spawns, 2)
T.eq("P1 each is filled with one unit", fills[1] and fills[1].amount, DepotConstants.PRODUCT_LITRES_PER_UNIT)
T.eq("P1 the farm pays for both units once", charged(), 2 * DepotConstants.PRODUCT_LITRES_PER_UNIT * 0.5)
T.eq("P1 the charge is the ordering farm's", money[1] and money[1].farmId, 3)
T.eq("P1 stock stays at zero", system:getStorageLevel(depotId, "UAN32"), 0)

-- P2: partial stock is used first, the rest is bought in, the price is unchanged.
reset(400)
dialog(1):onProductConfirm()
T.eq("P2 one tank spawns", #spawns, 1)
T.eq("P2 the 400 stored litres are taken", system:getStorageLevel(depotId, "UAN32"), 0)
T.eq("P2 the price is the full unit either way", charged(), DepotConstants.PRODUCT_LITRES_PER_UNIT * 0.5)

-- P3: ample stock is drawn down by exactly the order.
reset(3000)
dialog(2):onProductConfirm()
T.eq("P3 two tanks spawn", #spawns, 2)
T.eq("P3 stock falls by the order", system:getStorageLevel(depotId, "UAN32"), 1000)

-- P4: no money, no order: nothing spawns, nothing is charged, stock is untouched.
reset(500, 10)
dialog(1):onProductConfirm()
T.eq("P4 nothing spawns without the money", #spawns, 0)
T.eq("P4 nothing is charged", #money, 0)
T.eq("P4 stock is untouched", system:getStorageLevel(depotId, "UAN32"), 500)
T.ok("P4 and it is not called a stock problem", not noStockLine())
