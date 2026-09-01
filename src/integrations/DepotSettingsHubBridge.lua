-- =========================================================
-- FS25 Fertilizer Depot - SettingsHub bridge
-- =========================================================
-- Author: TisonK
-- =========================================================
-- Optional bridge to FS25_SettingsHub. Safe if SettingsHub is not
-- installed (register() just no-ops). Purpose: let the FarmTablet
-- System Settings app list Fertilizer Depot's settings.
--
-- g_DepotManager.settings (a DepotSettings instance, persisted to
-- FS25_FertilizerDepot.xml on game save) stays the source of truth. This
-- mirrors the settings into SettingsHub for display; the tablet app is
-- read-only for now, so applyChange only sets the value back on that table
-- (the next game save persists it via onSaveToXML). Depot's discrete preset
-- settings map onto SettingsHub's "enum" type using the same option tables
-- the in-game settings dialog uses, so nothing new is invented here.
-- =========================================================

DepotSettingsHubBridge = DepotSettingsHubBridge or {}

local function applyChange(key, value)
    local mgr = g_DepotManager
    if mgr == nil or mgr.settings == nil then return end
    mgr.settings[key] = value
    -- debugLogging mirrors onto the logger (same as main.lua onMissionLoad).
    if key == "debugLogging" and DepotLogger ~= nil then
        DepotLogger._debug = value
    end
    -- Sync the changed settings to all clients via NetworkSync
    if FDNetworkSyncBridge ~= nil and FDNetworkSyncBridge.stateActive then
        FDNetworkSyncBridge.syncNow()
    end
end

function DepotSettingsHubBridge.register(mgr)
    -- The reliable cross-mod handle is g_currentMission.settingsHub (the same one
    -- FarmTablet reads). The bare g_settingsHub global is only visible inside
    -- SettingsHub's own mod environment, so it reads back nil from here.
    local hub = (g_currentMission ~= nil and g_currentMission.settingsHub) or g_settingsHub
    if hub == nil then
        DepotLogger.info("SettingsHub not detected; skipping tablet registration")
        return
    end
    if mgr == nil or mgr.settings == nil then return end
    local s = mgr.settings

    local defs = {
        { id = "seasonalPricing", type = "bool", default = s.seasonalPricing, adminOnly = true,  label = "Seasonal Pricing" },
        { id = "storageCapacity", type = "enum", default = s.storageCapacity, adminOnly = true,  values = DepotSettings.CAPACITY_OPTIONS,   label = "Depot Storage Capacity (L)" },
        { id = "sellRatio",       type = "enum", default = s.sellRatio,       adminOnly = true,  values = DepotSettings.SELL_RATIO_OPTIONS, label = "Sell Price Ratio" },
        { id = "buyMultiplier",   type = "enum", default = s.buyMultiplier,   adminOnly = true,  values = DepotSettings.BUY_MULT_OPTIONS,   label = "Buy Price Multiplier" },
        { id = "debugLogging",    type = "bool", default = s.debugLogging,    adminOnly = false, label = "Debug Logging" },
    }

    local ok, err = pcall(function()
        hub:registerModule("FertilizerDepot", {
            adminSettings = defs,
            onChange      = function(key, value, playerId) applyChange(key, value) end,
            -- We own our persistence (FS25_FertilizerDepot.xml, loaded in onMissionLoad
            -- before this registration runs), so the hub must mirror for display only:
            -- never restore its own stale copy and replay it back through onChange on
            -- load. Without this the hub could push a stale value over our real one every
            -- load (the trap SoilFertilizer hit that silently disabled the mod).
            selfPersisted = true,
        })
    end)

    if ok then
        DepotLogger.info("Registered with SettingsHub (%d setting(s))", #defs)
    else
        DepotLogger.warning("SettingsHub registration failed: %s", tostring(err))
    end
end
