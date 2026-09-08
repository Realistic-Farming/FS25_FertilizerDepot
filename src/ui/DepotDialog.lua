-- =========================================================
-- FS25 Fertilizer Depot - Buy/Sell Dialog
-- =========================================================

local _depotDialogModDir  = (FertilizerDepotModDirectory or g_currentModDirectory)
local _depotDialogModName = (FertilizerDepotModName or g_currentModName)
local _depotDialogInstance = nil

local function tr(key, fallback)
    local modEnv = g_modEnvironments and g_modEnvironments[_depotDialogModName]
    local i18n = (modEnv and modEnv.i18n) or g_i18n
    if i18n then
        local ok, text = pcall(function() return i18n:getText(key) end)
        -- FS25 returns "Missing 'key' in l10n_XX.xml" for unknown keys instead of throwing
        if ok and text and text ~= "" and text ~= ("$l10n_" .. key)
           and not text:find("^Missing '") then
            return text
        end
    end
    return fallback or key
end

---@class DepotDialog
DepotDialog = DepotDialog or {}
DepotDialog.TAB_BUY      = "buy"
DepotDialog.TAB_SELL     = "sell"
DepotDialog.TAB_PRODUCTS = "products"
DepotDialog.ORDER_STEP  = 500
DepotDialog.ORDER_MIN   = 500
DepotDialog.ORDER_MAX   = 50000

local DepotDialog_mt = Class(DepotDialog, MessageDialog)

function DepotDialog.new(depotId)
    local self = MessageDialog.new(nil, DepotDialog_mt)
    self.depotId          = depotId
    self.tab              = DepotDialog.TAB_BUY
    -- BUILD 17:21: one scrolling list, so there is no page offset any more. self.listRows is
    -- what the list is showing right now, rebuilt by each refresh*Tab, and its index IS the index
    -- into the backing array for that tab.
    self.listRows         = {}
    -- The Sell tab's armed fill type, by name so a rebuilt list cannot arm a different row.
    self.sellArmedName    = nil
    self.fillTypes        = {}
    self.selectedFillType = nil
    self.orderAmount      = 1000

    -- Products tab state
    self.productFillTypes   = {}
    self.selectedProduct    = nil
    self.productQuantity    = 1

    -- Element caches
    self.seasonLabel      = nil
    self.pageLabel        = nil
    self.statusText       = nil
    self.prevPageBtn      = nil
    self.nextPageBtn      = nil
    self.colTypeHeader    = nil
    self.colStockHeader   = nil
    self.colPriceHeader   = nil
    self.preOrderDivider  = nil
    self.preOrderRow      = nil
    self.selectedTypeName = nil
    self.amountDisplay    = nil

    -- Products order row elements
    self.productsOrderRow     = nil
    self.prodSelectedName     = nil
    self.prodQtyDisplay       = nil
    self.prodTotalPrice       = nil

    -- Cached sell list built each refresh: [{ft, liters, revenue}, ...]
    self.sellList = {}
    return self
end

-- ─── Registration ────────────────────────────────────────

function DepotDialog.getInstance()
    return _depotDialogInstance
end

function DepotDialog.register()
    if _depotDialogInstance then return end
    _depotDialogInstance = DepotDialog.new(nil)
    DepotLogger.info("DepotDialog.register: loading GUI from %s", _depotDialogModDir)
    g_gui:loadGui(_depotDialogModDir .. "xml/gui/DepotDialog.xml",
        "DepotDialog", _depotDialogInstance)
end

function DepotDialog.show(depotId)
    DepotLogger.info("DepotDialog.show called for depot #%s", tostring(depotId))
    if not _depotDialogInstance then
        DepotDialog.register()
    end
    local dlg = _depotDialogInstance
    dlg.depotId          = depotId
    dlg.tab              = DepotDialog.TAB_BUY
    dlg.selectedFillType = nil
    dlg.sellArmedName    = nil
    dlg.orderAmount      = 1000
    dlg.selectedProduct  = nil
    dlg.productQuantity  = 1
    g_gui:showDialog("DepotDialog")
end

-- ─── Lifecycle ───────────────────────────────────────────

function DepotDialog:onCreate()
    local ok, err = pcall(function() DepotDialog:superClass().onCreate(self) end)
    if not ok then DepotLogger.error("DepotDialog:onCreate error: %s", tostring(err)) end
end

