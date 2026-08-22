-- =========================================================
-- FS25 Fertilizer Depot - ProStaffCoOp Integration Bridge
-- =========================================================
-- Reads fertilizer discount from FS25_ProStaffCoOp.
-- Falls back to 1.0 (no discount) if ProStaff is not installed.
--
-- API:
--   getDiscount(farmId)  → number (multiplier, default 1.0)
--   isInstalled()        → boolean
-- =========================================================

DepotProStaffBridge = DepotProStaffBridge or {}

function DepotProStaffBridge.getDiscount(farmId)
    local psm = g_currentMission and g_currentMission.proStaffManager
    if psm == nil or type(psm.getFertilizerDiscount) ~= "function" then
        return 1.0
    end
    local ok, val = pcall(psm.getFertilizerDiscount, psm, farmId)
    if ok and type(val) == "number" and val > 0 then
        return val
    end
    return 1.0
end

function DepotProStaffBridge.isInstalled()
    local psm = g_currentMission and g_currentMission.proStaffManager
    return psm ~= nil
end
