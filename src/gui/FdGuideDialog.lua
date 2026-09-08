-- =========================================================
-- Fertilizer Depot Field Guide - Field Guide
-- =========================================================
-- BUILD 19:15 (George CLOSED DESIGN 18:55 item 5): every Realistic Farming Esc page gets its own
-- guide, in its own mod, opened from the shared Help footer through this guest's onOpenHelp. The
-- chrome is SoilGuideDialog's so all of them read as one family; only the words differ.
-- Rows are { t = "H" | "B" | "S" | "COL", v = "text" }: header, body, spacer, column break.
-- =========================================================

---@class FdGuideDialog
FdGuideDialog = FdGuideDialog or {}
local FdGuideDialog_mt = Class(FdGuideDialog, ScreenElement)

local GUIDE_MOD_DIR = (FertilizerDepotModDirectory or g_currentModDirectory)

FdGuideDialog.INSTANCE = nil
FdGuideDialog.GUI_NAME = "FdGuideDialog"

FdGuideDialog.SUBTITLES = {
    "Overview - what the depot does and this page",
    "Esc Page - reading the depot table and lines",
    "The Building - shop, door, bays, production",
    "Buy and Sell - the depot window tab by tab",
    "Settings and FAQ - options, prices, answers",
}

FdGuideDialog.PAGE1 = {
    { t="H", v="WHAT THE FERTILIZER DEPOT DOES" },
    { t="B", v="The Fertilizer Depot is a placeable building" },
    { t="B", v="you buy from the shop and put on your farm." },
    { t="B", v="It keeps a private store of fertilizer for" },
    { t="B", v="your farm and lets you fill a trailer or" },
    { t="B", v="tank straight from that store." },
    { t="S", v=" " },
    { t="B", v="Each fill type has its own silo inside the" },
    { t="B", v="depot, so nitrogen, phosphate and potash" },
    { t="B", v="products are all held separately." },
    { t="S", v=" " },
    { t="H", v="TWO PLACES TO LOOK" },
    { t="B", v="The depot building has a window with Buy," },
    { t="B", v="Sell and Products tabs. That is where money" },
    { t="B", v="changes hands." },
    { t="S", v=" " },
    { t="B", v="This Realistic Farming page is the quiet" },
    { t="B", v="one. It lists what your depot is holding and" },
    { t="B", v="what each type costs to buy or sell right" },
    { t="B", v="now. It never spends or earns money." },
    { t="COL", v="" },
    { t="H", v="THE PAGE IN FRONT OF YOU" },
    { t="B", v="The table here has four columns: Fill," },
    { t="B", v="Stock, Buy and Sell." },
    { t="S", v=" " },
    { t="B", v="Fill is the fertilizer name. Stock is how" },
    { t="B", v="much the depot holds against how much it" },
    { t="B", v="can hold. Buy and Sell are the prices per" },
    { t="B", v="thousand litres right now." },
    { t="S", v=" " },
    { t="B", v="The list scrolls. Use the slider beside it" },
    { t="B", v="to reach types further down." },
    { t="S", v=" " },
    { t="H", v="IF THE TABLE IS EMPTY" },
    { t="B", v="Two different notes can appear. One tells" },
    { t="B", v="you to place a depot on your farm. The" },
    { t="B", v="other says the depot is standing empty and" },
    { t="B", v="needs stock ordering into it." },
    { t="S", v=" " },
    { t="B", v="Only depots owned by your own farm show up" },
    { t="B", v="here." },
}