function DepotDialog:onGuiSetupFinished()
    DepotDialog:superClass().onGuiSetupFinished(self)

    self.seasonLabel     = self:getDescendantById("seasonLabel")
    self.pageLabel       = self:getDescendantById("pageLabel")
    self.statusText      = self:getDescendantById("statusText")
    self.prevPageBtn     = self:getDescendantById("prevPageBtn")
    self.nextPageBtn     = self:getDescendantById("nextPageBtn")
    self.colTypeHeader   = self:getDescendantById("colTypeHeader")
    self.colStockHeader  = self:getDescendantById("colStockHeader")
    self.colPriceHeader  = self:getDescendantById("colPriceHeader")
    self.preOrderDivider  = self:getDescendantById("preOrderDivider")
    self.preOrderRow      = self:getDescendantById("preOrderRow")
    self.selectedTypeName = self:getDescendantById("selectedTypeName")
    self.amountDisplay    = self:getDescendantById("amountDisplay")

    self.productsOrderRow = self:getDescendantById("productsOrderRow")
    self.prodSelectedName = self:getDescendantById("prodSelectedName")
    self.prodQtyDisplay   = self:getDescendantById("prodQtyDisplay")
    self.prodTotalPrice   = self:getDescendantById("prodTotalPrice")

    self.depotList = self:getDescendantById("depotList")
end

function DepotDialog:onOpen()
    DepotDialog:superClass().onOpen(self)
    if g_DepotManager then
        self.fillTypes       = g_DepotManager.sfBridge:getFillTypeList()
        self.productFillTypes = g_DepotManager.sfBridge:getProductFillTypeList()
    else
        self.fillTypes        = {}
        self.productFillTypes = {}
    end
    self:_syncTabSections()
    self:refresh()
end

function DepotDialog:fdOnClose()
    DepotDialog:superClass().onClose(self)
    if g_DepotManager then
        g_DepotManager.activeDialog = nil
    end
end

function DepotDialog:onSyncReceived(depotId)
    if depotId == self.depotId then self:refresh() end
end

function DepotDialog:showStatus(text)
    if self.statusText then self.statusText:setText(text) end
end

-- ─── Tab Switching ───────────────────────────────────────

function DepotDialog:onTabBuy()
    self.tab = DepotDialog.TAB_BUY
    self.sellArmedName = nil
    self:_syncTabSections()
    self:refresh()
end

function DepotDialog:onTabSell()
    self.tab = DepotDialog.TAB_SELL
    self.sellArmedName = nil
    self:_syncTabSections()
    self:refresh()
end

function DepotDialog:onTabProducts()
    self.tab = DepotDialog.TAB_PRODUCTS
    self.sellArmedName = nil
    self.selectedProduct = nil
    self.productQuantity = 1
    self:_syncTabSections()
    self:refresh()
end

function DepotDialog:_syncTabSections()
    local isBuy      = (self.tab == DepotDialog.TAB_BUY)
    local isProducts = (self.tab == DepotDialog.TAB_PRODUCTS)
    if self.preOrderDivider  then self.preOrderDivider:setVisible(isBuy or isProducts) end
    if self.preOrderRow      then self.preOrderRow:setVisible(isBuy) end
    if self.productsOrderRow then self.productsOrderRow:setVisible(isProducts) end
end

-- ─── Refresh ─────────────────────────────────────────────

function DepotDialog:refresh()
    self:updateSeasonLabel()
    if self.tab == DepotDialog.TAB_BUY then
        if self.colTypeHeader  then self.colTypeHeader:setText(tr("fd_col_type",   "Fill Type"))    end
        if self.colStockHeader then self.colStockHeader:setText(tr("fd_col_stock", "Depot Stock"))  end
        if self.colPriceHeader then self.colPriceHeader:setText(tr("fd_col_price", "Price / 1kL")) end
        self:refreshBuyTab()
    elseif self.tab == DepotDialog.TAB_SELL then
        if self.colTypeHeader  then self.colTypeHeader:setText(tr("fd_col_type",    "Fill Type"))   end
        if self.colStockHeader then self.colStockHeader:setText(tr("fd_col_amount", "Amount"))      end
        if self.colPriceHeader then self.colPriceHeader:setText(tr("fd_col_revenue","Revenue"))     end
        self:refreshSellTab()
    else
        if self.colTypeHeader  then self.colTypeHeader:setText(tr("fd_col_type",   "Fill Type"))    end
        if self.colStockHeader then self.colStockHeader:setText(tr("fd_col_stock", "Depot Stock"))  end
        if self.colPriceHeader then self.colPriceHeader:setText(tr("fd_col_price", "Price / 1kL")) end
        self:refreshProductsTab()
    end
end

