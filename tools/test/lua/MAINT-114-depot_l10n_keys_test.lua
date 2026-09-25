--!text: xml/depotPlaceable.xml, xml/fillTypes.xml, xml/gui/DepotSettingsDialog.xml, src/ui/DepotDialog.lua, src/ui/DepotSettingsDialog.lua, translations/translation_br.xml, translations/translation_ct.xml, translations/translation_cz.xml, translations/translation_da.xml, translations/translation_de.xml, translations/translation_ea.xml, translations/translation_en.xml, translations/translation_es.xml, translations/translation_fc.xml, translations/translation_fi.xml, translations/translation_fr.xml, translations/translation_hu.xml, translations/translation_id.xml, translations/translation_it.xml, translations/translation_jp.xml, translations/translation_kr.xml, translations/translation_nl.xml, translations/translation_no.xml, translations/translation_pl.xml, translations/translation_pt.xml, translations/translation_ro.xml, translations/translation_ru.xml, translations/translation_sv.xml, translations/translation_tr.xml, translations/translation_uk.xml, translations/translation_vi.xml
-- MAINT-114-depot_l10n_keys_test.lua
--
-- MAINTENANCE row 114: every text the depot's own files name is shipped in every language
-- file. The engine loads ONE file per language (mods.lua:783-805) with no per-key English
-- fallback, and a production's name params go through I18N.convertText ->
-- getText(key, customEnv) (I18N.lua:401-418, :175-191), so a key a language lacks shows
-- "Missing '<key>' in l10n<suffix>.xml" inside the production's name. Row 114 found
-- fd_depot_send_failed and the 24 sf_*_title production params in English only; the same
-- measurement at the same head found 14 more (6 fillType_* titles, 4 stationName_*, 4
-- info-board actions), all added by hand in this PR.
--
-- A TEXT BAR, READ FROM THE REAL FILES. The key list is not written here: it is every
-- "$l10n_<key>" the mod's XML uses, every posText/negText action key, and every literal key
-- passed to tr() in the two dialogs, restricted to keys the mod's own English file ships (a
-- key it does not ship is the engine's, e.g. fillType_water). The shared Esc door page's XML
-- (xml/gui/RfPdaMenuPage.xml) and the Esc guest (src/gui/FdRfPdaGuest.lua) are left out: the
-- door is row 79's and the guest's fd_rf_pda keys are row 83's.
--
--   K0 the scan found the keys (a guard against a vacuous pass)
--   K  each of the 25 non-English files carries every such key
--   N  the row's named keys: fd_depot_send_failed and the 24 sf_*_title keys in all 25
--   S  no added value is an [EN] stamp

local SOURCES = { "xml/depotPlaceable.xml", "xml/fillTypes.xml", "xml/gui/DepotSettingsDialog.xml",
    "src/ui/DepotDialog.lua", "src/ui/DepotSettingsDialog.lua" }
local LANGS = { "br", "ct", "cz", "da", "de", "ea", "es", "fc", "fi", "fr", "hu", "id", "it", "jp", "kr",
    "nl", "no", "pl", "pt", "ro", "ru", "sv", "tr", "uk", "vi" }

local function texts(lang)
    local out = {}
    local src = _SOURCE_TEXT["translations/translation_" .. lang .. ".xml"]
    for k, v in src:gmatch('<text name="([^"]+)"%s+text="([^"]*)"') do out[k] = v end
    return out
end
local EN = texts("en")

local KEYS, N = {}, 0
local function add(k) if EN[k] ~= nil and not KEYS[k] then KEYS[k] = true; N = N + 1 end end
for _, path in ipairs(SOURCES) do
    local s = _SOURCE_TEXT[path]
    for k in s:gmatch("%$l10n_([%w_]+)") do add(k) end
    for k in s:gmatch('posText="([%w_]+)"') do add(k) end
    for k in s:gmatch('negText="([%w_]+)"') do add(k) end
    for k in s:gmatch('tr%(%s*"([%w_]+)"') do add(k) end
end
local ORDERED = {}
for k in pairs(KEYS) do ORDERED[#ORDERED + 1] = k end
table.sort(ORDERED)

T.ok("K0 the scan found the depot's own keys (" .. N .. "), among them a production param, a fill type, a station, an action and the dialog's send failure",
    N > 40 and KEYS.sf_an_title and KEYS.fillType_ammonia and KEYS.stationName_fertilizerChemIn
        and KEYS.action_turnOnInformation and KEYS.fd_depot_send_failed or false)

for _, lang in ipairs(LANGS) do
    local have, missing = texts(lang), {}
    for _, k in ipairs(ORDERED) do if have[k] == nil then missing[#missing + 1] = k end end
    T.eq("K " .. lang .. " carries every key the depot's files name", table.concat(missing, " "), "")
end

local NAMED = { "fd_depot_send_failed", "sf_uan32_title", "sf_uan28_title", "sf_anhydrous_title", "sf_starter_title",
    "sf_urea_title", "sf_an_title", "sf_ams_title", "sf_map_title", "sf_dap_title", "sf_potash_title", "sf_polifoska_title",
    "sf_liquid_urea_title", "sf_liquid_ams_title", "sf_liquid_map_title", "sf_liquid_dap_title", "sf_liquid_potash_title",
    "sf_insecticide_title", "sf_fungicide_title", "sf_gypsum_title", "sf_compost_title", "sf_biosolids_title",
    "sf_chicken_manure_title", "sf_pelletized_manure_title", "sf_liquidlime_title" }
local miss, stamps = {}, {}
for _, lang in ipairs(LANGS) do
    local have = texts(lang)
    for _, k in ipairs(NAMED) do
        if have[k] == nil then miss[#miss + 1] = lang .. ":" .. k
        elseif have[k]:find("^%[EN%]") then stamps[#stamps + 1] = lang .. ":" .. k end
    end
    for _, k in ipairs(ORDERED) do
        if have[k] ~= nil and have[k]:find("^%[EN%]") and (k:find("^fillType_") or k:find("^stationName_") or k:find("^action_")) then
            stamps[#stamps + 1] = lang .. ":" .. k
        end
    end
end
T.eq("N1 the row's 25 keys are in all 25 non-English files", table.concat(miss, " "), "")
T.eq("S1 none of the added keys carries an [EN] stamp", table.concat(stamps, " "), "")