FdGuideDialog.PAGE2 = {
    { t="H", v="OPENING THE PAGE" },
    { t="B", v="Press Esc for the in game menu, then pick" },
    { t="B", v="the Realistic Farming tab in the top row." },
    { t="S", v=" " },
    { t="B", v="This page is shared by several Realistic" },
    { t="B", v="Farming mods. A list of modules runs down" },
    { t="B", v="the left side. Click Fertilizer Depot in" },
    { t="B", v="that list to bring up the depot table." },
    { t="S", v=" " },
    { t="H", v="THE LEFT PANEL" },
    { t="B", v="Beside the module list is a short help" },
    { t="B", v="panel. For this module it reminds you the" },
    { t="B", v="page is a glance at stock against capacity" },
    { t="B", v="with buy and sell prices, and that buying" },
    { t="B", v="and selling happen at the depot building," },
    { t="B", v="not here." },
    { t="COL", v="" },
    { t="H", v="THE FOUR COLUMNS" },
    { t="B", v="Fill: the name of the fertilizer." },
    { t="B", v="Stock: what the depot's production hall" },
    { t="B", v="holds, then that bin's capacity. Tipping at" },
    { t="B", v="the depot is what fills it. If any of your" },
    { t="B", v="vehicles is carrying that fill, anywhere on" },
    { t="B", v="the map, a third figure after a dash is the" },
    { t="B", v="litres on board, not in the hall." },
    { t="B", v="Buy: what a thousand litres costs you." },
    { t="B", v="Sell: what the depot pays for a thousand." },
    { t="S", v=" " },
    { t="H", v="THE LINES UNDER THE TABLE" },
    { t="B", v="One line names the depot the table is" },
    { t="B", v="showing and how many depots your farm has." },
    { t="B", v="The page always shows the first one." },
    { t="S", v=" " },
    { t="B", v="Another line gives the season and its price" },
    { t="B", v="multiplier. With seasonal pricing switched" },
    { t="B", v="off that multiplier sits at one." },
    { t="S", v=" " },
    { t="H", v="WHAT CLICKING DOES" },
    { t="B", v="Nothing on this table. The rows are there" },
    { t="B", v="to be read. Clicking one does not select," },
    { t="B", v="buy or sell anything." },
    { t="S", v=" " },
    { t="B", v="Every type the depot can hold is listed," },
    { t="B", v="not only the ones in stock, so a new depot" },
    { t="B", v="shows a column of zeroes." },
}

FdGuideDialog.PAGE3 = {
    { t="H", v="BUYING AND PLACING IT" },
    { t="B", v="Look for the Fertilizer Depot in the shop" },
    { t="B", v="under production points. It is a large" },
    { t="B", v="industrial hall with silos and bays, and" },
    { t="B", v="its shop price is 25000." },
    { t="S", v=" " },
    { t="B", v="Place it with room in front for a trailer." },
    { t="B", v="There is a drive up bay on one side and a" },
    { t="B", v="walk in door for you on foot." },
    { t="S", v=" " },
    { t="H", v="OPENING THE DEPOT WINDOW" },
    { t="B", v="Walk up to the door on foot. When you are" },
    { t="B", v="close enough a prompt appears reading Open" },
    { t="B", v="Fertilizer Depot. Use it to open the buy" },
    { t="B", v="and sell window." },
    { t="S", v=" " },
    { t="B", v="No default key ships with the mod. Bind the" },
    { t="B", v="action Interact with Fertilizer Depot under" },
    { t="B", v="Options, Controls first." },
    { t="COL", v="" },
    { t="H", v="IT IS ALSO A PRODUCTION POINT" },
    { t="B", v="The same building runs production lines" },
    { t="B", v="that turn raw chemicals into finished" },
    { t="B", v="fertilizer." },
    { t="S", v=" " },
    { t="B", v="Inputs include ammonia, phosphoric acid," },
    { t="B", v="potassium chloride, urea, sulfur and water," },
    { t="B", v="plus lime, manure, slurry and compost for" },
    { t="B", v="the organic lines." },
    { t="S", v=" " },
    { t="B", v="Outputs cover the granular and liquid" },
    { t="B", v="fertilizers, insecticide, fungicide," },
    { t="B", v="gypsum, compost and liquid lime." },
    { t="S", v=" " },
    { t="H", v="THE LOADING BAYS" },
    { t="B", v="One bay sells the raw inputs to you, so a" },
    { t="B", v="line can be started without hauling." },
    { t="B", v="Another takes deliveries of chemicals and" },
    { t="B", v="organics into the building store." },
    { t="B", v="A third loads finished product back into" },
    { t="B", v="your own trailer." },
    { t="S", v=" " },
    { t="B", v="Levers outside turn the information boards" },
    { t="B", v="on and off." },
}

