-- =========================================================
-- FdRfPdaGuest - Esc RF PDA Fertilizer Depot framework (Table shell)
-- Stage-8 densify 2026-08-05 (Samantha DESIGN + George ENGINE ACK).
-- Soft-detect: mission.depotManager (preferred) then temporary g_DepotManager.
-- Read-only stock/price table + delivery title; no commerce writes.
-- =========================================================

FdRfPdaGuest = FdRfPdaGuest or {}

local MOD_DIR = (FertilizerDepotModDirectory or g_currentModDirectory)
local MOD_NAME = (FertilizerDepotModName or g_currentModName)
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

local _rfFwTitleBaselineWarned = false

--- rfFwTableTitle is shared by every Table-mode module (Income, Dairy, Depot, NPCFavor).
--- Income deliberately drops it to the bottom band (-360) for its own glance, and no host
--- calls onHide, so whoever shows next must reassert its own baseline or it inherits
--- Income's position. Cheap, idempotent, and keeps each guest owning its own layout.
local function resetFwTableTitlePos(container)
    local el = findDescendant(container, "rfFwTableTitle")
    if el == nil or type(el.setPosition) ~= "function" then return end
    if GuiUtils == nil or type(GuiUtils.getNormalizedXValue) ~= "function"
        or type(GuiUtils.getNormalizedYValue) ~= "function" then
        if not _rfFwTitleBaselineWarned then
            _rfFwTitleBaselineWarned = true
            print("[FertilizerDepot] FdRfPdaGuest: GuiUtils normalizer absent - cannot reassert rfFwTableTitle baseline")
        end
        return
    end
    -- BUILD 21:16: was 0px / 0px, the pre-16:32 baseline. The shared XML has placed
    -- rfFwTableTitle at 10px / -8px since the card inset, so this reset was handing the
    -- shared element back to a position that no longer exists in the page.
    el:setPosition(GuiUtils.getNormalizedXValue("10px", 0), GuiUtils.getNormalizedYValue("-8px", 0))
    if type(el.updateAbsolutePosition) == "function" then el:updateAbsolutePosition() end
end

-- ============================================================
-- BUILD 21:41: the column grid, applied every show.
-- ============================================================
-- All four Table guests (Income, Depot, Dairy, NPC Favor) paint into the SAME shared
-- elements, so whichever ran last leaves its geometry behind for the next one. Every guest
-- therefore has to state its own grid on entry rather than assume the XML baseline, or it
-- inherits the previous module's columns. This block is the even 4-bay.
--
-- Y IS HELD. Each move reads the element's own current Y and writes it straight back, and
-- setSize keeps the element's own height, so this can only ever change X and width.
--
-- Positions and sizes are NORMALISED in FS25, so everything goes through GuiUtils. A raw
-- pixel integer here would throw the row off the screen.
local FW_GRID_COLS = {
    { "A", "10px", "280px" },
    { "B", "310px", "280px" },
    { "C", "610px", "220px" },
    { "D", "850px", "280px" },
}
local FW_GRID_RULES = { "300px", "600px", "840px" }
local _fwGridWarned = false

local function applyFwGrid(container)
    if GuiUtils == nil or type(GuiUtils.getNormalizedXValue) ~= "function"
        or type(GuiUtils.getNormalizedScreenValues) ~= "function" then
        if not _fwGridWarned then
            _fwGridWarned = true
            print("[RF] applyFwGrid: GuiUtils normalizer absent - leaving the XML grid")
        end
        return
    end

    local function place(el, xPx, wPx)
        if el == nil then return end
        if type(el.setPosition) == "function" and el.position ~= nil then
            el:setPosition(GuiUtils.getNormalizedXValue(xPx, 0), el.position[2])
        end
        if wPx ~= nil and type(el.setSize) == "function" and el.size ~= nil then
            local norms = GuiUtils.getNormalizedScreenValues(wPx .. " 1px")
            if type(norms) == "table" and norms[1] ~= nil then
                el:setSize(norms[1], el.size[2])
            end
        end
        if type(el.updateAbsolutePosition) == "function" then el:updateAbsolutePosition() end
    end

    -- BUILD 21:54: this was ipairs over a table my generator had written with ",," between
    -- entries, which puts a nil at the skipped index. ipairs stops at the first nil, so only
    -- column A was ever placed and B, C and D stayed on the freeze XML while the rules moved
    -- anyway. A literal 1..4 walk cannot be truncated by a hole, and skipping a nil entry
    -- costs one column rather than throwing inside onShow.
    for i = 1, 4 do
        local c = FW_GRID_COLS[i]
        if c ~= nil then
            local letter, xPx, wPx = c[1], c[2], c[3]
            place(findDescendant(container, "rfFwCol" .. letter), xPx, wPx)
            for row = 1, 8 do
                place(findDescendant(container, "rfFwRow" .. row .. letter), xPx, wPx)
            end
        end
    end
    -- Vertical rules keep their own Y and their 1px width; only the column boundary moves.
    for i, xPx in ipairs(FW_GRID_RULES) do
        place(findDescendant(container, "rfFwRuleCol" .. i), xPx, nil)
    end
