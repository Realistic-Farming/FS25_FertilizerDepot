-- =========================================================
-- FS25 Fertilizer Depot - Entry Point
-- =========================================================
-- Load order matters: constants first, then logger, then all
-- subsystems, then network events, then UI.

-- Hot-reload latch (FuelCosts reference): g_currentModDirectory and
-- g_currentModName are nil on a live re-source, so they are latched into
-- module globals on first load, with a g_modsDirectory loose-folder fallback.
FertilizerDepotModDirectory = FertilizerDepotModDirectory
    or g_currentModDirectory
    or (g_modsDirectory ~= nil and (g_modsDirectory .. "FS25_FertilizerDepot/") or nil)
FertilizerDepotModName = FertilizerDepotModName or g_currentModName or "FS25_FertilizerDepot"
local modDir = FertilizerDepotModDirectory
local modName = FertilizerDepotModName

-- Phase 1: Config
source(modDir .. "src/config/Constants.lua")
source(modDir .. "src/integrations/OptionScalingResolver.lua")
source(modDir .. "src/config/DepotSettings.lua")
source(modDir .. "src/DepotLogger.lua")

-- Phase 2: Core systems
source(modDir .. "src/integrations/SoilFertilizerBridge.lua")
source(modDir .. "src/integrations/DepotProStaffBridge.lua")
source(modDir .. "src/integrations/DepotMarketDynamicsBridge.lua")
source(modDir .. "src/integrations/DepotFuelCostsBridge.lua")
source(modDir .. "src/integrations/DepotSettingsHubBridge.lua")
source(modDir .. "src/integrations/DepotMasterHUDBridge.lua")
source(modDir .. "src/DepotPricing.lua")
source(modDir .. "src/DepotSystem.lua")
source(modDir .. "src/delivery/DeliverySystem.lua")
source(modDir .. "src/DepotManager.lua")

-- Phase 3: Network (NetworkSync bridge replaces old event classes)
source(modDir .. "src/integrations/FDNetworkSyncBridge.lua")

-- Phase 4: Placeables
source(modDir .. "src/placeable/PlaceableDepot.lua")
source(modDir .. "src/placeable/PlaceableSilo.lua")
source(modDir .. "src/placeable/PlaceableDepotPickup.lua")

-- Phase 5: UI (lazy-loaded on first open, but class must be defined)
source(modDir .. "src/ui/DepotDialog.lua")
source(modDir .. "src/ui/DepotSettingsDialog.lua")
source(modDir .. "src/ui/DepotHUD.lua")

-- Esc RF PDA guest (Wizard local; keep across development merge)
source(FertilizerDepotModDirectory .. "src/gui/RfEscModules.lua")
source(FertilizerDepotModDirectory .. "src/gui/RfPdaMenuPage.lua")
source(FertilizerDepotModDirectory .. "src/gui/RfEscBootstrap.lua")
source(FertilizerDepotModDirectory .. "src/gui/RfEscUiDebugger.lua")
source(FertilizerDepotModDirectory .. "src/gui/FdRfPdaGuest.lua")

-- ─── Mission00 Lifecycle Hooks ───────────────────────────

local function onMissionLoad(mission, ...)
    getfenv(0).g_DepotManager = DepotManager.new()
    g_DepotManager:initialize()

    -- Esc soft-detect prefer: also publish the mission handle (same object).
    -- FdRfPdaGuest.getMgr reads g_currentMission.depotManager first, then falls back
    -- to the global. Lost when the Phase 3 network refactor rewrote this file.
    if g_currentMission ~= nil then
        g_currentMission.depotManager = g_DepotManager
    end

    -- Load settings from our own XML file (same pattern as FuelCosts, SoilFertilizer).
    -- FSCareerMissionInfo.loadFromXMLFile fires before g_DepotManager exists, so we
    -- read directly here where the manager is guaranteed to be present.
    local missionInfo = mission and mission.missionInfo
    if missionInfo and missionInfo.savegameDirectory then
        local path = missionInfo.savegameDirectory .. "/" .. modName .. ".xml"
        local xmlFile = XMLFile.load("depotSettingsLoad", path)
        if xmlFile then
            g_DepotManager.settings:loadFromXML(xmlFile, "fertilizerDepot.settings")
            DepotLogger._debug = g_DepotManager.settings.debugLogging
            xmlFile:delete()
            DepotLogger.info("Settings loaded from savegame")
        end
    end
    DepotLogger.info("Mission load complete")