function DepotDialog:updateSeasonLabel()
    if not self.seasonLabel or not g_DepotManager then return end
    local key   = g_DepotManager.pricing:getSeasonKey()
    local label = tr(key, key)
    local mult  = g_DepotManager.pricing:getSeasonMultiplier()
    local sign  = mult >= 1.0 and "+" or ""
    local text = string.format("%s %s%.0f%%", label, sign, (mult - 1.0) * 100)
    local fuelPrice = DepotFuelCostsBridge.getFuelPrice()
    if fuelPrice then
        text = text .. string.format("  |  Diesel: $%.2f/L", fuelPrice)
    end
    self.seasonLabel:setText(text)
end

function DepotDialog:refreshBuyTab()
    local system  = g_DepotManager and g_DepotManager.depotSystem
    local pricing = g_DepotManager and g_DepotManager.pricing

    local rows = {}
    for i, ft in ipairs(self.fillTypes) do
        local stored   = system and system:getStorageLevel(self.depotId, ft.name) or 0
        local farmId = g_localPlayer and g_localPlayer.farmId or 1
        local buyPrice = pricing and pricing:getBuyPrice(ft.name, farmId) or 0
        local priceStr = string.format("$%.2f/kL", buyPrice * 1000)
        local stockStr
        if stored >= DepotConstants.STORAGE_CAPACITY then
            stockStr = tr("fd_depot_stock_full", "Full")
        elseif stored <= 0 then
            stockStr = tr("fd_depot_stock_stocking", "Stocking")
        else
            stockStr = string.format("%dL", math.floor(stored))
        end
        local isSelected = self.selectedFillType and self.selectedFillType.name == ft.name
        rows[i] = {
            name = ft.displayName or ft.name,
            stock = stockStr,
            price = priceStr,
            action = isSelected and tr("fd_depot_selected", "Selected") or tr("fd_depot_select_btn", "Select"),
        }
    end
    self.listRows = rows
    self:syncDepotList()
end

function DepotDialog:refreshSellTab()
    local system  = g_DepotManager and g_DepotManager.depotSystem
    local pricing = g_DepotManager and g_DepotManager.pricing
    local sellTypes = {}

    if system and self.depotId then
        -- Single vehicle scan across all fill types (avoids N separate 96-vehicle searches)
        local nearbyFills = system:buildNearbyFillMap(self.depotId)
        for _, ft in ipairs(self.fillTypes) do
            if ft.fillTypeIndex and ft.fillTypeIndex > 0 then
                local entry = nearbyFills[ft.fillTypeIndex]
                if entry then
                    local rev = pricing and pricing:calculateSellRevenue(ft.name, entry.fillLevel) or 0
                    table.insert(sellTypes, {ft = ft, liters = entry.fillLevel, revenue = rev})
                end
            end
        end
    end

    -- Cache so executeSell uses the same snapshot as what was displayed
    self.sellList = sellTypes

    local rows = {}
    for i, entry in ipairs(sellTypes) do
        rows[i] = {
            name = entry.ft.displayName or entry.ft.name,
            stock = string.format("%.0fL", entry.liters),
            price = string.format("$%.2f", entry.revenue),
            action = (self.sellArmedName ~= nil and self.sellArmedName == entry.ft.name)
                and tr("fd_depot_sell_confirm", "Confirm sale")
                or tr("fd_depot_sell_btn", "Sell All"),
        }
    end
    self.listRows = rows
    self:syncDepotList()

    if self.statusText then
        if #sellTypes == 0 then
            self.statusText:setText(tr("fd_depot_no_trailer", "No compatible trailer nearby."))
        else
            self.statusText:setText("")
        end
    end
end

function DepotDialog:refreshProductsTab()
    local system  = g_DepotManager and g_DepotManager.depotSystem
    local pricing = g_DepotManager and g_DepotManager.pricing

    if self.statusText then
        if #self.productFillTypes == 0 then
            self.statusText:setText(tr("fd_products_none", "No physical products available."))
        else
            self.statusText:setText("")
        end
    end

    local rows = {}
    for i, ft in ipairs(self.productFillTypes) do
        local stored      = system and system:getStorageLevel(self.depotId, ft.name) or 0
        local pricePerUnit = pricing and
            (pricing:getBuyPrice(ft.name) * ft.litresPerUnit) or 0
        local priceStr = string.format("$%.2f/unit", pricePerUnit)
        local stockStr
        if stored <= 0 then
            stockStr = tr("fd_depot_stock_stocking", "Stocking")
        else
            local units = math.floor(stored / ft.litresPerUnit)
            stockStr = string.format("%d units", units)
        end
        local action
        if self.selectedProduct and self.selectedProduct.name == ft.name then
            action = tr("fd_depot_selected", "Selected")
        elseif ft.productLabel == "bag" then
            action = tr("fd_products_order_bag", "Order Bag")
        else
            action = tr("fd_products_order_tank", "Order Tank")
        end
        rows[i] = { name = ft.displayName or ft.name, stock = stockStr, price = priceStr, action = action }
    end
    self.listRows = rows
    self:syncDepotList()

    self:_updateProductsOrderRow()