end

-- ============================================================
-- BUILD 22:15: optical centring, after the text exists.
-- ============================================================
-- Even-grid was dead on arrival as product: sliding a cell 15 to 45 px does not move where a
-- short left-glued word sits, so two builds of cell geometry changed nothing on screen. What
-- moves is the WORD, to the middle of its own bay, and the width of a word is only knowable
-- once setText has run.
--
-- The bay never changes. Only the element's X moves inside it, so a string that fills or
-- overflows its bay is left exactly where the freeze put it, and setSize is never called.
-- textAlignment and profiles are untouched by design.
local FW_OPTICAL_BOXES = {
    { "A", "10px", "280px" },
    { "B", "310px", "280px" },
    { "C", "610px", "220px" },
    { "D", "850px", "280px" }
}
local _opticalWarned = false

local function opticalCentreFwCells(container)
    if GuiUtils == nil or type(GuiUtils.getNormalizedXValue) ~= "function"
        or type(GuiUtils.getNormalizedScreenValues) ~= "function" then
        return
    end

    --- Centre one cell's text inside its bay, or leave the freeze X alone. Every refusal
    --- below is deliberate: a hidden or empty cell has nothing to centre, and a string that
    --- is as wide as its bay is already using all of it.
    local function centre(el, leftPx, widthPx)
        if el == nil then
            return
        end
        if type(el.getTextWidth) ~= "function" then
            if not _opticalWarned then
                _opticalWarned = true
                print("[RF] optical centre: getTextWidth absent - leaving the freeze X")
            end
            return
        end
        if el.visible == false then
            return
        end
        if type(el.text) ~= "string" or el.text == "" then
            return
        end
        local norms = GuiUtils.getNormalizedScreenValues(widthPx .. " 1px")
        if type(norms) ~= "table" or norms[1] == nil then
            return
        end
        local cellW = norms[1]
        local okW, textW = pcall(function() return el:getTextWidth() end)
        if not okW or type(textW) ~= "number" or textW <= 0 or textW >= cellW then
            return
        end
        if type(el.setPosition) == "function" and el.position ~= nil then
            local left = GuiUtils.getNormalizedXValue(leftPx, 0)
            el:setPosition(left + (cellW - textW) * 0.5, el.position[2])
            if type(el.updateAbsolutePosition) == "function" then el:updateAbsolutePosition() end
        end
    end

    for i = 1, 4 do
        local b = FW_OPTICAL_BOXES[i]
        if b ~= nil then
            centre(findDescendant(container, "rfFwCol" .. b[1]), b[2], b[3])
            for row = 1, 8 do
                centre(findDescendant(container, "rfFwRow" .. row .. b[1]), b[2], b[3])
            end
        end
    end
end

-- ============================================================
-- BUILD 07:06: the empty notice lives in the FIRST CELL, not across the sheet.
-- ============================================================
-- 22:32 fixed the vertical half of this and left the horizontal half wrong. The notice kept
-- the XML's 1120 box and was then optically centred inside it, so a left-aligned RF_HintText
-- painted its glyph run in the middle of the sheet and walked straight over rfFwRuleCol1 at
-- 300. Wizard's read is the plain one: the copy belongs in the first box, under DAY on Income
-- and under FILL on Depot.
--
-- So the box becomes bay A itself: the same 10 / 280 window rfFwColA and rfFwRow1A already
-- use, on the row-1 axis, one pitch high. Inner right edge is 290 against a rule at 300, which
-- is 10px of air, and that is exactly why this box is never nudged. A 280 box moved right is
-- a box that crosses the line Wizard is complaining about, so the X here is the freeze X and
-- nothing measures it. A string wider than the bay TRUNCATEs with an ellipsis; that is the
-- overflow valve, not a defect.
--
-- rfFwEmptyHint is ONE element behind all nine doors. Shrinking it is only safe because every
-- other page restores it, which is why Dairy and NPC Favor ship alongside this change.
--
-- ONE function owns X, Y, W, H and textMaxNumLines for both states. 22:32 split them and came
-- out correctly placed on one axis and wrong on the other.
local FW_HINT_X     = "10px"      -- sheet left and bay A left are the same edge
local FW_HINT_Y     = "-68px"     -- the row-1 glyph axis, same as rfFwRow1A
local FW_HINT_BAY_W = "280px"     -- bay A. 10 + 280 = 290, clear of rfFwRuleCol1 at 300
local FW_HINT_BAY_H = "22px"      -- 28 pitch less clearance: ends at -90, above the -92 rule
local FW_HINT_XML_W = "1120px"    -- the shared XML box, restored for every other page
local FW_HINT_XML_H = "44px"