end

local _playerInputWrapped = false

local function onMissionLoadFinished(mission, ...)
    if not g_DepotManager then return end
    -- SF global is now available if installed
    g_DepotManager.sfBridge:invalidateCache()
    DepotLogger.info("Post-load: SF installed: %s",
        tostring(g_DepotManager.sfBridge:isInstalled()))

    -- Bedrock bridges (delegate-when-present; each no-ops if its bedrock mod is
    -- absent). Handles (g_currentMission.settingsHub / .masterHUD) are published
    -- by the bedrock mods at Mission00.load, so they are ready by now.
    DepotSettingsHubBridge.register(g_DepotManager)
    DepotMasterHUDBridge.register(g_DepotManager)
    FDNetworkSyncBridge.register()

    -- Pricing integration bridges (pcall-guarded, neutral fallback when absent)
    if g_currentMission and g_currentMission.proStaffManager then
        DepotLogger.info("ProStaffCoOp detected — fertilizer discount active")
    end
    DepotMarketDynamicsBridge.register()

    -- Register Shift+D settings hotkey in PLAYER context.
    -- Pattern mirrors FS25_SoilFertilizer:SoilFertilityManager.lua exactly.
    if PlayerInputComponent and PlayerInputComponent.registerActionEvents and not _playerInputWrapped then
        _playerInputWrapped = true
        local origRegister = PlayerInputComponent.registerActionEvents
        PlayerInputComponent.registerActionEvents = function(inputComp, ...)
            origRegister(inputComp, ...)

            -- Only register for the local (owning) player, not networked players
            if not (inputComp.player and inputComp.player.isOwner) then return end
            -- Guard against double-registration across level reloads
            if g_DepotManager and g_DepotManager._settingsEventId then return end
            if not g_DepotManager then return end

            if not InputAction.FD_OPEN_SETTINGS then
                DepotLogger.warning("InputAction.FD_OPEN_SETTINGS is nil — check modDesc <actions>")
                return
            end

            g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)
            local ok, id = g_inputBinding:registerActionEvent(
                InputAction.FD_OPEN_SETTINGS, g_DepotManager,
                g_DepotManager.openSettingsDialog, false, true, false, true)
            if ok and id then
                g_DepotManager._settingsEventId = id
                g_inputBinding:setActionEventTextVisibility(id, false)
                DepotLogger.info("Shift+D (FD_OPEN_SETTINGS) registered in PLAYER context")
            else
                DepotLogger.warning("Shift+D registration failed — registerActionEvent returned false")
            end

            local dragOk, dragId = g_inputBinding:registerActionEvent(
                InputAction.FD_HUD_DRAG, g_DepotManager,
                g_DepotManager.toggleHUDEditMode, false, true, false, true)
            if dragOk and dragId then
                g_DepotManager._hudDragEventId = dragId
                g_inputBinding:setActionEventTextPriority(dragId, GS_PRIO_NORMAL)
                DepotLogger.info("FD_HUD_DRAG registered in PLAYER context")
            else
                DepotLogger.warning("FD_HUD_DRAG registration failed")
            end

            g_inputBinding:endActionEventsModification()
        end
    end
end

local function onMissionUpdate(mission, dt)
    if g_DepotManager then
        g_DepotManager:update(dt)
    end
end

local function onMissionDraw(mission)
    -- When MasterHUD is present it owns the single draw loop (our draw was
    -- registered as a self-draw via the bridge); stand down so the depot HUD
    -- never draws twice. Absent MasterHUD, this hook runs the draw as before.
    if DepotMasterHUDBridge ~= nil and DepotMasterHUDBridge.active then return end
    if g_DepotManager then
        g_DepotManager:drawHUD()
    end
end

