-- =========================================================
-- FS25 Fertilizer Depot - MarketDynamics Integration Bridge
-- =========================================================
-- Registers a consumer price modifier with FS25_MarketDynamics
-- so that fertilizer/pesticide fill type prices can be
-- adjusted based on market conditions.
--
-- API:
--   register()              — called from onMissionLoadFinished
--   unregister()            — called from delete / cleanup
--   isInstalled()           → boolean
-- =========================================================

DepotMarketDynamicsBridge = DepotMarketDynamicsBridge or {}

local MODIFIER_NAME = "FertilizerDepot"

local function isFertilizerFillTypeName(name)
    if not name then return false end
    for _, ftName in ipairs(DepotConstants.SF_FILL_TYPE_NAMES) do
        if ftName == name then return true end
    end
    for _, entry in ipairs(DepotConstants.VANILLA_FILL_TYPES) do
        if entry.name == name then return true end
    end
    return false
end

local function modifierFn(ctx)
    if not ctx or not ctx.fillTypeIndex then return nil end
    if not g_fillTypeManager then return nil end
    local ftName = g_fillTypeManager:getFillTypeNameByIndex(ctx.fillTypeIndex)
    if not ftName or not isFertilizerFillTypeName(ftName) then
        return nil
    end
    return 1.0
end

local function getHandle()
    return g_currentMission and g_currentMission.MarketDynamics
end

function DepotMarketDynamicsBridge.register()
    local md = getHandle()
    if md == nil or type(md.registerPriceModifier) ~= "function" then
        DepotLogger.info("MarketDynamics not detected; skipping price modifier registration")
        return
    end
    local ok, err = pcall(md.registerPriceModifier, md, MODIFIER_NAME, modifierFn)
    if ok then
        DepotLogger.info("Registered price modifier '" .. MODIFIER_NAME .. "' with MarketDynamics")
    else
        DepotLogger.warning("MarketDynamics registration failed: " .. tostring(err))
    end
end

function DepotMarketDynamicsBridge.unregister()
    local md = getHandle()
    if md == nil or type(md.unregisterPriceModifier) ~= "function" then return end
    pcall(md.unregisterPriceModifier, md, MODIFIER_NAME)
    DepotLogger.info("Unregistered price modifier '" .. MODIFIER_NAME .. "' from MarketDynamics")
end

function DepotMarketDynamicsBridge.isInstalled()
    local md = getHandle()
    return md ~= nil
end