--- Put rfFwEmptyHint in one of its two states and nothing in between.
--- "bay" is this page with an empty table: first cell, one line, truncating.
--- "xml" is every other case: the box exactly as RfPdaMenuPage.xml declares it.
local function setFwEmptyHintBox(container, mode)
    local el = findDescendant(container, "rfFwEmptyHint")
    if el == nil then
        return
    end
    if GuiUtils == nil or type(GuiUtils.getNormalizedXValue) ~= "function"
        or type(GuiUtils.getNormalizedYValue) ~= "function"
        or type(GuiUtils.getNormalizedScreenValues) ~= "function" then
        return
    end
    local bay = mode == "bay"
    -- Line count first. setSize re-runs the text layout, so the number of lines has to be
    -- true before the width it is measured against changes under it.
    el.textMaxNumLines = bay and 1 or 2
    local norms = GuiUtils.getNormalizedScreenValues(
        (bay and FW_HINT_BAY_W or FW_HINT_XML_W) .. " "
        .. (bay and FW_HINT_BAY_H or FW_HINT_XML_H))
    if type(norms) ~= "table" or norms[1] == nil or norms[2] == nil then
        return
    end
    if type(el.setSize) == "function" then
        el:setSize(norms[1], norms[2])
    end
    if type(el.setPosition) == "function" then
        el:setPosition(GuiUtils.getNormalizedXValue(FW_HINT_X, 0),
                       GuiUtils.getNormalizedYValue(FW_HINT_Y, 0))
        if type(el.updateAbsolutePosition) == "function" then el:updateAbsolutePosition() end
    end
end

--- Empty gets bay A, anything else gets the shared box back. This reads the element rather
--- than re-deriving the row count, so it stays in step with whichever refusal path inside
--- _paintShow actually ran.
local function placeFwEmptyHint(container)
    local el = findDescendant(container, "rfFwEmptyHint")
    local showing = el ~= nil and el.visible ~= false
        and type(el.text) == "string" and el.text ~= ""
    setFwEmptyHintBox(container, showing and "bay" or "xml")
end

