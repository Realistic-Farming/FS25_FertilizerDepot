-- MAINT-258-hub_reader_entry_test.lua
--
-- MAINTENANCE row 258 (the depot's half): the depot passes SettingsHub a reader, so a change made in the
-- depot's own settings dialog shows in the hub, the Tablet and the hub's broadcast.
--
-- THE DEFECT THIS PINS (development a0bd601): the depot registers with SettingsHub as selfPersisted
-- (src/integrations/DepotSettingsHubBridge.lua:56-65), so the hub mirrors the values it registered with. The
-- depot's own settings dialog (src/ui/DepotSettingsDialog.lua:205-235) sends each change through
-- FDNetworkSyncBridge's settings action, whose handler writes g_DepotManager.settings
-- (src/integrations/FDNetworkSyncBridge.lua:141-178) and never tells the hub, so the Tablet showed the stale
-- value. SettingsHub's row 258 PR lets a selfPersisted companion pass read(key); this passes one, reading
-- the table the hub's own onChange (applyChange) writes.
--
-- THE ENTRY-POINT BAR IS GROUP E. main.lua's own registration statements (its onMissionLoadFinished:
-- DepotSettingsHubBridge.register(g_DepotManager), then FDNetworkSyncBridge.register()) run from main.lua's
-- text, with the real bridges loaded, on the host. The hub and NetworkSync are reachable only as the
-- mission's handles: the hub records the spec registerModule receives (the hub's own behaviour is
-- SettingsHub's bench), and NetworkSync records the actions registerAction receives. The depot's settings are
-- the real DepotSettings object. The change enters where a player makes it: the depot's own dialog,
-- onApplySettings, with its options set as a player sets them.
--
--   E0  the sites are present once; the registration is selfPersisted and carries a reader
--   E1  after the dialog's apply (sell ratio 0.90, seasonal pricing off), the reader answers 0.9 and false,
--       while the values the hub registered are still the old ones
--   E2  for every registered key, the reader answers the depot's own value
--   E3  an unknown key answers nil (the hub then shows its copy)
--!load: src/config/Constants.lua, src/integrations/OptionScalingResolver.lua, src/config/DepotSettings.lua, src/DepotLogger.lua, src/integrations/DepotSettingsHubBridge.lua, src/integrations/FDNetworkSyncBridge.lua, src/ui/DepotSettingsDialog.lua
--!text: src/main.lua

local function group(name, fn)
  local ok, err = pcall(fn)
  if not ok then T.ok(name .. " [group raised: " .. tostring(err) .. "]", false) end
end

local MAIN = ((_SOURCE_TEXT and _SOURCE_TEXT["src/main.lua"]) or ""):gsub("\r\n", "\n")
local SITE = "    DepotSettingsHubBridge.register(g_DepotManager)\n    FDNetworkSyncBridge.register()\n"
local count = 0
do
  local from = 1
  while true do
    local k = MAIN:find(SITE, from, true)
    if k == nil then break end
    count, from = count + 1, k + 1
  end
end

-- The mission: the host, with SettingsHub and NetworkSync on it and nowhere else.
local SPEC, ACTIONS = nil, {}
g_server = {}
g_currentMission.isMasterUser = true
g_currentMission.getIsServer = function() return true end
g_currentMission.settingsHub = { registerModule = function(_, modId, spec) if modId == "FertilizerDepot" then SPEC = spec end return true end }
g_currentMission.networkSync = {
  registerAction = function(_, id, spec) ACTIONS[id] = spec return true end,
  registerModule = function() return true end,
  syncNow = function() end,
}
g_settingsHub, g_networkSync = nil, nil

-- The depot's manager, as DepotManager.new builds its settings (src/DepotManager.lua).
g_DepotManager = { settings = DepotSettings.new() }

local function option(state) return { getState = function() return state end } end
local function indexOf(tbl, v) for i, x in ipairs(tbl) do if x == v then return i end end return nil end

group("E", function()
  T.eq("E0 main.lua's registration site is present once", count, 1)
  local run = load(SITE, "=main.lua site", "t", _ENV)
  run()
  T.ok("E0 [reached] the depot registered with the mission's SettingsHub as selfPersisted, with a reader, and its settings action with the mission's NetworkSync",
    SPEC ~= nil and SPEC.selfPersisted == true and type(SPEC.read) == "function"
    and ACTIONS[FDNetworkSyncBridge.ACTION_SETTINGS] ~= nil)

  local registered = {}
  for _, def in ipairs(SPEC.adminSettings) do registered[def.id] = def.default end

  -- A player opens the depot's own settings dialog and applies: sell ratio 0.90, seasonal pricing off.
  local s = g_DepotManager.settings
  local dlg = setmetatable({
    close = function() end,
    optSeasonalPricing = option(1),
    optStorageCapacity = option(indexOf(DepotSettings.CAPACITY_OPTIONS, s.storageCapacity)),
    optSellRatio       = option(indexOf(DepotSettings.SELL_RATIO_OPTIONS, 0.90)),
    optBuyMultiplier   = option(indexOf(DepotSettings.BUY_MULT_OPTIONS, s.buyMultiplier)),
    optDebugLogging    = option(1),
  }, { __index = DepotSettingsDialog })
  dlg:onApplySettings()

  T.eq("E1 [entry point] NAMED (row 258): after the depot's own dialog applied, the reader answers the new sell ratio and the switched-off seasonal pricing",
    tostring(SPEC.read("sellRatio")) .. "/" .. tostring(SPEC.read("seasonalPricing")), "0.9/false")
  T.eq("E1 while the values the hub registered are still the old ones (what the hub showed before)",
    tostring(registered.sellRatio) .. "/" .. tostring(registered.seasonalPricing), "0.8/true")

  local all, mismatch = 0, {}
  for _, def in ipairs(SPEC.adminSettings) do
    all = all + 1
    if SPEC.read(def.id) ~= s[def.id] then mismatch[#mismatch + 1] = def.id end
  end
  T.eq("E2 for every registered key the reader answers the depot's own value", all .. " " .. table.concat(mismatch, ","), "5 ")
  T.eq("E3 an unknown key answers nil, so the hub shows its own copy", SPEC.read("noSuchKey"), nil)
end)

g_server, g_DepotManager = nil, nil
