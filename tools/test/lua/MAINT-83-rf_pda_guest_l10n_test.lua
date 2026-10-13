--!text: src/gui/FdRfPdaGuest.lua, translations/translation_br.xml, translations/translation_ct.xml, translations/translation_cz.xml, translations/translation_da.xml, translations/translation_de.xml, translations/translation_ea.xml, translations/translation_en.xml, translations/translation_es.xml, translations/translation_fc.xml, translations/translation_fi.xml, translations/translation_fr.xml, translations/translation_hu.xml, translations/translation_id.xml, translations/translation_it.xml, translations/translation_jp.xml, translations/translation_kr.xml, translations/translation_nl.xml, translations/translation_no.xml, translations/translation_pl.xml, translations/translation_pt.xml, translations/translation_ro.xml, translations/translation_ru.xml, translations/translation_sv.xml, translations/translation_tr.xml, translations/translation_uk.xml, translations/translation_vi.xml
-- MAINT-83-rf_pda_guest_l10n_test.lua
--
-- MAINTENANCE row 83: the RF Esc door guest page (src/gui/FdRfPdaGuest.lua) draws every
-- text through its own tr(key, fallback), which asks the mod's i18n (g_i18n inside a mod's
-- environment is the mod's own, mods.lua:453) and falls back to the English literal when
-- the key is absent. None of its 22 fd_rf_pda_* keys was in any translation file, so the
-- page read English in every language. They are now in all 26, the 25 non-English ones by
-- hand.
--
-- A TEXT BAR, READ FROM THE REAL FILES, and the lookup EXECUTED:
--   R1  the reader set: every "fd_rf_pda_*" string in the guest's source (20 passed to tr()
--       as literals, 2 chosen through a variable, :663) is exactly the en file's set
--   E1  each en value is the code's own fallback text, byte for byte
--   K   each of the 25 non-English files carries all 22
--   T   none is empty, carries an em dash, or is the English text (ALLOW_SAME names the two
--       where the language's word is the English one)
--   F   each value's %d/%s sequence equals English's, in order (string.format has no
--       positional arguments)
--   C   in ct, jp, kr, ru and uk every value carries a letter of that script
--   X1  the guest's OWN tr, cut from the real source, runs against each real file's texts
--       (an i18n whose hasText is the file's key set) and returns the file's value, never
--       the fallback, for every key; X0 is the same helper against a file without the keys,
--       returning the fallback, so X1 can fail the way the page did

local LANGS = { "br", "ct", "cz", "da", "de", "ea", "es", "fc", "fi", "fr", "hu", "id", "it", "jp", "kr",
    "nl", "no", "pl", "pt", "ro", "ru", "sv", "tr", "uk", "vi" }
-- The French word for a stock is "Stock".
local ALLOW_SAME = { ["fr:fd_rf_pda_col_stock"] = true, ["fc:fd_rf_pda_col_stock"] = true }

local function unxml(v)
    return (v:gsub("&quot;", '"'):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"))
end
local function texts(lang)
    local out = {}
    local src = _SOURCE_TEXT["translations/translation_" .. lang .. ".xml"]
    for k, v in src:gmatch('<text name="([^"]+)"%s+text="([^"]*)"') do out[k] = unxml(v) end
    return out
end
local EN = texts("en")
local GUEST = _SOURCE_TEXT["src/gui/FdRfPdaGuest.lua"]:gsub("\r\n", "\n")

local KEYS, INEN = {}, {}
for k in pairs(EN) do if k:find("^fd_rf_pda_") then KEYS[#KEYS + 1] = k; INEN[k] = true end end
table.sort(KEYS)

-- R1: the reader set.
local read, extra, unread = {}, {}, {}
for k in GUEST:gmatch('"(fd_rf_pda_[%w_]+)"') do read[k] = true end
for k in pairs(read) do if not INEN[k] then extra[#extra + 1] = k end end
for _, k in ipairs(KEYS) do if not read[k] then unread[#unread + 1] = k end end
table.sort(extra); table.sort(unread)
T.eq("R1 the guest reads exactly the en file's 22 fd_rf_pda keys",
    #KEYS .. "/" .. table.concat(extra, " ") .. "/" .. table.concat(unread, " "), "22//")

-- E1: the en values are the code's fallbacks.
local wrong = {}
for _, k in ipairs(KEYS) do
    local lit = GUEST:match('tr%("' .. k .. '",%s*"([^"]*)"')
    if lit ~= nil then
        if lit ~= EN[k] then wrong[#wrong + 1] = k end
    elseif not GUEST:find('"' .. EN[k] .. '"', 1, true) then
        wrong[#wrong + 1] = k
    end
end
T.eq("E1 each en value is the guest's own fallback text", table.concat(wrong, " "), "")

-- K, T, F, C.
local function ph(s)
    local out = {}
    for p in s:gmatch("%%[%-0-9%.]*%a") do out[#out + 1] = p end
    return table.concat(out, " ")
end
local function codepoints(s)
    local out, i = {}, 1
    while i <= #s do
        local c = s:byte(i)
        local n, cp = 1, c
        if c >= 0xF0 then n, cp = 4, c - 0xF0 elseif c >= 0xE0 then n, cp = 3, c - 0xE0 elseif c >= 0xC0 then n, cp = 2, c - 0xC0 end
        for j = 1, n - 1 do cp = cp * 64 + ((s:byte(i + j) or 0x80) - 0x80) end
        out[#out + 1] = cp
        i = i + n
    end
    return out
end
local SCRIPT = {
    ct = function(cp) return cp >= 0x4E00 and cp <= 0x9FFF end,
    jp = function(cp) return (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x4E00 and cp <= 0x9FFF) end,
    kr = function(cp) return cp >= 0xAC00 and cp <= 0xD7A3 end,
    ru = function(cp) return cp >= 0x0400 and cp <= 0x04FF end,
    uk = function(cp) return cp >= 0x0400 and cp <= 0x04FF end,
}
local FILES = {}
for _, lang in ipairs(LANGS) do
    local have = texts(lang)
    FILES[lang] = have
    local missing, bad, fmt, script = {}, {}, {}, {}
    for _, k in ipairs(KEYS) do
        local v = have[k]
        if v == nil then
            missing[#missing + 1] = k
        else
            if v:match("^%s*$") or v:find("\226\128\148", 1, true) or (v == EN[k] and not ALLOW_SAME[lang .. ":" .. k]) then
                bad[#bad + 1] = k
            end
            if ph(v) ~= ph(EN[k]) then fmt[#fmt + 1] = k end
            if SCRIPT[lang] ~= nil then
                local any = false
                for _, cp in ipairs(codepoints(v)) do if SCRIPT[lang](cp) then any = true break end end
                if not any then script[#script + 1] = k end
            end
        end
    end
    T.eq("K " .. lang .. " carries all 22 keys", table.concat(missing, " "), "")
    T.eq("T " .. lang .. " has no empty, em-dashed or English value", table.concat(bad, " "), "")
    T.eq("F " .. lang .. " keeps English's placeholders in order", table.concat(fmt, " "), "")
    if SCRIPT[lang] ~= nil then
        T.eq("C " .. lang .. " writes every value in its own script", table.concat(script, " "), "")
    end
end

-- X0, X1: the guest's own tr, executed.
local s = GUEST:find("local function tr(key, fallback)", 1, true)
local e = s and GUEST:find("\nend\n", s, true)
T.ok("X1 [reached] the guest's local tr was cut from the real source", s ~= nil and e ~= nil)
if s ~= nil and e ~= nil then
    local body = GUEST:sub(s, e + 4) .. "return tr\n"
    local function trFor(file)
        local env = { pcall = pcall, type = type }
        env.g_i18n = {
            hasText = function(_, key) return file[key] ~= nil end,
            getText = function(_, key) return file[key] or ("Missing '" .. tostring(key) .. "' in l10n.xml") end,
        }
        local chunk = assert(load(body, "=FdRfPdaGuest.tr", "t", env))
        return chunk()
    end
    local fell = {}
    for _, lang in ipairs(LANGS) do
        local tr = trFor(FILES[lang])
        for _, k in ipairs(KEYS) do
            local got = tr(k, "<fallback>")
            if got ~= FILES[lang][k] then fell[#fell + 1] = lang .. ":" .. k end
        end
    end
    T.eq("X1 the guest's own tr returns each file's text for all 22 keys in all 25 languages, never the fallback", table.concat(fell, " "), "")
    local bare = trFor({ fd_shop_name = "x" })
    T.eq("X0 against a file without the keys the same tr returns the fallback (the page before this row)",
        bare("fd_rf_pda_module_title", "<fallback>"), "<fallback>")
end
