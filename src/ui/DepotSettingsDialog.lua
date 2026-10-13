-- =========================================================
-- FS25 Fertilizer Depot - Settings Dialog
-- =========================================================
-- Opened via Shift+D hotkey. Admin-only in multiplayer.
-- Uses MultiTextOptionElement for each setting (cycle presets).

local _depotSettingsModDir  = (FertilizerDepotModDirectory or g_currentModDirectory)  -- captured at source() time
local _depotSettingsInstance = nil                  -- local so __index chain can't shadow it

--- Localised text the SoilFertilizer #973 way: hasText is the gate (the engine's own
--- answer to "does this key exist", I18N.lua:194), the return is opaque past it. Never a
--- comparison against the "$l10n_" attribute prefix, which getText cannot return, nor
--- against the "Missing '<key>' in l10n<suffix>.xml" sentence (I18N.lua:186), which is a
--- bet on how the engine renders a failure. Inside a mod's environment g_i18n IS the
--- mod's own i18n (mods.lua:453, chained to the global), so no environment lookup is
--- needed: g_modEnvironments appears in no file of the decompiled engine.
local function tr(key, fallback)
    local i18n = g_i18n
    if i18n == nil or type(i18n.hasText) ~= "function" or type(i18n.getText) ~= "function" then
        return fallback or key
    end
    local okHas, has = pcall(i18n.hasText, i18n, key)
    if not okHas or has ~= true then return fallback or key end
    local ok, text = pcall(i18n.getText, i18n, key)
    if not ok or type(text) ~= "string" or text == "" then return fallback or key end
    return text
end

---@class DepotSettingsDialog
DepotSettingsDialog = DepotSettingsDialog or {}

local DepotSettingsDialog_mt = Class(DepotSettingsDialog, MessageDialog)

function DepotSettingsDialog.new()
    local self = MessageDialog.new(nil, DepotSettingsDialog_mt)
    -- Element caches
    self.optSeasonalPricing  = nil
    self.optStorageCapacity  = nil
    self.optSellRatio        = nil
    self.optBuyMultiplier    = nil
    self.optDebugLogging     = nil
    self.adminBadge          = nil
    self.isOpen              = false
    return self
end

-- ─── Registration ────────────────────────────────────────

function DepotSettingsDialog.register()
    if _depotSettingsInstance then return end
    _depotSettingsInstance = DepotSettingsDialog.new()
    DepotLogger.info("DepotSettingsDialog.register: loading GUI from %s", _depotSettingsModDir)
    g_gui:loadGui(_depotSettingsModDir .. "xml/gui/DepotSettingsDialog.xml",
        "DepotSettingsDialog", _depotSettingsInstance)
end

function DepotSettingsDialog.show()
    DepotLogger.info("DepotSettingsDialog.show called")
    if not _depotSettingsInstance then
        DepotSettingsDialog.register()
    end
    g_gui:showDialog("DepotSettingsDialog")
end

function DepotSettingsDialog.refreshIfOpen()
    if _depotSettingsInstance and _depotSettingsInstance.isOpen then
        _depotSettingsInstance:refresh()
    end
end

-- ─── Lifecycle ───────────────────────────────────────────

function DepotSettingsDialog:onCreate()
    local ok, err = pcall(function()
        DepotSettingsDialog:superClass().onCreate(self)
    end)
    if not ok then
        DepotLogger.error("DepotSettingsDialog:onCreate error: %s", tostring(err))
    end
end

function DepotSettingsDialog:onGuiSetupFinished()
    DepotSettingsDialog:superClass().onGuiSetupFinished(self)
    self.optSeasonalPricing = self:getDescendantById("optSeasonalPricing")
    self.optStorageCapacity = self:getDescendantById("optStorageCapacity")
    self.optSellRatio       = self:getDescendantById("optSellRatio")
    self.optBuyMultiplier   = self:getDescendantById("optBuyMultiplier")
    self.optDebugLogging    = self:getDescendantById("optDebugLogging")
    self.adminBadge         = self:getDescendantById("adminBadge")

    -- Populate option lists
    if self.optSeasonalPricing then
        self.optSeasonalPricing:setTexts({
            tr("fd_settings_off", "OFF"),
            tr("fd_settings_on",  "ON"),
        })
    end
    if self.optStorageCapacity then
        local labels = {}
        for _, v in ipairs(DepotSettings.CAPACITY_OPTIONS) do
            table.insert(labels, string.format("%s L", tostring(math.floor(v / 1000)) .. "k"))
        end
        self.optStorageCapacity:setTexts(labels)
    end
    if self.optSellRatio then
        local labels = {}
        for _, v in ipairs(DepotSettings.SELL_RATIO_OPTIONS) do
            table.insert(labels, string.format("%d%%", math.floor(v * 100)))
        end
        self.optSellRatio:setTexts(labels)
    end
    if self.optBuyMultiplier then
        local labels = {}
        for _, v in ipairs(DepotSettings.BUY_MULT_OPTIONS) do
            table.insert(labels, string.format("%.2f×", v))
        end
        self.optBuyMultiplier:setTexts(labels)
    end
    if self.optDebugLogging then
        self.optDebugLogging:setTexts({
            tr("fd_settings_off", "OFF"),
            tr("fd_settings_on",  "ON"),
        })
    end