end

function DepotDialog:_updateProductsOrderRow()
    local pricing = g_DepotManager and g_DepotManager.pricing
    local ft = self.selectedProduct

    if self.prodSelectedName then
        self.prodSelectedName:setText(ft and (ft.displayName or ft.name) or "—")
    end
    if self.prodQtyDisplay then
        self.prodQtyDisplay:setText(string.format("×%d", self.productQuantity))
    end
    if self.prodTotalPrice then
        if ft and pricing then
            local farmId = g_localPlayer and g_localPlayer.farmId or 1
            local total = pricing:getBuyPrice(ft.name, farmId) * ft.litresPerUnit * self.productQuantity
            self.prodTotalPrice:setText(string.format("$%.2f", total))
        else
            self.prodTotalPrice:setText("")
        end
    end
end

-- ---------------------------------------------------------
-- BUILD 17:21: the one stock list. The dialog is its own dataSource AND delegate (the XML loader
-- already made it the delegate; setDataSource is ours), so a row click lands on
-- onListSelectionChanged below and there is no per-row Button to keep in step.
-- ---------------------------------------------------------

function DepotDialog:getNumberOfItemsInSection(list, section)
    return #(self.listRows or {})
end

function DepotDialog:populateCellForItemInSection(list, section, index, cell)
    if cell == nil or type(cell.getDescendantByName) ~= "function" then return end
    local row = (self.listRows or {})[index]
    if row == nil then return end
    local function put(name, value)
        local el = cell:getDescendantByName(name)
        if el ~= nil and type(el.setText) == "function" then el:setText(value or "") end
    end
    put("cellName", row.name)
    put("cellStock", row.stock)
    put("cellPrice", row.price)
    put("cellAction", row.action)
end

--- A click on a row is the row action. This is the engine's CLICK channel, not its selection-changed
--- delegate: the delegate only fires when the index really changes (SmoothListElement hasChanged), and
--- a SmoothList is born with selectedIndex 1, so the top row could never act on itself. notifyClick
--- runs on every click because selectOnClick defaults to false. Index is the index into the tab's
--- backing array, because listRows is built one-for-one from it in the same order. Do not also route
--- onListSelectionChanged here: the engine selects before it notifies, so both would act twice.
function DepotDialog:onDepotRowClick(list, section, index, element, wasAlreadySelected)
    local i = tonumber(index)
    if i == nil or i < 1 then return end
    self:onRowAction(i)
end

--- setDataSource once per element, by identity so a re-sourced chunk re-binds; reloadData only
--- when the engine has finished loading the list. No timer ever calls this.
function DepotDialog:syncDepotList()
    local list = self.depotList
    if list == nil then return end
    if list.dataSource ~= self and type(list.setDataSource) == "function" then
        list:setDataSource(self)
    end
    if type(list.setDelegate) == "function" and list.delegate ~= self then
        list:setDelegate(self)
    end
    if list.isLoaded and type(list.reloadData) == "function" then
        pcall(list.reloadData, list)
    end
end

function DepotDialog:getSellCount()
    return #self.sellList
end

-- ─── Buy Actions ─────────────────────────────────────────

function DepotDialog:onAmountMinus()
    self.orderAmount = math.max(DepotDialog.ORDER_MIN, self.orderAmount - DepotDialog.ORDER_STEP)
    if self.amountDisplay then
        self.amountDisplay:setText(string.format("%dL", self.orderAmount))
    end
end

function DepotDialog:onAmountPlus()
    self.orderAmount = math.min(DepotDialog.ORDER_MAX, self.orderAmount + DepotDialog.ORDER_STEP)
    if self.amountDisplay then
        self.amountDisplay:setText(string.format("%dL", self.orderAmount))
    end
end

function DepotDialog:onConfirmOrder()
    if not self.selectedFillType then
        self:showStatus(tr("fd_depot_select_first", "Select a fill type first."))
        return
    end

    local farmId = g_localPlayer and g_localPlayer.farmId or 1
    local ft     = self.selectedFillType
    local system = g_DepotManager and g_DepotManager.depotSystem

    -- A compatible vehicle must be parked near the depot to fill it directly
    local vehicle, unitIndex = system and system:findCompatibleVehicle(
        self.depotId, ft.fillTypeIndex, false)

    if vehicle and unitIndex then
        FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PURCHASE, {
            depotId = self.depotId, fillTypeName = ft.name,
            fillTypeIndex = ft.fillTypeIndex, liters = self.orderAmount, farmId = farmId,
        })
        self:showStatus(string.format(
            tr("fd_depot_filling", "Filling %.0fL of %s into your vehicle..."),
            self.orderAmount, ft.displayName or ft.name))
    else
        self:showStatus(tr("fd_depot_no_trailer", "No compatible trailer nearby."))
    end
