-- =========================================================
-- FdRfPdaGuest - Esc RF PDA Fertilizer Depot framework (Table shell)
-- Stage-8 densify 2026-08-05 (Samantha DESIGN + George ENGINE ACK).
-- Soft-detect: mission.depotManager (preferred) then temporary g_DepotManager.
-- Read-only stock/price table; no commerce writes.
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

-- The separator the shared footer already uses, so the table reads as one voice.
local VEH_SEP = "-"

-- BUILD 21:40 (George CLOSED DESIGN 21:35 item 5): the old fixed eight-row table is dead chrome.
-- Its rows moved into the shared SmoothList at 17:21, but the eleven hairline Bitmaps were never
-- hidden by either sheet painter, so they stood behind the sheet as a second frame. The door now
-- declares them visible="false"; this is the belt that also covers an older door copy, and it is
-- what stops them coming back if any other module hands the chrome over still visible.
local LEGACY_GRID_IDS = {
    "rfFwRuleHead", "rfFwRuleRow1", "rfFwRuleRow2", "rfFwRuleRow3", "rfFwRuleRow4",
    "rfFwRuleRow5", "rfFwRuleRow6", "rfFwRuleRow7",
    "rfFwRuleCol1", "rfFwRuleCol2", "rfFwRuleCol3",
}

local function hideLegacyGrid(container)
    for _, id in ipairs(LEGACY_GRID_IDS) do
        setVis(findDescendant(container, id), false)
    end
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

-- BUILD 17:21 (George CLOSED DESIGN 14:00): the shared Esc table scrolls. Rows go into the door's one
-- SmoothList (rfFwSheetList) instead of the eight fixed rfFwRow* lines, so a long list is reachable
-- instead of being cut off under a footer that counted rows nobody could reach. The 32 static cells
-- stay declared in the door because Dairy, NPC Favor and Pro Staff each hide them by id; this guest
-- just stops writing to them.
local _sheetRows = {}
local _sheetContainer = nil

local fdSheetSource = {}

function fdSheetSource:getNumberOfItemsInSection(list, section)
    return #_sheetRows
end

function fdSheetSource:populateCellForItemInSection(list, section, index, cell)
    if cell == nil or type(cell.getDescendantByName) ~= "function" then return end
    local row = _sheetRows[index]
    if row == nil then return end
    setText(cell:getDescendantByName("rfFwSheetA"), row[1])
    setText(cell:getDescendantByName("rfFwSheetB"), row[2])
    setText(cell:getDescendantByName("rfFwSheetC"), row[3])
    setText(cell:getDescendantByName("rfFwSheetD"), row[4])
end

