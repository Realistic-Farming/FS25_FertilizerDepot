-- prelude_i18n_contract_test.lua - the shared harness i18n must model the engine.
--
-- Ported from SoilFertilizer (PR #972) for MAINTENANCE row 63. This bar exists because
-- a harness that lies about i18n makes every l10n gate in the mod untestable, and makes
-- the WRONG file look guilty when a test goes red. This prelude used to define g_i18n as
-- { getText = function(_self, _key) return "" end }: no hasText at all, and a getText
-- returning a shape the engine never returns. A gate written the engine's way refuses an
-- i18n object that cannot answer hasText, so under the old prelude every correctly
-- repaired site silently took its English fallback, one test file stopped loading on a
-- nil-call, and nine assertions went red for a reason that had nothing to do with their
-- subject (row 63, measured by Bob).
--
-- The engine, read from D:\FS25_Decoded\dataS\scripts_decompiled:
--   I18N.lua:175 getText  - returns texts[name]; when the key is absent returns the
--                           literal "Missing '<name>' in l10n<suffix>.xml". Never
--                           nil, never "", never the "$l10n_" attribute prefix.
--   I18N.lua:194 hasText  - false when name is nil, otherwise texts[name] ~= nil,
--                           returned as a real boolean.
--
-- Locked here:
--   NO LOCALE IS LOADED     - the harness reads no l10n.xml, so by default no key
--                             exists and every gate takes its English fallback.
--                             That is the honest result, not a workaround.
--   THE MISSING SENTENCE    - an absent key comes back as the engine's sentence,
--                             which is exactly the string the old $l10n_ guards
--                             could not see and the defect class is made of.
--   A TEST CAN REGISTER     - setText makes a key exist, so a bar that needs a
--                             translated string can have one without hand-building
--                             an i18n object.
--   THE REPAIRED GATE WORKS - the canonical hasText gate resolves a registered key
--                             and falls back on an unregistered one.
--
-- Every probe below goes through call(), so a prelude missing a method reports
-- "<absent>" and fails its own assertion instead of taking the file down with a
-- nil-call. A kill that arrives as a load error names nothing; this one names a row.

local KEY     = "fd_prelude_contract_key"
local ABSENT  = "fd_prelude_contract_absent"
local ENGLISH = "English fallback"

local function call(method, ...)
    if type(g_i18n) ~= "table" then return "<no g_i18n>" end
    if type(g_i18n[method]) ~= "function" then return "<absent>" end
    local ok, v = pcall(g_i18n[method], g_i18n, ...)
    if not ok then return "<error>" end
    return v
end

-- ── shape ────────────────────────────────────────────────────────────────────
T.ok("prelude i18n: g_i18n exists", type(g_i18n) == "table")
T.eq("prelude i18n: getText is a function", type(g_i18n.getText), "function")
T.eq("prelude i18n: hasText is a function", type(g_i18n.hasText), "function")
T.eq("prelude i18n: setText is a function", type(g_i18n.setText), "function")
T.eq("prelude i18n: it starts with no keys at all", next(g_i18n.texts or {}), nil)

-- ── hasText on an absent key ─────────────────────────────────────────────────
T.eq("prelude i18n: an unregistered key does not exist", call("hasText", ABSENT), false)
T.eq("prelude i18n: a nil key does not exist (I18N.lua:195)", call("hasText", nil), false)
T.eq("prelude i18n: hasText answers with a real boolean, not a truthy value",
     type(call("hasText", ABSENT)), "boolean")

-- ── getText on an absent key: the engine's sentence, and none of the fictions ──
local missing = call("getText", ABSENT)
T.eq("prelude i18n: an absent key returns the engine's missing sentence",
     missing, "Missing '" .. ABSENT .. "' in l10n_en.xml")
T.eq("prelude i18n: it is a string", type(missing), "string")
T.ok("prelude i18n: it is never empty (this prelude's old fiction)", missing ~= "")
T.ok("prelude i18n: it is never the key itself (the other common fiction)", missing ~= ABSENT)
T.ok("prelude i18n: it is never the $l10n_ attribute prefix (the old guards' fiction)",
     missing ~= ("$l10n_" .. ABSENT))

-- The suffix is interpolated, not spelled into the harness. I18N.lua:186 formats
-- with g_languageSuffix, which main.lua:33 defaults to "_en" and main.lua:1187
-- reassigns per client language. A harness that hardcodes one suffix renders a
-- sentence no non-English client produces, which is the same class of fiction this
-- file exists to remove.
T.eq("prelude i18n: the default suffix is the engine's own (main.lua:33)", g_languageSuffix, "_en")
do
    local saved = g_languageSuffix
    g_languageSuffix = "_de"
    T.eq("prelude i18n: the missing sentence follows the client's language suffix",
         call("getText", ABSENT), "Missing '" .. ABSENT .. "' in l10n_de.xml")
    g_languageSuffix = saved
    T.eq("prelude i18n: and it follows it back", call("getText", ABSENT), missing)
end

-- ── setText registers a key ──────────────────────────────────────────────────
call("setText", KEY, "Eine echte Uebersetzung")
T.eq("prelude i18n: a registered key exists", call("hasText", KEY), true)
T.eq("prelude i18n: and getText hands back exactly what was registered",
     call("getText", KEY), "Eine echte Uebersetzung")
T.eq("prelude i18n: registering one key does not make a sibling exist",
     call("hasText", ABSENT), false)

-- ── the canonical repaired gate, as the four tr() helpers write it ────────────
-- Copied rather than loaded: the subject here is the harness i18n, not a dialog.
-- The real sites are driven by l10n_gate_sites_test.lua.
local function translate(key, fallback)
    local i18n = g_i18n
    if i18n == nil or type(i18n.hasText) ~= "function" or type(i18n.getText) ~= "function" then
        return fallback
    end
    local okHas, has = pcall(i18n.hasText, i18n, key)
    if not okHas or has ~= true then return fallback end
    local ok, text = pcall(i18n.getText, i18n, key)
    if not ok or type(text) ~= "string" or text == "" then return fallback end
    return text
end

T.eq("prelude i18n: the repaired gate resolves a registered key",
     translate(KEY, ENGLISH), "Eine echte Uebersetzung")
T.eq("prelude i18n: the repaired gate falls back on an unregistered key",
     translate(ABSENT, ENGLISH), ENGLISH)
T.ok("prelude i18n: the fallback is returned INSTEAD of the missing sentence, which is the whole point",
     translate(ABSENT, ENGLISH) ~= missing)

-- ── the shapes this repair removes must still be refused ─────────────────────
do
    local saved = g_i18n
    g_i18n = { getText = function(_self, _key) return "" end }   -- this prelude's old shape
    T.eq("prelude i18n: an i18n that cannot answer hasText is still refused (empty-string fiction)",
         translate(KEY, ENGLISH), ENGLISH)
    g_i18n = { getText = function(_self, key) return key end }   -- the key-returning fiction
    T.eq("prelude i18n: an i18n that cannot answer hasText is still refused (key fiction)",
         translate(KEY, ENGLISH), ENGLISH)
    g_i18n = nil
    T.eq("prelude i18n: a nil i18n is still refused", translate(KEY, ENGLISH), ENGLISH)
    g_i18n = saved
end

T.eq("prelude i18n: the shared object survived the swap", call("hasText", KEY), true)
