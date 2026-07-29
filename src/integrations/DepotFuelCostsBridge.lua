-- =========================================================
-- FS25 Fertilizer Depot - FuelCosts Integration Bridge
-- =========================================================
-- Reads diesel price from FS25_FuelCosts.
-- Read-only display — does not modify prices.
--
-- API:
--   getFuelPrice()  → number (price per liter) | nil
--   isInstalled()   → boolean
-- =========================================================

DepotFuelCostsBridge = {}

function DepotFuelCostsBridge.getFuelPrice()
    local fcm = g_currentMission and g_currentMission.fuelCostsManager
    if fcm == nil or fcm.priceEngine == nil then return nil end
    local ok, price = pcall(fcm.priceEngine.getDisplayPrice, fcm.priceEngine)
    if ok and type(price) == "number" then
        return price
    end
    return nil
end

function DepotFuelCostsBridge.isInstalled()
    return g_currentMission and g_currentMission.fuelCostsManager ~= nil
end