--- setDataSource by identity - this module's source, not whichever Table guest showed last - then
--- setDelegate explicitly (the XML loader made the host page the delegate), and reloadData only once
--- the engine has finished loading the list. No timer ever calls this.
local function syncSheet(container, rows)
    _sheetRows = rows or {}
    -- The host hands onSheetRow an index and nothing else, so the container the sheet was painted
    -- into is remembered here for the band lookup.
    _sheetContainer = container
    local list = findDescendant(container, "rfFwSheetList")
    local box = findDescendant(container, "rfFwSheetBox")
    if list == nil then
        setVis(box, false)
        return false
    end
    if list.dataSource ~= fdSheetSource and type(list.setDataSource) == "function" then
        list:setDataSource(fdSheetSource)
    end
    if type(list.setDelegate) == "function" and list.delegate ~= fdSheetSource then
        list:setDelegate(fdSheetSource)
    end
    setVis(box, #_sheetRows > 0)
    if #_sheetRows == 0 then
        setVis(findDescendant(container, "rfFwSheetBand"), false)
    end
    if list.isLoaded and type(list.reloadData) == "function" then
        pcall(list.reloadData, list)
    end
    return true
end

--- BUILD 19:15 (George CLOSED DESIGN 18:55 item 2): the readout for the row the player clicked. Three
--- lines under the sheet: what it is and how much of it the depot holds, the two prices, and the one
--- sentence that matters, which is that this page never moves stock or money. Read-only, so there is
--- no chip and no selection highlight (SmoothListElement publishes no setSelectedIndex).
---@param index number row index into the array syncSheet last built
function FdRfPdaGuest.onSheetRow(index)
    local container = _sheetContainer
    if container == nil then return end
    local band = findDescendant(container, "rfFwSheetBand")
    if band == nil then return end
    local row = _sheetRows[tonumber(index) or 0]
    if row == nil then
        setVis(band, false)
        setText(band, "")
        return
    end
    -- BUILD 21:40: line 1 is the hall bin, the same figure the Stock column now prints. A fill
    -- type this hall has no recipe for has no capacity to quote, so it is named as such.
    local head
    if row.cap ~= nil then
        head = string.format(tr("fd_rf_pda_band_hall", "%s: hall %s / %s L"),
            tostring(row.name or row[1]), tostring(row.hall or "0"), tostring(row.cap))
    else
        head = string.format(tr("fd_rf_pda_band_absent", "%s: this hall does not stock it"),
            tostring(row.name or row[1]))
    end
    if row.onVehicle ~= nil then
        head = head .. string.format(tr("fd_rf_pda_band_onveh", "  %s on vehicle: %s L"),
            VEH_SEP, tostring(math.floor(row.onVehicle)))
    end
    local tail = tr("fd_rf_pda_band_readonly",
        "This page is a read-out. Buying and selling happen at the depot itself.")
    if (tonumber(row.hall) or 0) <= 0 and row.onVehicle ~= nil then
        -- The one case where the page can actually tell the player what to do next. The hall fills
        -- from its unload triggers: ProductionPoint loads that station from the .sellingStation key
        -- (ProductionPoint.lua 212-213) and gives it the hall storage as a target (line 270), so
        -- tipping is what puts litres in the bin. Selling in the walk-in dialog credits the other
        -- book and would not move this number.
        tail = string.format(tr("fd_rf_pda_band_empty_hall",
            "Hall empty. %s L is on your vehicle: tip it in at the depot to store it."),
            tostring(math.floor(row.onVehicle)))
    end
    local lines = {
        head,
        string.format(tr("fd_rf_pda_band_prices", "Buy %s   Sell %s"), tostring(row[3]), tostring(row[4])),
        tail,
    }
    setText(band, table.concat(lines, "\n"))
    setVis(band, true)
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

--- Focus on the first depot owned by this farm (no delivery system anymore).
local function pickFocusDepot(mgr, farmDepots, fid)
    return farmDepots[1], nil
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
    hideLegacyGrid(container)
    paintSide(container, "rf_pda_side_info_fertilizer_depot",
        "Depot glance: stock vs capacity, buy/sell.\n"
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
    local focusId = pickFocusDepot(mgr, farmDepots, fid)

    -- BUILD 21:41: rfFwTableTitle stays hidden; the column headers already announce the
    -- table and resetFwTableTitlePos above still reasserts the shared baseline for the
    -- other Table-mode modules (Income, Dairy, NPCFavor).
    setVis(titleEl, false)
    setText(titleEl, "")

    -- More: focus honesty + 8-of-N
    local moreParts = {}
    local depotCount = #farmDepots
    if focusId ~= nil then
        moreParts[#moreParts + 1] = string.format(
            tr("fd_rf_pda_focus_depot", "Focus: depot %d · %d depot(s)"),
            tonumber(focusId) or 0, depotCount)
    elseif depotCount == 0 then
        moreParts[#moreParts + 1] = tr("fd_rf_pda_no_depot", "no depot on your farm yet")
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
    -- proven focusId, nFill > 0 and hasAnyEntry, which is George's guard verbatim.
    -- BUILD 17:21: the range sentence is gone with the fixed rows. The stock list scrolls, so
    -- there is no longer a count of rows the player cannot reach, and PB-08's whole argument about
    -- when the range may be printed goes with it. The footer is just the footer.
    local function commitMore()
        setText(moreEl, table.concat(moreParts, "  ·  "))
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

    -- Hint: season
    local hint = seasonHint(mgr.pricing)
    -- SF teach stays in side body (densify copy); optional quiet append only if hint empty
    if hint == "" then
        local sfPresent = g_currentMission ~= nil and g_currentMission.soilFertilityManager ~= nil
        if not sfPresent then
            hint = tr("fd_rf_pda_sf_absent", "Soil Fertilizer: not installed (specialist unlocks quiet)")
        end
    end
    setText(hintEl, hint)

    if focusId == nil then
        clearRows(container)
        syncSheet(container, {})
        -- No focus depot means the farm has none to focus on; that is the "place a depot"
        -- case, not the "your depot is empty" case.
        paintEmptyState(false)
        commitMore()
        return
    end

    -- BUILD 21:40 (George CLOSED DESIGN 21:35): Stock is the PRODUCTION HALL, not the shop book.
    -- The depot placeable is a vendored Giants productionPoint. The player tips into its unload
    -- triggers and the fill lands in the hall bins - 100000 L for the ten chemical inputs,
    -- 1000000 L for the outputs, per xml/depotPlaceable.xml. depotSystem.storageLevel is a
    -- different book: a flat 50000 L per fill type that only the walk-in dialog writes and reads.
    -- Esc was reading that book, which is why every row still said 0 / 50000 after he filled the
    -- building. This page now reads the hall and nothing else. The two books are deliberately not
    -- merged, and nothing here writes either one or invents a third.
    local hallPoint = nil
    do
        local placeable = (type(mgr.depots) == "table") and mgr.depots[focusId] or nil
        local spec = placeable ~= nil and placeable.spec_productionPoint or nil
        local pp = spec ~= nil and spec.productionPoint or nil
        if pp ~= nil and type(pp.getFillLevel) == "function" and type(pp.getCapacity) == "function" then
            hallPoint = pp
        end
    end
    if hallPoint == nil then
        clearRows(container)
        syncSheet(container, {})
        setVis(emptyEl, true)
        setText(emptyEl, tr("fd_rf_pda_no_hall",
            "no stock data yet - this depot's production hall did not answer"))
        commitMore()
        return
    end

    -- getFillLevel and getCapacity take a fill type INDEX. The bridge caches its index list on the
    -- first call, and buyFillType already re-resolves from the name (DepotSystem.lua 248-254) to
    -- dodge SoilFertilizer index drift, so ask the live manager by name first and keep the cached
    -- index as the fallback.
    local function liveFillTypeIndex(ft)
        if ft == nil then return nil end
        if ft.name ~= nil and g_fillTypeManager ~= nil
            and type(g_fillTypeManager.getFillTypeIndexByName) == "function" then
            local okIdx, idx = pcall(function()
                return g_fillTypeManager:getFillTypeIndexByName(ft.name)
            end)
            if okIdx then
                idx = tonumber(idx)
                if idx ~= nil and idx > 0 then return idx end
            end
        end
        local cached = tonumber(ft.fillTypeIndex)
        if cached ~= nil and cached > 0 then return cached end
        return nil
    end

    -- BUILD 21:40 (item 4): what this farm is carrying, anywhere on the map, as a readout only.
    -- Farm-wide by design: buildNearbyFillMap is distance filtered (8 m from the depot root, 15 m
    -- from the unload and spawn nodes) so it is blind to a trailer standing in a field.
    --
    -- The seen-set is not decoration. Every Vehicle registers itself with the vehicle system
    -- (Vehicle.lua:1010), so vehicleSystem.vehicles ALREADY lists attached implements as their own
    -- entries, and this pass SUMS rather than taking first-wins the way buildNearbyFillMap does.
    -- Walking getAttachedImplements without the set would count a hooked trailer twice, once as a
    -- list entry and once through its tractor. The walk is kept because it costs nothing here and
    -- it is the only thing that would find an implement the system somehow never registered.
    -- Read through the Giants getters, once per show, no timer, nothing written back.
    local onVehicleByFill = {}
    do
        local vs = g_currentMission ~= nil and g_currentMission.vehicleSystem or nil
        local list = vs ~= nil and vs.vehicles or nil
        if type(list) == "table" then
            local seen = {}
            local addVehicle
            addVehicle = function(veh, depth)
                if veh == nil or seen[veh] ~= nil or depth > 8 then return end
                seen[veh] = true
                local spec = veh.spec_fillUnit
                if spec ~= nil and type(spec.fillUnits) == "table"
                    and type(veh.getOwnerFarmId) == "function"
                    and type(veh.getFillUnitFillType) == "function"
                    and type(veh.getFillUnitFillLevel) == "function" then
                    local okOwn, owner = pcall(function() return veh:getOwnerFarmId() end)
                    if okOwn and owner == fid then
                        for fuIdx = 1, #spec.fillUnits do
                            local okT, ftIdx = pcall(function() return veh:getFillUnitFillType(fuIdx) end)
                            local okL, level = pcall(function() return veh:getFillUnitFillLevel(fuIdx) end)
                            ftIdx = okT and tonumber(ftIdx) or nil
                            level = (okL and tonumber(level)) or 0
                            if ftIdx ~= nil and ftIdx > 0 and level > 0 then
                                onVehicleByFill[ftIdx] = (onVehicleByFill[ftIdx] or 0) + level
                            end
                        end
                    end
                end
                if type(veh.getAttachedImplements) == "function" then
                    local okImp, impls = pcall(function() return veh:getAttachedImplements() end)
                    if okImp and type(impls) == "table" then
                        for _, impl in ipairs(impls) do
                            if impl ~= nil and impl.object ~= nil then
                                addVehicle(impl.object, depth + 1)
                            end
                        end
                    end
                end
            end
            for _, veh in ipairs(list) do
                addVehicle(veh, 1)
            end
        end
    end

    -- The hall answers for every fill type it has a recipe for, so an empty hall is a wall of
    -- honest zeros rather than a missing table. The only empty case left is an empty catalogue.
    if nFill == 0 then
        clearRows(container)
        syncSheet(container, {})
        -- A focus depot exists here by definition (the guard above returned otherwise), so
        -- this is the standing-but-empty case: tell the player to order, not to build.
        paintEmptyState(true)
        commitMore()
        return
    end

    setVis(emptyEl, false)
    setText(emptyEl, "")
    commitMore()
    local pricing = mgr.pricing
    -- Every fill type the depot stocks goes into the list; the box scrolls past the eight the old
    -- fixed sheet could show, which is the whole point of the change.
    local rows = {}
    for i = 1, nFill do
        local ft = fillList[i]
        local name = ft and ft.name or "?"
        local display = (ft and ft.displayName) or name
        local idx = liveFillTypeIndex(ft)
        local current, capacity = 0, 0
        if idx ~= nil then
            local okCap, cap = pcall(function() return hallPoint:getCapacity(idx) end)
            if okCap then capacity = tonumber(cap) or 0 end
            local okLvl, lvl = pcall(function() return hallPoint:getFillLevel(idx) end)
            if okLvl then current = tonumber(lvl) or 0 end
        end
        local buy, sell = "--", "--"
        if pricing ~= nil and type(pricing.getBuyPrice) == "function" then
            local okB, bv = pcall(function() return pricing:getBuyPrice(name) end)
            -- BUILD 20:53: per 1000 L with two decimals, the format the depot's own window uses.
            -- formatMoney asks g_i18n for ZERO decimals on a PER-LITRE price, so every live price
            -- under half a unit per litre printed as zero.
            if okB then buy = string.format("$%.2f/kL", (bv or 0) * 1000) end
        end
        if pricing ~= nil and type(pricing.getSellPrice) == "function" then
            local okS, sv = pcall(function() return pricing:getSellPrice(name) end)
            if okS then sell = string.format("$%.2f/kL", (sv or 0) * 1000) end
        end
        local onVehicle = (ft ~= nil and ft.fillTypeIndex ~= nil) and onVehicleByFill[ft.fillTypeIndex] or nil
        -- ProductionPoint.getCapacity returns 0 for a fill type that is neither an input nor an
        -- output of this hall's recipes. Two of the thirty in the bridge catalogue are like that,
        -- LIQUIDFERTILIZER and DIGESTATE, and neither appears anywhere in depotPlaceable.xml, so
        -- the hall genuinely cannot hold them. Printing 0 / 0 would read as a fault; say it plainly
        -- instead, and keep the row rather than hiding it.
        local stockCell
        if capacity > 0 then
            stockCell = string.format("%d / %d", math.floor(current), math.floor(capacity))
        else
            stockCell = tr("fd_rf_pda_stock_absent", "0 / not stocked here")
        end
        if onVehicle ~= nil then
            -- The tank reading never changes shape, so a zero row still reads 0 / 50000; the
            -- vehicle load is added after it rather than replacing it.
            stockCell = string.format("%s  %s %s L", stockCell, VEH_SEP, tostring(math.floor(onVehicle)))
        end
        rows[i] = {
            tostring(display),
            stockCell,
            buy,
            sell,
            name = tostring(display),
            hall = tostring(math.floor(current)),
            cap = (capacity > 0) and tostring(math.floor(capacity)) or nil,
            onVehicle = onVehicle,
        }
    end
    clearRows(container)
    syncSheet(container, rows)
end

function FdRfPdaGuest.onHide() end

--- BUILD 19:15: the Esc Help footer asks whichever module is showing to open its own guide, so
--- every companion ships and owns its own help instead of borrowing Soil's.
---@param container table|nil
function FdRfPdaGuest.onOpenHelp(container)
    if FdGuideDialog ~= nil and type(FdGuideDialog.show) == "function" then
        FdGuideDialog.show()
    end
end

function FdRfPdaGuest.tryRegister()
    if RfEscBootstrap ~= nil then
        if MOD_DIR == nil then
            print("[FertilizerDepot] FdRfPdaGuest: WARNING MOD_DIR nil - cannot ensureDoor")
        else
            local doorOk = RfEscBootstrap.ensureDoor(MOD_DIR, {
                profilesXml = MOD_DIR .. "xml/gui/rfEscProfiles.xml",
                iconPath = "textures/ui/menuIcon.dds",
            })
            -- BUILD 19:15 (George CLOSED DESIGN 18:55 item 5): load this mod's Field Guide at the
            -- same moment the door itself loads. A GUI loaded from a mod directory later, once the
            -- mod's own file system context has closed, fails to open.
            if FdGuideDialog ~= nil and type(FdGuideDialog.register) == "function" then
                pcall(FdGuideDialog.register, MOD_DIR)
            end
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
            blurb = tr("fd_rf_pda_blurb", "Stock and buy/sell prices for your focused depot. Read-only."),
            order = PANEL_ORDER,
            isAvailable = function() return getMgr() ~= nil end,
            onShow = FdRfPdaGuest.onShow,
            onHide = FdRfPdaGuest.onHide,
            onOpenHelp = FdRfPdaGuest.onOpenHelp,
            onSheetRow = FdRfPdaGuest.onSheetRow,
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
