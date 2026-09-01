-- =========================================================
-- FS25 Fertilizer Depot - Silo Placeable Specialization
-- =========================================================
-- Registers placed silos with DepotManager so the proximity
-- system can detect vehicles near the silo and trigger the
-- pre-order fill flow.

local modName = (FertilizerDepotModName or g_currentModName)

---@class PlaceableSilo
-- 2026-08-22 FAIL-FIX (map hung at 88%). NEVER write "PlaceableSilo = PlaceableSilo or {}" here.
-- PlaceableSilo is a BASE GAME class (dataS/scripts/placeables/specializations/PlaceableSilo.lua).
-- A mod sandbox reads through to the engine globals, so the "or" branch adopted the ENGINE's own
-- PlaceableSilo table and the assignments below then overwrote the real onLoad /
-- onPostFinalizePlacement / onDelete on it. The engine's silo specialization therefore never built
-- its own spec state and died with
--   PlaceableSilo.lua:369: attempt to index nil with number
-- inside loadSharedI3DFileAsyncFinished. Six placeable async loads never signalled completion and
-- the map load stopped at 88% forever. Introduced by the 2026-08-22 hot-reload conformance sweep,
-- which rewrote 438 plain class declarations to "X = X or {}" without excluding base-game names;
-- it only surfaced once the live loose folders started loading instead of the 07:00 zips.
-- modDesc pins the global name (placeableSpecializations className="PlaceableSilo"), so the class
-- keeps that name but is latched under a mod-unique global: still reload-safe across a re-source,
-- which was the conformance intent, without ever reading the engine's name.
FertilizerDepotPlaceableSilo = FertilizerDepotPlaceableSilo or {}
PlaceableSilo = FertilizerDepotPlaceableSilo
PlaceableSilo.SPEC_TABLE_NAME = "spec_" .. modName .. ".fertilizerSilo"

function PlaceableSilo.prerequisitesPresent(...)
    return true
end

function PlaceableSilo.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad",                 PlaceableSilo)
    SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", PlaceableSilo)
    SpecializationUtil.registerEventListener(placeableType, "onDelete",               PlaceableSilo)
end

function PlaceableSilo.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("FertilizerSilo")
    schema:register(XMLValueType.NODE_INDEX, basePath .. ".fertilizerSilo#loadingStation",
        "Loading station node used as vehicle search origin for fill orders")
    schema:setXMLSpecializationType()
end

function PlaceableSilo:onLoad(savegame)
    local spec = { siloId = nil, loadStationNode = nil }
    self[PlaceableSilo.SPEC_TABLE_NAME] = spec
    spec.loadStationNode = self.xmlFile:getValue(
        "placeable.fertilizerSilo#loadingStation", nil,
        self.components, self.i3dMappings)
    if spec.loadStationNode == nil then
        DepotLogger.warning("PlaceableSilo: loadingStation node not found — using rootNode for vehicle search")
    end
end

function PlaceableSilo:onPostFinalizePlacement()
    if g_DepotManager then
        local spec = self[PlaceableSilo.SPEC_TABLE_NAME]
        spec.siloId = g_DepotManager:registerSilo(self, spec.loadStationNode)
    end
end

function PlaceableSilo:onDelete()
    local spec = self[PlaceableSilo.SPEC_TABLE_NAME]
    if not spec then return end
    if g_DepotManager and spec.siloId then
        g_DepotManager:unregisterSilo(spec.siloId)
    end
    self[PlaceableSilo.SPEC_TABLE_NAME] = nil
end