FdGuideDialog.PAGE4 = {
    { t="H", v="THE DEPOT WINDOW" },
    { t="B", v="Three tabs sit along the bottom: Buy, Sell" },
    { t="B", v="and Products, with Close beside them. A top" },
    { t="B", v="label shows the season and its price change." },
    { t="S", v=" " },
    { t="H", v="BUY TAB" },
    { t="B", v="The list shows every fill type with the" },
    { t="B", v="depot stock and the price for a thousand" },
    { t="B", v="litres. Stock reads Full when the silo is" },
    { t="B", v="full and Stocking when it is empty." },
    { t="S", v=" " },
    { t="B", v="Click a row to pick it. The order line" },
    { t="B", v="underneath names your choice. Use minus and" },
    { t="B", v="plus to set the amount in five hundred litre" },
    { t="B", v="steps, up to fifty thousand, then Confirm." },
    { t="S", v=" " },
    { t="B", v="A suitable trailer or tank must be parked" },
    { t="B", v="at the depot. Without one the window says" },
    { t="B", v="so and nothing is charged." },
    { t="S", v=" " },
    { t="B", v="Buying still works when the stock column" },
    { t="B", v="reads Stocking. Stored litres go first." },
    { t="COL", v="" },
    { t="H", v="SELL TAB" },
    { t="B", v="This tab looks at the vehicle parked at the" },
    { t="B", v="depot and lists the loads it carries, with" },
    { t="B", v="the litres on board and what they are worth." },
    { t="S", v=" " },
    { t="B", v="Selling empties the whole tank, so it asks" },
    { t="B", v="twice. The first click arms the row; a" },
    { t="B", v="second click on the same row sells." },
    { t="S", v=" " },
    { t="H", v="DRIVING IN TO SELL" },
    { t="B", v="Drive a loaded vehicle into the unloading" },
    { t="B", v="bay and the depot offers to buy the load in" },
    { t="B", v="a yes or no box. Say no and it waits." },
    { t="S", v=" " },
    { t="H", v="PRODUCTS TAB" },
    { t="B", v="This orders physical containers: big bags" },
    { t="B", v="or liquid tanks of a thousand litres each," },
    { t="B", v="up to five at a time." },
    { t="S", v=" " },
    { t="B", v="Unlike the Buy tab this comes out of depot" },
    { t="B", v="stock, so the depot must hold enough." },
}

FdGuideDialog.PAGE5 = {
    { t="H", v="OPENING SETTINGS" },
    { t="B", v="The settings box opens on the action Open" },
    { t="B", v="Depot Settings. No default key ships with" },
    { t="B", v="it, so bind it under Options, Controls." },
    { t="S", v=" " },
    { t="B", v="In multiplayer only the host or an admin" },
    { t="B", v="can change anything. Everyone else sees a" },
    { t="B", v="red note and rows they cannot move." },
    { t="S", v=" " },
    { t="H", v="THE FIVE SETTINGS" },
    { t="B", v="Seasonal Pricing: on or off." },
    { t="B", v="Storage per Fill Type: litres per silo." },
    { t="B", v="Sell Back Ratio: your share of buy price." },
    { t="B", v="Buy Price Multiplier: scales what you pay." },
    { t="B", v="Debug Logging: extra lines in the log." },
    { t="S", v=" " },
    { t="B", v="Out of the box a silo holds fifty thousand" },
    { t="B", v="litres and sell back is eighty percent." },
    { t="S", v=" " },
    { t="B", v="Reset Defaults just fills the boxes with the" },
    { t="B", v="starting values. Apply saves; Close discards." },
    { t="COL", v="" },
    { t="H", v="HOW A PRICE IS WORKED OUT" },
    { t="B", v="Start from the base price of the fill type." },
    { t="B", v="Multiply by the season, then by the buy" },
    { t="B", v="multiplier from settings. If Pro Staff Co" },
    { t="B", v="Op is installed its discount comes last." },
    { t="B", v="Sell price is that figure times sell back." },
    { t="S", v=" " },
    { t="H", v="COMMON QUESTIONS" },
    { t="B", v="Why do prices move through the year? Spring" },
    { t="B", v="is dearest and winter is cheapest. Turn" },
    { t="B", v="Seasonal Pricing off to stop it." },
    { t="S", v=" " },
    { t="B", v="Why will my trailer not fill? It must be" },
    { t="B", v="parked at the depot, it must accept that" },
    { t="B", v="fill type and it needs free space." },
    { t="S", v=" " },
    { t="B", v="Does it work without Soil Fertilizer? Yes." },
    { t="B", v="It falls back to the standard game" },
    { t="B", v="fertilizers, lime, manure and slurry." },
    { t="S", v=" " },
    { t="B", v="Is it multiplayer safe? Yes. The server" },
    { t="B", v="settles every purchase and sale." },
}

FdGuideDialog.PAGE_CONTENT = { FdGuideDialog.PAGE1, FdGuideDialog.PAGE2, FdGuideDialog.PAGE3, FdGuideDialog.PAGE4, FdGuideDialog.PAGE5 }

-- -- Constructor ------------------------------------------

function FdGuideDialog.new(target, customMt)
    local self = ScreenElement.new(target, customMt or FdGuideDialog_mt)
    self._contentLineEls = {}
    self._currentPage = 1
    return self
end

