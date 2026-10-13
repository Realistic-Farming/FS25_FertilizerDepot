--!load: src/config/Constants.lua, src/config/DepotSettings.lua, src/DepotLogger.lua, src/integrations/FDNetworkSyncBridge.lua, src/ui/DepotDialog.lua
--
-- RSF-F230, remaining scope: per-action validation before the owner is called,
-- the acting farm bound to something the server trusts (never args[5]), the
-- owner's tuple returned at its own width, dirty only on success, the host paths
-- of sendAction relaying the tuple, and the three dialog sites saying only what
-- this machine actually knows. NetworkSync is mirrored (NetworkSync.lua:310-349),
-- not loaded; handleSettings is asserted untouched.

DepotLogger.info    = function() end
DepotLogger.warning = function() end
DepotLogger.error   = function() end
DepotLogger.debug   = function() end

-- ── owner stand-in: records what it was asked, answers what the test says ──
local calls, answer = {}, {}
local depotSystem = {}
function depotSystem:buyFillType(depotId, name, idx, liters, farmId)
    calls[#calls + 1] = { op = "buy", depotId, name, idx, liters, farmId }
    if answer.buy then return unpack(answer.buy) end
    return true, "fd_depot_buy_success", liters
end
function depotSystem:sellFillType(depotId, name, idx, liters, farmId)
    calls[#calls + 1] = { op = "sell", depotId, name, idx, liters, farmId }
    if answer.sell then return unpack(answer.sell) end
    return true, "fd_depot_sell_success", liters, liters * 0.5
end
function depotSystem:orderProduct(depotId, name, idx, quantity, sx, sz, farmId)
    calls[#calls + 1] = { op = "order", depotId, name, idx, quantity, farmId }
    if answer.order then return unpack(answer.order) end
    return true, "fd_products_ordered"
end
function depotSystem:findCompatibleVehicle() return { typeName = "trailer" }, 1 end
function depotSystem:getStorageLevel() return 100000 end

local dirty = 0
local function reset()
    calls, answer, dirty = {}, {}, 0
    g_DepotManager = {
        depotSystem = depotSystem, depots = { [7] = { rootNode = 1 } },
        depotProductSpawnNodes = {}, depotUnloadNodes = {},
        settings = DepotSettings.new(),
    }
end
FDNetworkSyncBridge.markDirty = function() dirty = dirty + 1 end

-- ── NetworkSync mirror (NetworkSync.lua:310-333 _applyAction, :336-349 requestAction) ──
local users = {}           -- connection -> { id = userId }
local function fakeNS()
    local ns = { actions = {}, handlerErr = nil, lastReturns = nil }
    function ns:registerAction(id, def) self.actions[id] = def end
    function ns:registerModule() end
    function ns:markDirty() end
    function ns:syncNow() end
    function ns:_applyAction(id, args, connection)
        local a = self.actions[id]
        if a == nil then self.handlerErr = "unregistered " .. tostring(id); return end
        local userId = nil
        if connection ~= nil then
            local user = users[connection]
            userId = user ~= nil and user.id or nil
        end
        local r = { pcall(a.onAction, userId, args) }
        if not r[1] then self.handlerErr = r[2] end
        self.lastReturns = { unpack(r, 2) }   -- discarded by the real thing; kept to prove it
    end
    function ns:requestAction(id, args)
        if g_currentMission:getIsServer() then self:_applyAction(id, args, nil); return true end
        self:_applyAction(id, args, "conn")   -- the event's run(), on the server
        return true
    end
    return ns
end

local function setup(mode)
    reset()
    g_currentMission = g_currentMission or {}
    g_currentMission.getIsServer = function() return mode ~= "client" end
    g_currentMission.missionDynamicInfo = { isMultiplayer = (mode ~= "sp") }
    g_currentMission.networkSync = nil
    g_networkSync = nil
    g_server = {}
    if mode == "absent-host" then
        FDNetworkSyncBridge.active, FDNetworkSyncBridge._ns = false, nil
        return nil
    end
    g_networkSync = fakeNS()
    FDNetworkSyncBridge.register()
    return g_networkSync
end

local function farmObj(id, spectator)
    return { getId = function() return id end, isSpectator = spectator or false }
end
local farmsByUser = {}
g_farmManager = { getFarmByUserId = function(_self, userId) return farmsByUser[userId] end }

local H = nil
local function handlers()
    -- reach the registered handlers through the fake NS
    local ns = setup("host")
    H = { buy = ns.actions[FDNetworkSyncBridge.ACTION_PURCHASE].onAction,
          sell = ns.actions[FDNetworkSyncBridge.ACTION_SELL].onAction,
          order = ns.actions[FDNetworkSyncBridge.ACTION_PRODUCT_ORDER].onAction,
          settings = ns.actions[FDNetworkSyncBridge.ACTION_SETTINGS].onAction }
    return H
end
handlers()

-- ── 1. Validation before the owner ──────────────────────────────────────────
do
    local bad = {
        { name = "non-table", args = "nope" },
        { name = "four elements", args = { 7, "X", 1, 10 } },
        { name = "six elements", args = { 7, "X", 1, 10, 3, 9 } },
        { name = "gap in slot 3", args = { 7, "X", nil, 10, 3 } },
        { name = "depotId string", args = { "7", "X", 1, 10, 3 } },
        { name = "name number", args = { 7, 9, 1, 10, 3 } },
        { name = "index string", args = { 7, "X", "1", 10, 3 } },
        { name = "qty zero", args = { 7, "X", 1, 0, 3 } },
        { name = "qty negative", args = { 7, "X", 1, -5, 3 } },
        { name = "qty NaN", args = { 7, "X", 1, 0/0, 3 } },
        { name = "qty inf", args = { 7, "X", 1, math.huge, 3 } },
        { name = "qty string", args = { 7, "X", 1, "10", 3 } },
    }
    for _, c in ipairs(bad) do
        for _, op in ipairs({ "buy", "sell", "order" }) do
            reset()
            local r = { H[op](nil, c.args, 3) }
            T.eq("validate " .. op .. " (" .. c.name .. "): refused", r[1], false)
            T.eq("validate " .. op .. " (" .. c.name .. "): owner key", r[2], "fd_error_server")
            T.eq("validate " .. op .. " (" .. c.name .. "): owner never called", #calls, 0)
            T.eq("validate " .. op .. " (" .. c.name .. "): not dirty", dirty, 0)
        end
    end
    -- widths on refusal
    reset()
    T.eq("validate: buy refusal width 3", select("#", H.buy(nil, "x", 3)), 3)
    T.eq("validate: order refusal width 2", select("#", H.order(nil, "x", 3)), 2)
    T.eq("validate: sell refusal width 4", select("#", H.sell(nil, "x", 3)), 4)
    -- an order of one unit and a buy of one litre both reach the owner
    reset()
    H.order(nil, { 7, "X", 1, 1, 99 }, 3)
    H.buy(nil, { 7, "X", 1, 1, 99 }, 3)
    T.eq("validate: order of 1 and buy of 1 reach the owner", #calls, 2)
end

-- ── 2. Actor binding ────────────────────────────────────────────────────────
do
    -- host: the trusted third argument wins over a different args[5]
    reset()
    H.buy(nil, { 7, "X", 1, 10, 42 }, 3)
    T.eq("actor host: charged the local farm, not args[5]", calls[1][5], 3)
    reset()
    H.sell(nil, { 7, "X", 1, 10, 0 }, 3)
    T.eq("actor host: manager sell path with farmId 0 in slot 5 still binds local", calls[1][5], 3)

    -- host: nil or spectator local farm refused
    for _, v in ipairs({ { nil, "nil" }, { 0, "spectator 0" }, { "3", "string" } }) do
        reset()
        local ok, key = H.buy(nil, { 7, "X", 1, 10, 3 }, v[1])
        T.eq("actor host (" .. v[2] .. "): refused", ok, false)
        T.eq("actor host (" .. v[2] .. "): farm key", key, "fd_error_farm")
        T.eq("actor host (" .. v[2] .. "): nobody charged", #calls, 0)
    end

    -- remote: the server's farm for the user, never args[5]
    farmsByUser = { [501] = farmObj(5), [502] = farmObj(0), [503] = farmObj(6, true) }
    reset()
    H.buy(501, { 7, "X", 1, 10, 42 })
    T.eq("actor remote: charged the user's farm", calls[1][5], 5)
    reset()
    local ok, key = H.buy(502, { 7, "X", 1, 10, 42 })
    T.eq("actor remote: spectator farm id refused", ok, false)
    T.eq("actor remote: spectator key", key, "fd_error_farm")
    reset()
    ok = H.sell(503, { 7, "X", 1, 10, 42 })
    T.eq("actor remote: isSpectator farm object refused", ok, false)
    reset()
    ok = H.order(504, { 7, "X", 1, 1, 42 })
    T.eq("actor remote: unmatched user (nil farm) refused", ok, false)
    T.eq("actor remote: nobody charged", #calls, 0)
    reset()
    ok, key = H.buy(nil, { 7, "X", 1, 10, 42 })
    T.eq("actor: nil user and no local farm refused", ok, false)
    T.eq("actor: ...with the farm key", key, "fd_error_farm")
    T.eq("actor: ...and no owner call", #calls, 0)
    -- no farm 1 fallback anywhere
    reset()
    H.buy(nil, { 7, "X", 1, 10, 1 })
    T.eq("actor: no farm 1 fallback", #calls, 0)
end

-- ── 3. Owner tuple at its own width, dirty only on success ──────────────────
do
    reset()
    answer.buy = { true, "fd_depot_buy_success", 640 }
    local r = { H.buy(nil, { 7, "X", 1, 1000, 3 }, 3) }
    T.eq("tuple buy: width 3", #r, 3)
    T.eq("tuple buy: actual litres relayed", r[3], 640)
    T.eq("tuple buy: dirty once", dirty, 1)

    reset()
    answer.order = { true, "fd_products_ordered" }
    r = { H.order(nil, { 7, "X", 1, 2, 3 }, 3) }
    T.eq("tuple order: width 2, nothing padded", #r, 2)
    T.eq("tuple order: dirty once", dirty, 1)

    reset()
    answer.sell = { true, "fd_depot_sell_success", 800, 412.5 }
    r = { H.sell(nil, { 7, "X", 1, 800, 3 }, 3) }
    T.eq("tuple sell: width 4", #r, 4)
    T.eq("tuple sell: revenue kept", r[4], 412.5)
    T.eq("tuple sell: dirty once", dirty, 1)

    reset()
    answer.buy = { false, "fd_depot_no_money", 0 }
    r = { H.buy(nil, { 7, "X", 1, 1000, 3 }, 3) }
    T.eq("tuple buy refusal: owner reason", r[2], "fd_depot_no_money")
    T.eq("tuple buy refusal: not dirty", dirty, 0)
    reset()
    answer.sell = { false, "fd_depot_tank_empty", 0, 0 }
    H.sell(nil, { 7, "X", 1, 800, 3 }, 3)
    T.eq("tuple sell refusal: not dirty", dirty, 0)
    reset()
    answer.order = { false, "fd_products_no_stock" }
    H.order(nil, { 7, "X", 1, 2, 3 }, 3)
    T.eq("tuple order refusal: not dirty", dirty, 0)
end

-- ── 4. sendAction relays on the host paths only; settings untouched ──────────
do
    g_localPlayer = { farmId = 3 }
    for _, mode in ipairs({ "host", "absent-host" }) do
        local ns = setup(mode)
        answer.buy = { true, "fd_depot_buy_success", 640 }
        local sent, ok, reason, actual = FDNetworkSyncBridge.sendAction(
            FDNetworkSyncBridge.ACTION_PURCHASE, { 7, "X", 1, 1000, 42 })
        T.eq("send " .. mode .. ": handled", sent, true)
        T.eq("send " .. mode .. ": ok relayed", ok, true)
        T.eq("send " .. mode .. ": reason relayed", reason, "fd_depot_buy_success")
        T.eq("send " .. mode .. ": actual relayed", actual, 640)
        T.eq("send " .. mode .. ": charged local farm not slot 5", calls[1][5], 3)
        if ns then T.eq("send " .. mode .. ": _applyAction not used on the host", ns.lastReturns, nil) end

        reset()
        answer.sell = { true, "fd_depot_sell_success", 800, 400 }
        local r = { FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_SELL, { 7, "X", 1, 800, 42 }) }
        T.eq("send " .. mode .. ": sell width 1+4", #r, 5)
        reset()
        r = { FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PRODUCT_ORDER, { 7, "X", 1, 2, 42 }) }
        T.eq("send " .. mode .. ": order width 1+2", #r, 3)

        -- local farm nil / spectator: handled, refused, nobody charged
        reset()
        g_localPlayer = nil
        r = { FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PURCHASE, { 7, "X", 1, 1000, 3 }) }
        T.eq("send " .. mode .. ": nil player handled", r[1], true)
        T.eq("send " .. mode .. ": nil player refused", r[2], false)
        T.eq("send " .. mode .. ": nil player farm key", r[3], "fd_error_farm")
        T.eq("send " .. mode .. ": nil player not charged", #calls, 0)
        g_localPlayer = { farmId = 0 }
        reset()
        r = { FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PURCHASE, { 7, "X", 1, 1000, 3 }) }
        T.eq("send " .. mode .. ": spectator refused", r[2], false)
        g_localPlayer = { farmId = 3 }

        -- settings still runs on the host paths and returns only `handled`
        -- (handleSettings itself is unchanged; the source diff is the proof).
        reset()
        g_currentMission.userManager = nil
        g_DepotManager.settings.debugLogging = true
        local sr = { FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_SETTINGS, { "debugLogging", "false" }) }
        T.eq("send " .. mode .. ": settings handled", sr[1], true)
        T.eq("send " .. mode .. ": settings relays nothing", #sr, 1)
        T.eq("send " .. mode .. ": settings applied", g_DepotManager.settings.debugLogging, false)
    end

    -- remote client: sent is all it says
    local ns = setup("client")
    users["conn"] = { id = 501 }
    farmsByUser[501] = farmObj(5)
    local r = { FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PURCHASE, { 7, "X", 1, 1000, 42 }) }
    T.eq("send client: sent", r[1], true)
    T.eq("send client: no owner result comes back", #r, 1)
    T.eq("send client: the server charged the user's farm, not slot 5", calls[1][5], 5)
    T.eq("send client: no handler error", ns.handlerErr, nil)
end

-- ── 5. The dialog says what it knows ────────────────────────────────────────
local lastStatus
local function fakeDialog()
    return setmetatable({
        depotId = 7, orderAmount = 1500,
        selectedFillType = { name = "FERTILIZER", fillTypeIndex = 12, displayName = "Fertilizer" },
        selectedProduct  = { name = "FERTILIZER", fillTypeIndex = 12, displayName = "Fertilizer",
                             litresPerUnit = 1000, productLabel = "bag" },
        productQuantity = 2,
        sellList = { { ft = { name = "LIME", fillTypeIndex = 9, displayName = "Lime" }, liters = 800 } },
        statusText = { setText = function(_, t) lastStatus = t end },
    }, { __index = DepotDialog })
end
local function has(s, sub) return type(s) == "string" and s:find(sub, 1, true) ~= nil end
-- A declared test locale, not the old fiction: every key EXISTS and translates to its
-- own name, so hasText answers true (the repaired tr() asks it first) and the rows below
-- keep pinning WHICH key each status reaches for. The old fixture answered hasText false
-- from a getText that returned the key, an object the engine cannot produce: I18N.lua:186
-- returns the Missing sentence exactly when :194 answers false. Under the repaired gate
-- every row here would have read as the English fallback, red for a reason unrelated to
-- its subject (MAINTENANCE row 63 measured nine of them).
g_i18n = {
    hasText = function(_self, key) return key ~= nil end,
    getText = function(_self, key) return key end,
}

do
    g_localPlayer = { farmId = 3 }
    setup("host")
    -- partial buy: actual litres, not the request
    answer.buy = { true, "fd_depot_buy_success", 640 }
    lastStatus = nil; fakeDialog():onConfirmOrder()
    T.ok("dialog host: success shows the owner key", has(lastStatus, "fd_depot_buy_success"))
    T.ok("dialog host: partial buy shows the actual 640, not 1500", has(lastStatus, "640L") and not has(lastStatus, "1500"))
    T.ok("dialog host: never says Filling", not has(lastStatus, "Filling") and not has(lastStatus, "fd_depot_filling"))
    -- refusal: the owner's reason
    answer.buy = { false, "fd_depot_no_money", 0 }
    lastStatus = nil; fakeDialog():onConfirmOrder()
    T.eq("dialog host: refusal shows the owner reason key", lastStatus, "fd_depot_no_money")
    -- sale: litres and revenue, no Filling
    answer.sell = { true, "fd_depot_sell_success", 800, 412 }
    lastStatus = nil; fakeDialog():executeSell(1)
    T.ok("dialog host: sale shows litres and revenue", has(lastStatus, "800L") and has(lastStatus, "$412"))
    T.ok("dialog host: sale never says Filling", not has(lastStatus, "Filling") and not has(lastStatus, "fd_depot_filling"))
    answer.sell = { false, "fd_depot_tank_empty", 0, 0 }
    lastStatus = nil; fakeDialog():executeSell(1)
    T.eq("dialog host: sale refusal shows the owner reason", lastStatus, "fd_depot_tank_empty")
    -- order: the existing ordered message on success, the reason on refusal
    answer.order = { true, "fd_products_ordered" }
    lastStatus = nil; fakeDialog():onProductConfirm()
    T.ok("dialog host: order success uses the ordered message", has(lastStatus, "fd_products_ordered"))
    -- Which SITE produced that key matters and the key alone cannot say: the
    -- formatted line and the fall-through that used to pass the same key are
    -- indistinguishable while getText hands back the key, because string.format on
    -- a template with no specifiers drops every argument. Give the key a real
    -- template for one case and the quantity and label become observable, which
    -- pins the success sentence to the site that renders it. Remove the early
    -- return above and this row fails, instead of the status quietly degrading.
    do
        local savedI18n = g_i18n
        g_i18n = {
            getText = function(_self, key)
                if key == "fd_products_ordered" then return "%d x %s %s ordered" end
                return key
            end,
            -- hasText must agree with getText or this declares an i18n the engine
            -- cannot produce: I18N.lua:194 answers false only when texts[name] is
            -- nil, and :186 then makes getText return the Missing sentence rather
            -- than a translation. Every key exists here, because getText answers
            -- every key: the label key too, so the repaired tr() (which asks
            -- hasText first) renders "fd_products_label_bag" and the row below
            -- keeps pinning which key the label reaches for. This is the ninth
            -- assertion MAINTENANCE row 63 measured: under the old fixture only the
            -- template key existed, and the gate took "Bag(s)" for the label.
            hasText = function(_self, key) return key ~= nil end,
        }
        answer.order = { true, "fd_products_ordered" }
        lastStatus = nil; fakeDialog():onProductConfirm()
        T.eq("dialog host: order success is the FORMATTED line, with quantity and label",
             lastStatus, "2 x Fertilizer fd_products_label_bag ordered")
        g_i18n = savedI18n
    end
    answer.order = { false, "fd_products_no_object" }
    lastStatus = nil; fakeDialog():onProductConfirm()
    T.eq("dialog host: order refusal shows the owner reason", lastStatus, "fd_products_no_object")

    -- client: sent and nothing more
    setup("client")
    users["conn"] = { id = 501 }; farmsByUser[501] = farmObj(5)
    lastStatus = nil; fakeDialog():onConfirmOrder()
    T.eq("dialog client: buy says request sent", lastStatus, "fd_depot_request_sent")
    lastStatus = nil; fakeDialog():executeSell(1)
    T.eq("dialog client: sale says request sent", lastStatus, "fd_depot_request_sent")
    lastStatus = nil; fakeDialog():onProductConfirm()
    T.eq("dialog client: order says request sent, never ordered", lastStatus, "fd_depot_request_sent")

    -- not sent
    FDNetworkSyncBridge.active, FDNetworkSyncBridge._ns = false, nil
    g_server = nil
    lastStatus = nil; fakeDialog():onConfirmOrder()
    T.eq("dialog not sent: send failed key", lastStatus, "fd_depot_send_failed")
    lastStatus = nil; fakeDialog():executeSell(1)
    T.eq("dialog not sent: sale send failed key", lastStatus, "fd_depot_send_failed")
    lastStatus = nil; fakeDialog():onProductConfirm()
    T.eq("dialog not sent: order send failed key", lastStatus, "fd_depot_send_failed")
    g_server = {}
end