function FdRfPdaGuest._paintShow(container, lightOnly)
    applyFwGrid(container)
    resetFwTableTitlePos(container)
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
        -- Title stays retired even here; the waiting notice goes where status now lives.
        setVis(titleEl, false)
        setText(titleEl, "")
        setText(moreEl, tr("fd_rf_pda_waiting", "Depot manager not ready"))
        clearRows(container)
        setVis(emptyEl, false)
        setText(emptyEl, "")
        setText(hintEl, "")
        return
    end

    local fid = farmId()
    local farmDepots = buildFarmDepots(mgr, fid)
    local focusId, deliveryRec = pickFocusDepot(mgr, farmDepots, fid)

    -- BUILD 21:41: delivery status reads UNDER the stock table, not in the top title.
    -- The column headers already announce the table, so a second title line above it was
    -- both redundant and the wrong place for a live status. rfFwTableTitle is hidden and
    -- cleared; resetFwTableTitlePos above still runs so the shared baseline is reasserted
    -- for the other Table-mode modules (Income, Dairy, NPCFavor) that do use it.
    setVis(titleEl, false)
    setText(titleEl, "")

    -- Delivery posture resolved exactly as before (HUD digit parity via getDelivery /
    -- farm-scan); only where it is painted has changed.
    local deliveryLine
    if focusId == nil and deliveryRec == nil then
        deliveryLine = deliveryTitleLine(nil)
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
        deliveryLine = deliveryTitleLine(rec)
    end

    -- More: delivery FIRST, then focus honesty + pending + 8-of-N
    local moreParts = {}
    local pendingPartIndex = nil
    if deliveryLine ~= nil and deliveryLine ~= "" then
        moreParts[#moreParts + 1] = deliveryLine
    end
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
            pendingPartIndex = #moreParts
        end
    end

    -- Fill list + stock rows for focus only
    local fillList = {}
    if mgr.sfBridge ~= nil and type(mgr.sfBridge.getFillTypeList) == "function" then
        local ok, list = pcall(function() return mgr.sfBridge:getFillTypeList() end)
        if ok and type(list) == "table" then fillList = list end
    end
    local nFill = #fillList

    -- BUILD 09:19 (PB-08). "Showing 8 of 30" used to be appended right here, and the footer
    -- was committed right here too - both BEFORE anything had asked whether the depot holds
    -- any stock at all. The two zero-stock returns further down then left that sentence
    -- standing under a table that says "no stock data yet". Brian read the page as claiming
    -- eight visible rows out of thirty while looking at an empty grid.
    --
    -- 30 was never the row count either. It is #fillList, the bridge's catalogue of fill
    -- types the depot COULD stock, so the range was fabricated from a list that has nothing
    -- to do with what is on screen.
    --
    -- The footer is now committed through one function that takes the range as an argument,
    -- and every exit calls it: the range is passed true only on the path that has actually
    -- proven focusId, nFill > 0 and hasAnyEntry, which is George's guard verbatim. The
    -- delivery status, focus honesty and pending-order parts are unaffected and still print
    -- on the empty paths, because those are true regardless of stock.
    local function commitMore(withRange)
        local parts = moreParts
        if withRange and nFill > MAX_ROWS then
            parts = {}
            for i = 1, #moreParts do parts[i] = moreParts[i] end
            parts[#parts + 1] = string.format(
                tr("fd_rf_pda_showing_of", "Showing %d of %d"), MAX_ROWS, nFill)
        end
        -- rfFwMore is ONE line: RF_TreatTargetLine at 19px across 1140px, so roughly 120
        -- glyphs before it clips. Delivery is the live status and outranks a static pending
        -- notice, so when both are present and the line will not fit, pending is what drops.
        local MORE_LINE_BUDGET = 120
        local moreText = table.concat(parts, "  ·  ")
        if #moreText > MORE_LINE_BUDGET and pendingPartIndex ~= nil
                and deliveryLine ~= nil and deliveryLine ~= "" then
            table.remove(parts, pendingPartIndex)
            moreText = table.concat(parts, "  ·  ")
        end
        setText(moreEl, moreText)
    end

    -- BUILD 09:19 (PB-08): the zero-state says what to DO about it, not just that it is
    -- empty. Which sentence depends on why it is empty, and the page already knows: no
    -- depot on the farm at all is a different problem from a depot standing empty, and
    -- telling a player to order stock when they have nowhere to put it is useless advice.
    local function paintEmptyState(hasDepot)
        local key = hasDepot and "fd_rf_pda_no_stock_guidance" or "fd_rf_pda_no_depot_guidance"
        local fallback = hasDepot
            and "no stock data yet - this depot is empty, order fertilizer to fill it"
            or "no stock data yet - place a depot on your farm to buy and store fertilizer"
        setVis(emptyEl, true)
        setText(emptyEl, tr(key, fallback))
    end

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
        -- No focus depot means the farm has none to focus on; that is the "place a depot"
        -- case, not the "your depot is empty" case.
        paintEmptyState(focusId ~= nil)
        commitMore(false)
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
        -- A focus depot exists here by definition (the guard above returned otherwise), so
        -- this is the standing-but-empty case: tell the player to order, not to build.
        paintEmptyState(true)
        commitMore(false)
        return
    end

    setVis(emptyEl, false)
    setText(emptyEl, "")
    -- The only path that has proven focusId ~= nil, nFill > 0 and hasAnyEntry, so the only
    -- path allowed to print a range.
    commitMore(true)
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


--- BUILD 22:15: onShow is now a wrapper. The paint runs first and may return early on any
--- of its refusal paths; the optical pass then runs regardless, which is what puts the
--- centred copy on an EMPTY table as well as a full one.
function FdRfPdaGuest.onShow(container, lightOnly)
    FdRfPdaGuest._paintShow(container, lightOnly)
    opticalCentreFwCells(container)
    placeFwEmptyHint(container)
end