end

function DepotSettingsDialog:onOpen()
    DepotSettingsDialog:superClass().onOpen(self)
    self.isOpen = true
    self:refresh()
end

function DepotSettingsDialog:fdSettingsOnClose()
    DepotSettingsDialog:superClass().onClose(self)
    self.isOpen = false
end

-- ─── Refresh ─────────────────────────────────────────────

function DepotSettingsDialog:refresh()
    if not g_DepotManager then return end
    local s = g_DepotManager.settings
    local isAdmin = g_currentMission.isMasterUser or g_server ~= nil

    if self.adminBadge then
        self.adminBadge:setVisible(not isAdmin)
    end

    if self.optSeasonalPricing then
        self.optSeasonalPricing:setState(s.seasonalPricing and 2 or 1)
        self.optSeasonalPricing:setDisabled(not isAdmin)
    end
    if self.optStorageCapacity then
        self.optStorageCapacity:setState(s:getCapacityIndex())
        self.optStorageCapacity:setDisabled(not isAdmin)
    end
    if self.optSellRatio then
        self.optSellRatio:setState(s:getSellRatioIndex())
        self.optSellRatio:setDisabled(not isAdmin)
    end
    if self.optBuyMultiplier then
        self.optBuyMultiplier:setState(s:getBuyMultiplierIndex())
        self.optBuyMultiplier:setDisabled(not isAdmin)
    end
    if self.optDebugLogging then
        self.optDebugLogging:setState(s.debugLogging and 2 or 1)
        self.optDebugLogging:setDisabled(not isAdmin)
    end
end

-- ─── Option Callbacks ────────────────────────────────────
-- Changes are buffered in the UI elements — nothing is sent until Apply is clicked.

function DepotSettingsDialog:onSeasonalPricingChanged(state)  end
function DepotSettingsDialog:onStorageCapacityChanged(state)  end
function DepotSettingsDialog:onSellRatioChanged(state)        end
function DepotSettingsDialog:onBuyMultiplierChanged(state)    end
function DepotSettingsDialog:onDebugLoggingChanged(state)     end

-- Reset: update UI to defaults without sending to server — Apply still required.
function DepotSettingsDialog:onResetDefaults()
    if not (g_currentMission.isMasterUser or g_server ~= nil) then return end
    local d = DepotSettings.DEFAULTS
    if self.optSeasonalPricing then
        self.optSeasonalPricing:setState(d.seasonalPricing and 2 or 1)
    end
    if self.optStorageCapacity then
        self.optStorageCapacity:setState(
            DepotSettings.indexInOptions(DepotSettings.CAPACITY_OPTIONS, d.storageCapacity))
    end
    if self.optSellRatio then
        self.optSellRatio:setState(
            DepotSettings.indexInOptions(DepotSettings.SELL_RATIO_OPTIONS, d.sellRatio))
    end
    if self.optBuyMultiplier then
        self.optBuyMultiplier:setState(
            DepotSettings.indexInOptions(DepotSettings.BUY_MULT_OPTIONS, d.buyMultiplier))
    end
    if self.optDebugLogging then
        self.optDebugLogging:setState(d.debugLogging and 2 or 1)
    end
end

-- Apply: read current UI states and send all settings to server, then close.
function DepotSettingsDialog:onApplySettings()
    if not (g_currentMission.isMasterUser or g_server ~= nil) then return end
    -- Positional {key, value}, in handleSettings' read order (FDNetworkSyncBridge.lua)
    local allSent = true
    local function send(key, value)
        local sent = FDNetworkSyncBridge.sendAction(FDNetworkSyncBridge.ACTION_SETTINGS, { key, value })
        allSent = allSent and sent
    end
    if self.optSeasonalPricing then
        send("seasonalPricing", tostring(self.optSeasonalPricing:getState() == 2))
    end
    if self.optStorageCapacity then
        local v = DepotSettings.CAPACITY_OPTIONS[self.optStorageCapacity:getState()]
        if v then send("storageCapacity", tostring(v)) end
    end
    if self.optSellRatio then
        local v = DepotSettings.SELL_RATIO_OPTIONS[self.optSellRatio:getState()]
        if v then send("sellRatio", tostring(v)) end
    end
    if self.optBuyMultiplier then
        local v = DepotSettings.BUY_MULT_OPTIONS[self.optBuyMultiplier:getState()]
        if v then send("buyMultiplier", tostring(v)) end
    end
    if self.optDebugLogging then
        send("debugLogging", tostring(self.optDebugLogging:getState() == 2))
    end
    if not allSent then
        DepotLogger.warning("Depot settings not sent: no NetworkSync and not the host")
    end
    self:close()
end

-- Close: discard any pending UI changes (nothing was sent yet).
function DepotSettingsDialog:onCloseSettings()
    self:close()
end