--- Loads the dialog into g_gui once. Safe to call twice, and safe to call when some other path has
--- already registered the same name.
function FdGuideDialog.register(modDirectory)
    if g_gui == nil then return end
    if g_gui.guis ~= nil and g_gui.guis[FdGuideDialog.GUI_NAME] ~= nil then return end
    if modDirectory ~= nil then GUIDE_MOD_DIR = modDirectory end
    if GUIDE_MOD_DIR == nil then return end
    FdGuideDialog.INSTANCE = FdGuideDialog.new()
    local ok, err = pcall(function()
        g_gui:loadGui(GUIDE_MOD_DIR .. "xml/gui/FdGuideDialog.xml", FdGuideDialog.GUI_NAME, FdGuideDialog.INSTANCE)
    end)
    if not ok then
        print("[FertilizerDepot] FdGuideDialog: loadGui failed: " .. tostring(err))
        FdGuideDialog.INSTANCE = nil
    end
end

function FdGuideDialog.show()
    if g_gui == nil then return end
    local loaded = g_gui.guis ~= nil and g_gui.guis[FdGuideDialog.GUI_NAME] ~= nil
    if not loaded then
        FdGuideDialog.register(GUIDE_MOD_DIR)
        loaded = g_gui.guis ~= nil and g_gui.guis[FdGuideDialog.GUI_NAME] ~= nil
    end
    if not loaded then return end
    g_gui:showDialog(FdGuideDialog.GUI_NAME)
end

-- -- Lifecycle --------------------------------------------

function FdGuideDialog:onGuiSetupFinished()
    FdGuideDialog:superClass().onGuiSetupFinished(self)
    self._elCol1 = self:getDescendantById("fdGuide_col1")
    self._elCol2 = self:getDescendantById("fdGuide_col2")
    self._elSubtitle = self:getDescendantById("fdGuide_subtitle")
end

function FdGuideDialog:onOpen()
    FdGuideDialog:superClass().onOpen(self)
    self._currentPage = 1
    self:_selectPage(1)
end

function FdGuideDialog:onClose()
    FdGuideDialog:superClass().onClose(self)
    self:_clearContent()
    self._currentPage = 1
end

-- -- Tabs -------------------------------------------------

function FdGuideDialog:onClickTab1() self:_selectPage(1) end
function FdGuideDialog:onClickTab2() self:_selectPage(2) end
function FdGuideDialog:onClickTab3() self:_selectPage(3) end
function FdGuideDialog:onClickTab4() self:_selectPage(4) end
function FdGuideDialog:onClickTab5() self:_selectPage(5) end

function FdGuideDialog:_selectPage(pageNum)
    if self._currentPage == pageNum and #self._contentLineEls > 0 then return end
    self:_clearContent()
    self._currentPage = pageNum
    if self._elSubtitle ~= nil then
        self._elSubtitle:setText(FdGuideDialog.SUBTITLES[pageNum] or "")
    end
    self:_buildContent(pageNum)
end

-- -- Content ----------------------------------------------

function FdGuideDialog:_buildContent(pageNum)
    local profileH = g_gui:getProfile("fdGuide_colHeader")
    local profileB = g_gui:getProfile("fdGuide_colBody")
    local profileS = g_gui:getProfile("fdGuide_colSpacer")
    if not profileH or not profileB then
        print("[FertilizerDepot] FdGuideDialog: column profiles not found")
        return
    end
    local content = FdGuideDialog.PAGE_CONTENT[pageNum]
    if content == nil then return end
    local currentBox = self._elCol1
    for _, row in ipairs(content) do
        if row.t == "COL" then
            if self._elCol1 ~= nil then self._elCol1:invalidateLayout() end
            currentBox = self._elCol2
        elseif currentBox ~= nil then
            local profile = (row.t == "H") and profileH
                         or (row.t == "S") and profileS
                         or profileB
            if profile ~= nil then
                local el = TextElement.new()
                el:loadProfile(profile, true)
                el:setText(row.v or "")
                currentBox:addElement(el)
                el:onGuiSetupFinished()
                table.insert(self._contentLineEls, { box = currentBox, el = el })
            end
        end
    end
    if self._elCol2 ~= nil then self._elCol2:invalidateLayout() end
end

function FdGuideDialog:_clearContent()
    for _, entry in ipairs(self._contentLineEls or {}) do
        if entry.box ~= nil then
            entry.box:removeElement(entry.el)
        end
    end
    self._contentLineEls = {}
    if self._elCol1 ~= nil then self._elCol1:invalidateLayout() end
    if self._elCol2 ~= nil then self._elCol2:invalidateLayout() end
end

-- -- Button -----------------------------------------------

function FdGuideDialog:onClickClose()
    g_gui:closeDialogByName(FdGuideDialog.GUI_NAME)
end
