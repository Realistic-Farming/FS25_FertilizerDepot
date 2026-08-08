-- =========================================================
-- FdRfPdaGuest - Esc RF PDA Fertilizer Depot framework (Table shell)
-- Stage-8 densify 2026-08-05 (Samantha DESIGN + George ENGINE ACK).
-- Soft-detect: mission.depotManager (preferred) then temporary g_DepotManager.
-- Read-only stock/price table + delivery title; no commerce writes.
-- =========================================================

FdRfPdaGuest = {}

local MOD_DIR = g_currentModDirectory
local MOD_NAME = g_currentModName
local PANEL_ID = "fertilizerDepot"
local PANEL_ORDER = 90
local MAX_ROWS = 8
local _registered = false

local function tr(key, fallback)
    local modEnv = g_modEnvironments and g_modEnvironments[MOD_NAME]
    local i18n = (modEnv and modEnv.i18n) or g_i18n
    if i18n then
        local ok, text = pcall(function() return i18n:getText(key) end)
        if ok and type(text) == "string" and text ~= "" then
            local lower = text:lower()
            if lower ~= tostring(key):lower()
                and text ~= ("$l10n_" .. key)
                and not lower:find("^missing%s")
                and not lower:find("^missing_")
            then
                return text
            end
        end
    end
    return fallback or key
end

local function getHost()
    if g_currentMission ~= nil and g_currentMission.rfEscModules ~= nil then
        return g_currentMission.rfEscModules
    end
    local env = getfenv(0)
    if env ~= nil and env.g_rfEscModules ~= nil then
        return env.g_rfEscModules
    end
    if RfEscModules ~= nil then
        return RfEscModules.getOrCreate()
    end
    return nil
end

local function getHostPage()
    if g_inGameMenu == nil then return nil end
    return g_inGameMenu.menuRealisticFarming
end

local function findDescendant(root, id)
    if root == nil or id == nil then return nil end
    if root.getDescendantById then
        local el = root:getDescendantById(id)
        if el ~= nil then return el end
    end
    local page = getHostPage()
    if page and page.getDescendantById then
        return page:getDescendantById(id)
    end
    return nil
end

local function setText(el, text)
    if el ~= nil and type(el.setText) == "function" then el:setText(text or "") end
end

local function setVis(el, visible)
    if el ~= nil and type(el.setVisible) == "function" then el:setVisible(visible) end
end

local function formatMoney(amount)
    if amount == nil then return "--" end
    if g_i18n and g_i18n.formatMoney then return g_i18n:formatMoney(amount, 0, true, true) end
    return string.format("%.0f", amount)
end

local function paintSide(container, key, fallback)
    setVis(findDescendant(container, "wcSideInfoShell"), false)
    setVis(findDescendant(container, "mdSideInfoShell"), false)
    local shell = findDescendant(container, "rfSideInfoShell")
    local body = findDescendant(container, "rfSideInfoBody")
    setVis(shell, true)
    setText(body, tr(key, fallback))
end


local function refreshFwAbs(container)
    local page = getHostPage()
    local host = findDescendant(container, "rfHostPlaceholder") or (page and page.rfHostPlaceholder)
    local shell = findDescendant(container, "rfFrameworkGlanceShell")
    local status = findDescendant(container, "rfFwStatusBlock")
    local tableBlock = findDescendant(container, "rfFwTableBlock")
    for _, el in ipairs({ host, shell, status, tableBlock }) do
        if el ~= nil and type(el.updateAbsolutePosition) == "function" then
            el:updateAbsolutePosition()
        end
    end
end

local function clearHostDupes(container)
    setText(findDescendant(container, "rfHostBody"), "")
    setText(findDescendant(container, "rfHostTitle"), "")
    setText(findDescendant(container, "rfHostBlurb"), "")
    setVis(findDescendant(container, "rfHostTitle"), false)
    setVis(findDescendant(container, "rfHostBlurb"), false)
end