local function onMissionMouseEvent(mission, posX, posY, isDown, isUp, button, ...)
    if g_DepotManager and g_DepotManager.hud then
        g_DepotManager.hud:onMouseEvent(posX, posY, isDown, isUp, button)
    end
end

local function onMissionDelete(mission, ...)
    DepotMarketDynamicsBridge.unregister()
    if g_DepotManager then
        g_DepotManager:delete()
        getfenv(0).g_DepotManager = nil
        if g_currentMission ~= nil then g_currentMission.depotManager = nil end
    end
end

-- Save settings to our own XML file (same pattern as FuelCosts / SoilFertilizer).
-- The xmlFile argument from FSCareerMissionInfo.saveToXMLFile is always nil for mods;
-- we write directly to savegameDirectory instead.
local function onSaveToXML(missionInfo, xmlFile, ...)
    if not g_DepotManager then return end
    if not missionInfo or not missionInfo.savegameDirectory then
        DepotLogger.warning("onSaveToXML: savegameDirectory not available — skipping")
        return
    end
    local path = missionInfo.savegameDirectory .. "/" .. modName .. ".xml"
    local outFile = XMLFile.create("depotSettingsSave", path, "fertilizerDepot")
    if not outFile then
        DepotLogger.warning("onSaveToXML: could not create XML file")
        return
    end
    g_DepotManager.settings:saveToXML(outFile, "fertilizerDepot.settings")
    outFile:save()
    outFile:delete()
    DepotLogger.info("Settings saved to %s", path)
end

-- Send full state snapshot to a joining client via NetworkSync
local function onSendInitialClientState(mission, connection, ...)
    if not g_DepotManager then return end
    if FDNetworkSyncBridge.stateActive and FDNetworkSyncBridge._ns then
        FDNetworkSyncBridge._ns:sendFullSnapshotTo(connection)
    end
end

-- PREPEND so g_DepotManager exists before Mission00.load loads savegame placeables.
-- appendedFunction would create it AFTER onPostFinalizePlacement fires → depotId never set.
Mission00.load                        = Utils.prependedFunction(Mission00.load,                        onMissionLoad)
Mission00.loadMission00Finished       = Utils.appendedFunction(Mission00.loadMission00Finished,       onMissionLoadFinished)
FSBaseMission.update                  = Utils.appendedFunction(FSBaseMission.update,                  onMissionUpdate)
FSBaseMission.draw                    = Utils.appendedFunction(FSBaseMission.draw,                    onMissionDraw)
FSBaseMission.mouseEvent              = Utils.prependedFunction(FSBaseMission.mouseEvent,             onMissionMouseEvent)
FSBaseMission.delete                  = Utils.appendedFunction(FSBaseMission.delete,                  onMissionDelete)
FSBaseMission.sendInitialClientState  = Utils.appendedFunction(FSBaseMission.sendInitialClientState,  onSendInitialClientState)
FSCareerMissionInfo.saveToXMLFile     = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile,     onSaveToXML)


local function _rfEscTryRegister()
    if FdRfPdaGuest ~= nil and type(FdRfPdaGuest.tryRegister) == "function" then
        pcall(FdRfPdaGuest.tryRegister)
    end
end

-- Esc RF PDA: register module after mission/door ready (retry-safe).
-- Restored 2026-08-08: the Phase 3 network refactor rewrote main.lua and dropped these
-- hooks while keeping the source() line, so FdRfPdaGuest.tryRegister was never called
-- and Depot had no Esc module at all. Same shape as Income / Dairy / NPCFavor.
if Mission00 ~= nil then
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
        _rfEscTryRegister()
    end)
end
if FSBaseMission ~= nil then
    FSBaseMission.onStartMission = Utils.appendedFunction(FSBaseMission.onStartMission, function()
        _rfEscTryRegister()
    end)
end

if FSBaseMission ~= nil then
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, function()
        if FdRfPdaGuest ~= nil and type(FdRfPdaGuest.reset) == "function" then
            FdRfPdaGuest.reset()
        end
    end)
end

-- Console commands are registered as methods on DepotManager in DepotManager.lua
-- using `self` as the target, following the FS25 addConsoleCommand pattern.
