--!text: src/ui/DepotDialog.lua, src/ui/DepotSettingsDialog.lua, src/DepotManager.lua, src/gui/FdRfPdaGuest.lua
--
-- l10n_gate_identity_test.lua - the four tr() helpers are ONE text (MAINTENANCE row 63,
-- Bob's finding on #77).
--
-- l10n_gate_sites_test.lua drives two of the four helpers through production's own
-- methods; DepotManager's renders an input-binding prompt and FdRfPdaGuest's paints a GUI
-- tree, so no bar drives them. Their only guarantee was "identical text", which nothing
-- checked. This bar checks it: the runner's --!text directive exposes each file's source
-- as _SOURCE_TEXT[path] without executing it (this Lua has no io library), and the body
-- of each `local function tr(key, fallback)` must equal the canonical gate and each
-- other. A helper that drifts, in any of the four, fails a named row here, which is what
-- the battery's M1 to M3 mutations rely on.

local FILES = {
    "src/ui/DepotDialog.lua",
    "src/ui/DepotSettingsDialog.lua",
    "src/DepotManager.lua",
    "src/gui/FdRfPdaGuest.lua",
}

-- The canonical gate, as the four helpers write it (the #973 shape).
local CANON = table.concat({
    "    local i18n = g_i18n",
    '    if i18n == nil or type(i18n.hasText) ~= "function" or type(i18n.getText) ~= "function" then',
    "        return fallback or key",
    "    end",
    "    local okHas, has = pcall(i18n.hasText, i18n, key)",
    "    if not okHas or has ~= true then return fallback or key end",
    "    local ok, text = pcall(i18n.getText, i18n, key)",
    '    if not ok or type(text) ~= "string" or text == "" then return fallback or key end',
    "    return text",
}, "\n")

local function body(path)
    local src = type(_SOURCE_TEXT) == "table" and _SOURCE_TEXT[path] or nil
    if type(src) ~= "string" then return "<no source text for " .. path .. ">" end
    src = src:gsub("\r\n", "\n")
    local count = select(2, src:gsub("\nlocal function tr%(key, fallback%)\n", ""))
    if count ~= 1 then return "<" .. tostring(count) .. " tr helpers in " .. path .. ">" end
    local b = src:match("\nlocal function tr%(key, fallback%)\n(.-)\nend\n")
    return b or "<tr body not found in " .. path .. ">"
end

T.ok("I0 the runner exposed all four sources (the --!text directive works)",
     type(_SOURCE_TEXT) == "table" and #FILES == 4
     and type(_SOURCE_TEXT[FILES[1]]) == "string" and type(_SOURCE_TEXT[FILES[4]]) == "string")
for i, path in ipairs(FILES) do
    T.eq("I" .. i .. " " .. path .. " carries exactly the canonical gate", body(path), CANON)
end
T.ok("I5 the canonical gate asks hasText before getText (the rule, not a coincidence of copies)",
     CANON:find("pcall%(i18n%.hasText") < CANON:find("pcall%(i18n%.getText"))