local function showTableMode(container)
    setVis(findDescendant(container, "rfFrameworkGlanceShell"), true)
    setVis(findDescendant(container, "rfFwStatusBlock"), false)
    setVis(findDescendant(container, "rfFwTableBlock"), true)
    refreshFwAbs(container)
end

local function labeled(label, value)
    local lbl = tostring(label or ""):gsub(":%s*$", "")
    return string.format("%s: %s", lbl, tostring(value or "--"))
end

local function getMgr()
    if g_currentMission ~= nil and g_currentMission.depotManager ~= nil then
        return g_currentMission.depotManager
    end
    -- Temporary soft-detect (named in DONE): bare g_DepotManager / getfenv
    if g_DepotManager ~= nil then
        return g_DepotManager
    end
    local env = getfenv(0)
    if env ~= nil and env.g_DepotManager ~= nil then
        return env.g_DepotManager
    end
    return nil
end

local function farmId()
    if g_localPlayer ~= nil and g_localPlayer.farmId ~= nil then
        return g_localPlayer.farmId
    end
    if g_currentMission ~= nil and type(g_currentMission.getFarmId) == "function" then
        return g_currentMission:getFarmId()
    end
    return 0
end

local function statusLabel(status)
    local S = DeliverySystem and DeliverySystem.STATUS
    if S ~= nil then
        if status == S.PENDING then return tr("fd_rf_pda_status_pending", "Pending") end
        if status == S.LOADED then return tr("fd_rf_pda_status_loaded", "Loaded") end
        if status == S.NONE then return tr("fd_rf_pda_status_idle", "Idle") end
    end
    if status == 1 then return tr("fd_rf_pda_status_pending", "Pending") end
    if status == 2 then return tr("fd_rf_pda_status_loaded", "Loaded") end
    return tr("fd_rf_pda_status_idle", "Idle")
end

local function isActiveStatus(status)
    local S = DeliverySystem and DeliverySystem.STATUS
    if S ~= nil then
        return status == S.PENDING or status == S.LOADED
    end
    return status == 1 or status == 2
end

local function clearRows(container)
    for i = 1, MAX_ROWS do
        for _, c in ipairs({"A", "B", "C", "D"}) do
            local el = findDescendant(container, "rfFwRow" .. i .. c)
            setVis(el, false)
            setText(el, "")
        end
    end
end

local function paintHeaders(container)
    setText(findDescendant(container, "rfFwColA"), tr("fd_rf_pda_col_fill", "Fill"))
    setText(findDescendant(container, "rfFwColB"), tr("fd_rf_pda_col_stock", "Stock"))
    setText(findDescendant(container, "rfFwColC"), tr("fd_rf_pda_col_buy", "Buy"))
    setText(findDescendant(container, "rfFwColD"), tr("fd_rf_pda_col_sell", "Sell"))
end