end

-- ─── Row Action (Select for Buy/Products, Sell All for Sell) ──────

function DepotDialog:onRowAction(rowSlot)
    if self.tab == DepotDialog.TAB_SELL then
        -- BUILD 17:21: selling a whole trailer load is the one irreversible thing on this window, and
        -- the list acts on mouse DOWN over the full row width, with no release gate and nothing to
        -- abort onto. So the first click arms the row and says so in its action cell; only a second
        -- click on the SAME fill type sells. Buy and Products just move a selection, so they act at
        -- once as before.
        local entry = self.sellList[rowSlot]
        if entry == nil or entry.ft == nil then return end
        local name = entry.ft.name
        if self.sellArmedName ~= nil and self.sellArmedName == name then
            self.sellArmedName = nil
            self:executeSell(rowSlot)
        else
            self.sellArmedName = name
            self:refreshSellTab()
        end
    elseif self.tab == DepotDialog.TAB_PRODUCTS then
        self:selectProductRow(rowSlot)
    else
        self:selectRow(rowSlot)
    end
end

function DepotDialog:selectRow(rowSlot)
    local ft    = self.fillTypes[rowSlot]
    if not ft then return end
    self.selectedFillType = ft
    self.orderAmount      = 1000
    if self.selectedTypeName then
        self.selectedTypeName:setText(ft.displayName or ft.name)
    end
    if self.amountDisplay then
        self.amountDisplay:setText(string.format("%dL", self.orderAmount))
    end
    self:showStatus("")
    -- Refresh buy rows so the selected row shows "Selected"
    self:refreshBuyTab()
end

function DepotDialog:selectProductRow(rowSlot)
    local ft    = self.productFillTypes[rowSlot]
    if not ft then return end
    self.selectedProduct = ft
    self.productQuantity = 1
    self:showStatus("")
    self:refreshProductsTab()
end

function DepotDialog:onProductQtyMinus()
    self.productQuantity = math.max(1, self.productQuantity - 1)
    self:_updateProductsOrderRow()
end

function DepotDialog:onProductQtyPlus()
    self.productQuantity = math.min(DepotConstants.MAX_PRODUCT_QUANTITY, self.productQuantity + 1)
    self:_updateProductsOrderRow()
end

function DepotDialog:onProductConfirm()
    if not self.selectedProduct then
        self:showStatus(tr("fd_depot_select_first", "Select a fill type first."))
        return
    end

    local farmId = g_localPlayer and g_localPlayer.farmId or 1
    local ft     = self.selectedProduct
    local system = g_DepotManager and g_DepotManager.depotSystem

    local stored = system and system:getStorageLevel(self.depotId, ft.name) or 0
    local litresNeeded = self.productQuantity * ft.litresPerUnit
    if stored < litresNeeded then
        self:showStatus(tr("fd_products_no_stock", "Insufficient depot stock for this order."))
        return
    end

    FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_PRODUCT_ORDER, {
        depotId = self.depotId, fillTypeName = ft.name,
        fillTypeIndex = ft.fillTypeIndex, quantity = self.productQuantity, farmId = farmId,
    })

    local label = ft.productLabel == "bag"
        and tr("fd_products_label_bag", "Bag(s)")
        or  tr("fd_products_label_tank", "Tank(s)")
    self:showStatus(string.format(
        tr("fd_products_ordered", "%d× %s %s ordered — delivering to depot."),
        self.productQuantity, ft.displayName or ft.name, label))
end

function DepotDialog:executeSell(rowSlot)
    local entry = self.sellList[rowSlot]
    if not entry then return end
    local farmId = g_localPlayer and g_localPlayer.farmId or 1
    self:showStatus(string.format(
        tr("fd_depot_filling", "Selling %.0fL %s..."),
        entry.liters, entry.ft.displayName or entry.ft.name))
    FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_SELL, {
        depotId = self.depotId, fillTypeName = entry.ft.name,
        fillTypeIndex = entry.ft.fillTypeIndex, liters = entry.liters, farmId = farmId,
    })
end

-- ─── Close ───────────────────────────────────────────────

function DepotDialog:onClickClose()
    self:close()
end

