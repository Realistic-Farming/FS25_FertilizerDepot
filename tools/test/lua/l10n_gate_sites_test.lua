--!load: src/config/Constants.lua, src/config/DepotSettings.lua, src/DepotLogger.lua, src/integrations/FDNetworkSyncBridge.lua, src/ui/DepotDialog.lua, src/ui/DepotSettingsDialog.lua
--
-- l10n_gate_sites_test.lua - the repaired translation gates, driven through the real
-- sites (MAINTENANCE row 63, the FertilizerDepot analogue of SoilFertilizer's #973).
--
-- THE ENTRY-POINT BAR. The four tr() helpers (DepotDialog, DepotSettingsDialog,
-- DepotManager, FdRfPdaGuest) are one text, and a copy of that text inside a test file
-- would pass with no src file touched. So this bar drives two of the real ones through
-- the public methods production enters them by: DepotDialog:onConfirmOrder with no fill
-- type selected renders its first status line through tr(), and
-- DepotSettingsDialog:onGuiSetupFinished fills the ON/OFF option texts through tr().
-- Nothing here builds an i18n answer by hand for the happy path: the prelude's g_i18n
-- is the engine model, and a translation exists only when a row registers one with
-- setText, exactly as a loaded locale would.
--
-- NOT DRIVEN, same text: DepotManager's helper renders an input-binding prompt (needs
-- g_inputBinding and a registered action event) and FdRfPdaGuest's paints a GUI tree.
--
-- The engine, from D:\FS25_Decoded\dataS\scripts_decompiled: I18N.lua:175 getText returns
-- "Missing '<key>' in l10n<suffix>.xml" for an absent key (:186), never nil, never "",
-- never the "$l10n_" attribute prefix; I18N.lua:194 hasText is the engine's own answer to
-- "does this key exist". The shipped gates compared getText's return against "$l10n_"
-- (dead: getText cannot return it) and, in three of the four, against the sentence's
-- "Missing '" prefix (a bet on how the engine renders a failure). DepotSettingsDialog's
-- gate had only the dead comparison, so every missing key there reached the player as
-- the engine's diagnostic.

local KEY_SELECT = "fd_depot_select_first"
local ENGLISH_SELECT = "Select a fill type first."

-- ── DepotDialog through onConfirmOrder ───────────────────────────────────────
local lastStatus
local function dialog()
    return setmetatable({ statusText = { setText = function(_, t) lastStatus = t end } },
        { __index = DepotDialog })
end
local function status()
    lastStatus = nil
    local ok, err = pcall(function() dialog():onConfirmOrder() end)
    if not ok then return "<error: " .. tostring(err) .. ">" end
    return lastStatus
end
local missing = g_i18n:getText(KEY_SELECT)

T.eq("D1 no locale loaded: the status is the English fallback, not the engine's sentence",
     status(), ENGLISH_SELECT)
T.ok("D1b and that sentence is what getText returns for the key, so the gate refused it",
     missing == "Missing '" .. KEY_SELECT .. "' in l10n_en.xml")

g_i18n:setText(KEY_SELECT, "Zuerst eine Fuellart waehlen.")
T.eq("D2 a registered translation reaches the status", status(), "Zuerst eine Fuellart waehlen.")
g_i18n.texts[KEY_SELECT] = nil
T.eq("D2b and unregistering it restores the fallback", status(), ENGLISH_SELECT)

do
    local saved = g_i18n
    g_languageSuffix = "_de"
    T.eq("D3 a non-English client with the key absent still gets the fallback (the gate never compares the sentence)",
         status(), ENGLISH_SELECT)
    g_languageSuffix = "_en"

    g_i18n = { getText = function(_self, key) return key end }
    T.eq("D4 an i18n that cannot answer hasText is refused: the key-returning fiction", status(), ENGLISH_SELECT)
    g_i18n = { getText = function(_self, _key) return "" end }
    T.eq("D5 an i18n that cannot answer hasText is refused: this prelude's old empty-string fiction",
         status(), ENGLISH_SELECT)
    g_i18n = { getText = function(_self, _key) return "Bogus" end }
    T.eq("D6 an i18n that cannot answer hasText is refused even when getText returns a plausible string",
         status(), ENGLISH_SELECT)
    g_i18n = { hasText = function(_self, key) return "Bogus" end, getText = function(_self, _key) return "Bogus" end }
    T.eq("D7 a truthy non-boolean hasText is not the engine's true (I18N.lua:209 returns a boolean)",
         status(), ENGLISH_SELECT)
    g_i18n = { hasText = function() return true end, getText = function() return { "not a string" } end }
    T.eq("D8 a key that exists with a non-string value falls back", status(), ENGLISH_SELECT)
    g_i18n = { hasText = function() return true end, getText = function() return "" end }
    T.eq("D9 a key that exists with an empty value falls back", status(), ENGLISH_SELECT)
    g_i18n = { hasText = function() error("boom") end, getText = function() return "Bogus" end }
    T.eq("D10 an i18n whose hasText raises is refused, not propagated", status(), ENGLISH_SELECT)
    g_i18n = { hasText = function() return true end, getText = function() error("boom") end }
    T.eq("D11 an i18n whose getText raises is refused, not propagated", status(), ENGLISH_SELECT)
    g_i18n = nil
    T.eq("D12 no i18n at all: the fallback", status(), ENGLISH_SELECT)
    g_i18n = saved
end
T.eq("D13 the shared i18n survived the swaps", status(), ENGLISH_SELECT)

-- ── DepotSettingsDialog through onGuiSetupFinished ───────────────────────────
local function settingsTexts()
    local captured = {}
    local function option(id) return { setTexts = function(_, texts) captured[id] = texts end } end
    local self = setmetatable({
        getDescendantById = function(_, id)
            if id == "optSeasonalPricing" or id == "optDebugLogging" then return option(id) end
            return nil
        end,
    }, { __index = DepotSettingsDialog })
    local ok, err = pcall(function() DepotSettingsDialog.onGuiSetupFinished(self) end)
    if not ok then return "<error: " .. tostring(err) .. ">" end
    local a, b = captured.optSeasonalPricing or {}, captured.optDebugLogging or {}
    return table.concat({ tostring(a[1]), tostring(a[2]), tostring(b[1]), tostring(b[2]) }, "|")
end

T.eq("S1 no locale loaded: the ON/OFF options are the English fallbacks, not the engine's sentence",
     settingsTexts(), "OFF|ON|OFF|ON")
g_i18n:setText("fd_settings_off", "AUS")
g_i18n:setText("fd_settings_on", "AN")
T.eq("S2 registered translations reach both option lists", settingsTexts(), "AUS|AN|AUS|AN")
g_i18n.texts.fd_settings_off, g_i18n.texts.fd_settings_on = nil, nil
T.eq("S3 and unregistering them restores the fallbacks", settingsTexts(), "OFF|ON|OFF|ON")
do
    local saved = g_i18n
    g_i18n = { getText = function(_self, key) return "$l10n_" .. key end }
    T.eq("S4 the shape the dead comparison was written for is refused too, by hasText rather than by the prefix",
         settingsTexts(), "OFF|ON|OFF|ON")
    g_i18n = saved
end