--- Esc-side farm filter CONSTRAINT (George): placeable:getOwnerFarmId() == localFarmId.
local function buildFarmDepots(mgr, fid)
    local ids = {}
    if mgr == nil or mgr.depots == nil then return ids end
    for depotId, placeable in pairs(mgr.depots) do
        if placeable ~= nil
            and type(placeable.getOwnerFarmId) == "function"
            and placeable:getOwnerFarmId() == fid
        then
            ids[#ids + 1] = tonumber(depotId) or depotId
        end
    end
    table.sort(ids, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na ~= nil and nb ~= nil then return na < nb end
        return tostring(a) < tostring(b)
    end)
    return ids
end

--- Prefer depot with this farm's active delivery; else first filtered id.
--- Re-focus to active-delivery depot so title + stock stay coherent (George).
local function pickFocusDepot(mgr, farmDepots, fid)
    local ds = mgr and mgr.deliverySystem
    if ds ~= nil and type(ds.getDelivery) == "function" then
        for _, depotId in ipairs(farmDepots) do
            local ok, rec = pcall(function() return ds:getDelivery(depotId) end)
            if ok and rec ~= nil and rec.farmId == fid and isActiveStatus(rec.status) then
                return depotId, rec
            end
        end
    end
    -- HUD parity fallback: farm-scan deliveries (first hit), re-focus if that depot is ours
    if ds ~= nil and ds.deliveries ~= nil then
        for depotId, rec in pairs(ds.deliveries) do
            if rec ~= nil and rec.farmId == fid and isActiveStatus(rec.status) then
                local idNum = tonumber(depotId) or depotId
                for _, ownedId in ipairs(farmDepots) do
                    if ownedId == idNum or tostring(ownedId) == tostring(depotId) then
                        return ownedId, rec
                    end
                end
                -- Active delivery on another farm's placeable: still paint HUD digits in title
                -- via returned rec, but keep stock on first owned depot if any.
                return farmDepots[1], rec
            end
        end
    end
    return farmDepots[1], nil
end

local function deliveryTitleLine(rec)
    local idle = (rec == nil)
        or (DeliverySystem ~= nil and rec.status == DeliverySystem.STATUS.NONE)
        or rec.status == 0
    local statusText = statusLabel(idle and 0 or rec.status)
    local lbl = tr("fd_rf_pda_lbl_status", "Delivery")
    if idle then
        return string.format("%s: %s  ·  %s",
            lbl, statusText, tr("fd_rf_pda_idle_copy", "no active delivery"))
    end
    return string.format("%s: %s  ·  %s",
        lbl, statusText, formatMoney(rec.deliveryCost))
end

local function seasonHint(pricing)
    if pricing == nil then return "" end
    local parts = {}
    local key, mult
    if type(pricing.getSeasonKey) == "function" then
        local ok, k = pcall(function() return pricing:getSeasonKey() end)
        if ok and k ~= nil and tostring(k) ~= "" then
            key = tr(tostring(k), tostring(k))
        end
    end
    if type(pricing.getSeasonMultiplier) == "function" then
        local ok, m = pcall(function() return pricing:getSeasonMultiplier() end)
        if ok and m ~= nil then
            mult = tonumber(m) or m
        end
    end
    if key == nil and mult == nil then return "" end
    if mult ~= nil and (tonumber(mult) == 1.0 or tonumber(mult) == 1) then
        parts[#parts + 1] = labeled(tr("fd_rf_pda_lbl_season", "Season"),
            string.format("%s · 1.0", key or tr("fd_rf_pda_season_off", "off")))
    else
        local val = key or "--"
        if mult ~= nil then
            val = string.format("%s · %.2f", key or "--", tonumber(mult) or 0)
        end
        parts[#parts + 1] = labeled(tr("fd_rf_pda_lbl_season", "Season"), val)
    end
    return parts[1] or ""
end

function FdRfPdaGuest.onShow(container, lightOnly)
    clearHostDupes(container)
    showTableMode(container)
    paintSide(container, "rf_pda_side_info_fertilizer_depot",
        "Depot glance: delivery status/cost, stock vs capacity, buy/sell.\n"
        .. "Esc never buys or sells - open the depot placeable dialog for that.")
    paintHeaders(container)

    local titleEl = findDescendant(container, "rfFwTableTitle")
    local moreEl = findDescendant(container, "rfFwMore")
    local hintEl = findDescendant(container, "rfFwHintTable")
    local emptyEl = findDescendant(container, "rfFwEmptyHint")

    local mgr = getMgr()
    if mgr == nil then
        setVis(titleEl, true)
        setText(titleEl, tr("fd_rf_pda_waiting", "Depot manager not ready"))
        clearRows(container)
        setVis(emptyEl, false)
        setText(emptyEl, "")
        setText(moreEl, "")
        setText(hintEl, "")
        return
    end

    local fid = farmId()
    local farmDepots = buildFarmDepots(mgr, fid)
    local focusId, deliveryRec = pickFocusDepot(mgr, farmDepots, fid)

    -- Title: delivery posture (HUD digit parity via getDelivery / farm-scan)
    setVis(titleEl, true)
    if focusId == nil and deliveryRec == nil then
        setText(titleEl, deliveryTitleLine(nil))
    else
        -- Prefer getDelivery(focus) when focus known and rec not already from scan
        local ds = mgr.deliverySystem
        local rec = deliveryRec
        if focusId ~= nil and ds ~= nil and type(ds.getDelivery) == "function" then
            local ok, focusRec = pcall(function() return ds:getDelivery(focusId) end)
            if ok and focusRec ~= nil and focusRec.farmId == fid and isActiveStatus(focusRec.status) then
                rec = focusRec
            elseif ok and focusRec ~= nil and (deliveryRec == nil) then
                -- Idle on focus; keep idle title (no stale cost)
                if not isActiveStatus(focusRec.status) then
                    rec = nil
                end
            end
        end
        -- If farm-scan found active delivery but focus getDelivery idle, keep HUD digits (rec from scan)
        setText(titleEl, deliveryTitleLine(rec))
    end

    -- More: focus honesty + pending + 8-of-N
    local moreParts = {}
    local depotCount = #farmDepots
    if focusId ~= nil then
        moreParts[#moreParts + 1] = string.format(
            tr("fd_rf_pda_focus_depot", "Focus: depot %d · %d depot(s)"),
            tonumber(focusId) or 0, depotCount)
    elseif depotCount == 0 then
        moreParts[#moreParts + 1] = tr("fd_rf_pda_no_depot", "no depot on your farm yet")
    end

    if type(mgr.getPendingOrder) == "function" then
        local ok, order = pcall(function() return mgr:getPendingOrder(fid) end)
        if ok and order ~= nil then
            moreParts[#moreParts + 1] = tr("fd_rf_pda_pending_order", "Pending order: not yet placed")
        end
    end

    -- Fill list + stock rows for focus only
    local fillList = {}
    if mgr.sfBridge ~= nil and type(mgr.sfBridge.getFillTypeList) == "function" then
        local ok, list = pcall(function() return mgr.sfBridge:getFillTypeList() end)
        if ok and type(list) == "table" then fillList = list end
    end
    local nFill = #fillList
    if nFill > MAX_ROWS then
        moreParts[#moreParts + 1] = string.format(
            tr("fd_rf_pda_showing_of", "Showing %d of %d"), MAX_ROWS, nFill)
    end
    setText(moreEl, table.concat(moreParts, "  ·  "))

    -- Hint: season (optional distance dropped under clutter)
    local hint = seasonHint(mgr.pricing)
    if deliveryRec ~= nil and isActiveStatus(deliveryRec.status) then
        local S = DeliverySystem and DeliverySystem.STATUS
        local loaded = (S ~= nil and deliveryRec.status == S.LOADED) or deliveryRec.status == 2
        if loaded and focusId ~= nil and mgr.deliverySystem ~= nil
            and type(mgr.deliverySystem.getDeliveryTruckDistance) == "function"
            and hint == ""
        then
            local ok, dist = pcall(function() return mgr.deliverySystem:getDeliveryTruckDistance(focusId) end)
            if ok and type(dist) == "number" then
                hint = string.format("%s: %.0fm", tr("fd_rf_pda_lbl_distance", "Distance"), dist)
            end
        end
    end
    -- SF teach stays in side body (densify copy); optional quiet append only if hint empty
    if hint == "" then
        local sfPresent = g_currentMission ~= nil and g_currentMission.soilFertilityManager ~= nil
        if not sfPresent then
            hint = tr("fd_rf_pda_sf_absent", "Soil Fertilizer: not installed (specialist unlocks quiet)")
        end
    end
    setText(hintEl, hint)

    if focusId == nil or mgr.depotSystem == nil or type(mgr.depotSystem.getStorageInfo) ~= "function" then
        clearRows(container)
        setVis(emptyEl, true)
        setText(emptyEl, tr("fd_rf_pda_no_stock", "no stock data yet"))
        return
    end

    local okInfo, storageInfo = pcall(function() return mgr.depotSystem:getStorageInfo(focusId) end)
    if not okInfo or type(storageInfo) ~= "table" then
        storageInfo = {}
    end

    local hasAnyEntry = false
    for _ in pairs(storageInfo) do
        hasAnyEntry = true
        break
    end

    if nFill == 0 or not hasAnyEntry then
        clearRows(container)
        setVis(emptyEl, true)
        setText(emptyEl, tr("fd_rf_pda_no_stock", "no stock data yet"))
        return
    end

    setVis(emptyEl, false)
    setText(emptyEl, "")
    local show = math.min(nFill, MAX_ROWS)
    local pricing = mgr.pricing
    for i = 1, MAX_ROWS do
        local a = findDescendant(container, "rfFwRow" .. i .. "A")
        local b = findDescendant(container, "rfFwRow" .. i .. "B")
        local c = findDescendant(container, "rfFwRow" .. i .. "C")
        local d = findDescendant(container, "rfFwRow" .. i .. "D")
        if i <= show then
            local ft = fillList[i]
            local name = ft and ft.name or "?"
            local display = (ft and ft.displayName) or name
            local entry = storageInfo[name]
            local current = entry and (tonumber(entry.current) or 0) or 0
            local capacity = entry and (tonumber(entry.capacity) or 0) or 0
            local buy, sell = "--", "--"
            if pricing ~= nil and type(pricing.getBuyPrice) == "function" then
                local okB, bv = pcall(function() return pricing:getBuyPrice(name) end)
                if okB then buy = formatMoney(bv) end
            end
            if pricing ~= nil and type(pricing.getSellPrice) == "function" then
                local okS, sv = pcall(function() return pricing:getSellPrice(name) end)
                if okS then sell = formatMoney(sv) end
            end
            setVis(a, true); setVis(b, true); setVis(c, true); setVis(d, true)
            setText(a, tostring(display))
            setText(b, string.format("%s / %s", tostring(current), tostring(capacity)))
            setText(c, buy)
            setText(d, sell)
        else
            setVis(a, false); setVis(b, false); setVis(c, false); setVis(d, false)
            setText(a, ""); setText(b, ""); setText(c, ""); setText(d, "")
        end
    end
end

function FdRfPdaGuest.onHide() end

function FdRfPdaGuest.tryRegister()
    if RfEscBootstrap ~= nil then
        if MOD_DIR == nil then
            print("[FertilizerDepot] FdRfPdaGuest: WARNING MOD_DIR nil - cannot ensureDoor")
        else
            local doorOk = RfEscBootstrap.ensureDoor(MOD_DIR, {
                profilesXml = MOD_DIR .. "xml/gui/rfEscProfiles.xml",
                iconPath = "textures/ui/menuIcon.dds",
            })
            if not doorOk then print("[FertilizerDepot] FdRfPdaGuest: WARNING ensureDoor failed (will retry)") end
        end
    end
    local host = getHost()
    local registerFn = host and (host.registerModule or host.registerPanel)
    if host == nil or registerFn == nil then return false end
    if not _registered then
        local ok = registerFn(host, {
            id = PANEL_ID,
            title = tr("fd_rf_pda_module_title", "Fertilizer Depot"),
            blurb = tr("fd_rf_pda_blurb", "Delivery posture plus stock and buy/sell prices for your focused depot. Read-only."),
            order = PANEL_ORDER,
            isAvailable = function() return getMgr() ~= nil end,
            onShow = FdRfPdaGuest.onShow,
            onHide = FdRfPdaGuest.onHide,
        })
        if ok then
            _registered = true
            print("[FertilizerDepot] FdRfPdaGuest: registered module fertilizerDepot on rfEscModules")
        else
            return false
        end
    end
    return _registered and g_inGameMenu ~= nil and g_inGameMenu.menuRealisticFarming ~= nil
end

function FdRfPdaGuest.isRegistered() return _registered end
function FdRfPdaGuest.reset() _registered = false end
