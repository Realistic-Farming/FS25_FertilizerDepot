-- MAINT-252-soil_handle_entry_test.lua
--
-- MAINTENANCE row 252 (Bob's fleet sweep row 11): the depot sees SoilFertilizer in a game.
--
-- THE DEFECT THIS PINS (development 78aed98): SoilFertilizerBridge:isInstalled read the bare global
-- g_SoilFertilityManager (src/integrations/SoilFertilizerBridge.lua:21). Soil writes that global into
-- its own mod environment (getfenv(0), SoilFertilizer main.lua:758), so the read was nil in a game and
-- the depot logged "Post-load: SF installed: false" in a session that loaded Soil (Tyson's log.txt of
-- 2026-10-05, line 1895). Soil also publishes its manager on the mission (:761).
--
-- THE FIX: isInstalled reads g_currentMission.soilFertilityManager first, the bare global as the
-- fallback, as the depot's other bridges read their handles.
--
-- THE ENTRY-POINT BAR IS GROUP E. main.lua's own post-load statements (its onMissionLoadFinished:
-- invalidate the bridge's cache, log "Post-load: SF installed: %s") run from main.lua's text
-- (--!text), with the real SoilFertilizerBridge loaded; the depot manager is a table carrying the real
-- bridge, as DepotManager.new builds it (src/DepotManager.lua:75). Soil is modelled in its own mod
-- environment, built as dataS mods.lua:482-520 builds one, and its load (SoilFertilizer main.lua:758,
-- :761) puts its manager into that environment and onto the mission. DepotLogger.info is recorded.
--
--   E0  the site is present once; the depot's environment has no g_SoilFertilityManager; Soil's has it
--   E1  with Soil on the mission, the post-load line reads "SF installed: true"
--   E2  with no Soil, it reads "SF installed: false"
--
--!load: src/config/Constants.lua, src/DepotLogger.lua, src/integrations/SoilFertilizerBridge.lua
--!text: src/main.lua

local function group(name, fn)
  local ok, err = pcall(fn)
  if not ok then T.ok(name .. " [group raised: " .. tostring(err) .. "]", false) end
end

local MAIN = ((_SOURCE_TEXT and _SOURCE_TEXT["src/main.lua"]) or ""):gsub("\r\n", "\n")
local FIRST = "    -- SF global is now available if installed\n"
local LAST = "        tostring(g_DepotManager.sfBridge:isInstalled()))\n"
local i = MAIN:find(FIRST, 1, true)
local j = i and MAIN:find(LAST, i, true)
local SITE = (i and j) and MAIN:sub(i, j + #LAST - 1) or nil
local count = 0
do
  local from = 1
  while true do
    local k = MAIN:find(FIRST, from, true)
    if k == nil then break end
    count, from = count + 1, k + 1
  end
end

-- DepotLogger.info, recorded (the real one prints; the record is what the bar reads).
local LOG = {}
local realInfo = DepotLogger.info
DepotLogger.info = function(fmt, ...)
  LOG[#LOG + 1] = select("#", ...) > 0 and string.format(fmt, ...) or fmt
  return realInfo(fmt, ...)
end

local function postLoad()
  LOG = {}
  g_DepotManager = { sfBridge = SoilFertilizerBridge.new() }
  assert(load(SITE, "=src/main.lua", "t", setmetatable({}, { __index = _G })))()
  for _, line in ipairs(LOG) do
    if line:find("Post-load: SF installed:", 1, true) then return line end
  end
  return nil
end

-- Soil, in its own mod environment (mods.lua:482-520).
local soilEnv = setmetatable({}, { __index = _G })
soilEnv._G = soilEnv
soilEnv.getfenv = function() return soilEnv end
local SOIL_LOAD = [==[
local mission = ...
local sfm = { soilSystem = {} }
-- SoilFertilizer main.lua:758 and :761.
getfenv(0)["g_SoilFertilityManager"] = sfm
mission.soilFertilityManager = sfm
return sfm
]==]

group("E0", function()
  T.ok("E0 main.lua's post-load site is present", SITE ~= nil)
  T.eq("E0 and present once", count, 1)
  g_currentMission = {}
  assert(load(SOIL_LOAD, "=SoilFertilizer main.lua (model)", "t", soilEnv))(g_currentMission)
  T.eq("E0 the depot's environment has no g_SoilFertilityManager", g_SoilFertilityManager, nil)
  T.ok("E0 Soil's own environment has it, and the mission carries it",
    soilEnv.g_SoilFertilityManager ~= nil and g_currentMission.soilFertilityManager == soilEnv.g_SoilFertilityManager)
end)

group("E1", function()
  T.eq("E1 with Soil on the mission the post-load line reads SF installed: true", postLoad(), "Post-load: SF installed: true")
end)

group("E2", function()
  g_currentMission = {}
  T.eq("E2 with no Soil it reads SF installed: false", postLoad(), "Post-load: SF installed: false")
end)
