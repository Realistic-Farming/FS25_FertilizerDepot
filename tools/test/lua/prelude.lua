-- prelude.lua - minimal FS25 engine mock + tiny test framework.
-- Loaded first by run-tests.mjs, before any src module and the test file itself.
-- Only stubs what module load + the functions under test actually touch; extend as
-- new tests need more of the engine surface.

-- ── Lua 5.1 <-> fengari (5.3) shims ─────────────────────────
unpack = unpack or table.unpack

-- ── FS25 engine globals (stubs) ────────────────────────────
-- Class(members, baseClass): the engine's OO helper, modelled on shared/class.lua:1-40.
-- Returns the instance metatable (__index = members, and __metatable = members as
-- class.lua:14 sets it, so getmetatable(instance) is the class and the metatable cannot
-- be replaced), chains members to baseClass (:17-21), and gives members the class(),
-- superClass() and isa() accessors the dialogs call (:22-40;
-- DepotDialog:superClass().onGuiSetupFinished(self) and its siblings). The one-argument
-- form `setmetatable({}, Class(Foo))` keeps working as before.
-- ONE GAP, stated: the engine's isa() walks cur:superClass() until nil, because every
-- engine class is a Class() and answers. A harness base written by hand (a plain table
-- with no superClass) would make that walk error, so the walk here stops at such a base
-- instead. The MessageDialog stub below answers superClass() with nil so the walk ends
-- the engine's way.
function Class(members, baseClass)
    members = members or {}
    local mt = { __metatable = members, __index = members }
    if baseClass ~= nil then
        setmetatable(members, { __index = baseClass })
    end
    function members:class() return members end
    function members:superClass() return baseClass end
    function members.isa(_, other)
        local cur = members
        while cur ~= nil do
            if cur == other then return true end
            if type(cur.superClass) ~= "function" then return false end
            cur = cur:superClass()
        end
        return false
    end
    return mt
end

function getWorldTranslation(_node) return 0, 0, 0 end

-- MessageDialog: DepotDialog / DepotSettingsDialog derive from it at load time. The
-- lifecycle methods are no-ops so a dialog's own onGuiSetupFinished and friends can run.
MessageDialog = MessageDialog or {
    new = function(_target, mt) return setmetatable({}, mt) end,
    superClass = function() return nil end,
    onCreate = function() end,
    onGuiSetupFinished = function() end,
    onOpen = function() end,
    onClose = function() end,
}

g_currentMission = {
    time = 1000,
    isMasterUser = true,
    getIsServer = function(_self) return true end,
}
g_server = nil
g_client = nil
g_localPlayer = { farmId = 1 }
-- The engine's own language suffix global: main.lua:33 sets it to "_en" and main.lua:1187
-- reassigns it per client language. getText's missing sentence interpolates it (I18N.lua:186),
-- so a harness that hardcodes the suffix renders a sentence no client ever produces.
g_languageSuffix = "_en"

-- i18n, modelled on the engine rather than on a convenient shim (MAINTENANCE row 63, the
-- analogue of SoilFertilizer's #972). I18N.lua:175 getText returns texts[name] and, when the
-- key is absent, the sentence "Missing '<key>' in l10n<suffix>.xml" with g_languageSuffix
-- interpolated at :186: never nil, never "" and never the "$l10n_" XML attribute prefix.
-- I18N.lua:194 hasText answers whether the key exists at all, false for a nil name, a real
-- boolean otherwise. The harness loads no locale file, so by default NO key exists: a gate
-- written the engine's way takes its English fallback here, which is the honest result. A
-- test that needs a translated string registers it with g_i18n:setText(key, text).
-- The block keeps SoilFertilizer's indentation so mutate_prelude_i18n.py applies unchanged.
g_i18n = {
  texts = {},
  setText = function(self, key, value) self.texts[key] = value end,
  hasText = function(self, key)
    if key == nil then return false end
    return self.texts[key] ~= nil
  end,
  getText = function(self, key)
    local ret = self.texts[key]
    if ret == nil then
      return string.format("Missing '%s' in l10n%s.xml", tostring(key), tostring(g_languageSuffix))
    end
    return ret
  end,
}
g_messageCenter = { subscribe = function() end, unsubscribe = function() end, publish = function() end }
Logging = { info = function() end, warning = function() end, error = function() end }

-- ── Mock network stream ────────────────────────────────────
-- A typed FIFO standing in for an FS25 streamId. Every streamWriteX pushes a
-- {tag,value}; the paired streamReadX pops it and checks the tag, so a write/read
-- order or width mismatch surfaces as a counted typeError/underflow.
function _fdMockStream()
    return { q = {}, r = 1, typeErrors = 0, underflows = 0 }
end

local function _push(s, tag, v) s.q[#s.q + 1] = { t = tag, v = v } end
local function _pull(s, tag)
    local e = s.q[s.r]
    if e == nil then s.underflows = s.underflows + 1; return nil end
    s.r = s.r + 1
    if e.t ~= tag then s.typeErrors = s.typeErrors + 1 end
    return e.v
end

function streamWriteInt32(s, v)    _push(s, "i32", v) end
function streamReadInt32(s)         return _pull(s, "i32") end
function streamWriteFloat32(s, v)   _push(s, "f32", v) end
function streamReadFloat32(s)       return _pull(s, "f32") end
function streamWriteUInt8(s, v)     _push(s, "u8", v) end
function streamReadUInt8(s)         return _pull(s, "u8") end
function streamWriteString(s, v)    _push(s, "str", v) end
function streamReadString(s)        return _pull(s, "str") end
function streamWriteBool(s, v)      _push(s, "bool", v and true or false) end
function streamReadBool(s)          return _pull(s, "bool") end

-- ── tiny test framework ────────────────────────────────────
-- Results are emitted as ##TEST_ lines that run-tests.mjs parses out of stdout, so
-- ordinary log noise (DepotLogger prints) is ignored.
T = { _pass = 0, _fail = 0 }

local function _pass(name)
    T._pass = T._pass + 1
    print("##TEST_PASS " .. name)
end
local function _fail(name, msg)
    T._fail = T._fail + 1
    print("##TEST_FAIL " .. name .. " :: " .. tostring(msg))
end

function T.ok(name, cond, msg)
    if cond then _pass(name) else _fail(name, msg or "expected truthy, got " .. tostring(cond)) end
end

function T.eq(name, got, want)
    if got == want then _pass(name)
    else _fail(name, "got " .. tostring(got) .. " want " .. tostring(want)) end
end

function T.summary()
    print("##TEST_SUMMARY " .. T._pass .. " " .. T._fail)
end
