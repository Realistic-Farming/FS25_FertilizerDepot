-- prelude.lua - minimal FS25 engine mock + tiny test framework.
-- Loaded first by run-tests.mjs, before any src module and the test file itself.
-- Only stubs what module load + the functions under test actually touch; extend as
-- new tests need more of the engine surface.

-- ── Lua 5.1 <-> fengari (5.3) shims ─────────────────────────
unpack = unpack or table.unpack

-- ── FS25 engine globals (stubs) ────────────────────────────
-- Class(base): FS25's OO helper. Returns a metatable whose __index chains to base,
-- enough for `setmetatable({}, Class(Foo))` and method dispatch in tests.
function Class(base)
    local mt = {}
    mt.__index = base or mt
    return mt
end

function getWorldTranslation(_node) return 0, 0, 0 end

-- MessageDialog: DepotDialog / DepotSettingsDialog derive from it at load time.
MessageDialog = MessageDialog or {
    new = function(_target, mt) return setmetatable({}, mt) end,
}

g_currentMission = {
    time = 1000,
    isMasterUser = true,
    getIsServer = function(_self) return true end,
}
g_server = nil
g_client = nil
g_localPlayer = { farmId = 1 }
-- Empty text makes the modules' local tr() fall through to its English fallback,
-- so tests can assert on readable status strings.
g_i18n = { getText = function(_self, _key) return "" end }
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
