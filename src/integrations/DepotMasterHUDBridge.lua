-- =========================================================
-- FS25 Fertilizer Depot - MasterHUD bridge
-- =========================================================
-- Author: TisonK
-- =========================================================
-- Optional bridge to FS25_MasterHUD. Fertilizer Depot ships standalone, so
-- this is delegate-when-present:
--   * MasterHUD installed -> Depot registers its HUD draw as a self-draw.
--     MasterHUD then owns the single draw loop, the menu/dialog suspend, and
--     cross-mod ordering, so the depot HUD stacks cleanly with the rest of the
--     ecosystem instead of every mod hooking FSBaseMission.draw independently.
--   * MasterHUD absent -> Depot's own FSBaseMission.draw hook runs the exact
--     same draw, exactly as before.
--
-- MasterHUD owns draw ordering + suspend only, not layout and not input, so
-- the depot HUD keeps positioning itself and the mouse/interact hooks stay on
-- Depot's own handlers. drawStack() is the single source of the draw body,
-- shared with the fallback hook so the two paths can never diverge.
-- =========================================================

DepotMasterHUDBridge = DepotMasterHUDBridge or {}

DepotMasterHUDBridge.HUD_ID = "FertilizerDepot_HUD"
DepotMasterHUDBridge.active = false   -- MasterHUD present and we registered

-- The depot HUD draw body. Same call the standalone FSBaseMission.draw hook
-- makes; drawHUD() self-guards on client/GUI/visibility as before.
function DepotMasterHUDBridge.drawStack()
    -- Suite hide: MasterHUD # key. No-op when MasterHUD absent.
    local mh = (g_currentMission ~= nil and g_currentMission.masterHUD) or g_masterHUD
    if mh ~= nil and mh.areHudsHidden ~= nil and mh:areHudsHidden() then return end
    if g_DepotManager ~= nil then
        g_DepotManager:drawHUD()
    end
end

-- Register with MasterHUD if present. Called at loadMission00Finished, after
-- the HUD has published its g_currentMission handle (Mission00.load).
function DepotMasterHUDBridge.register(mgr)
    DepotMasterHUDBridge.active = false

    local hud = (g_currentMission ~= nil and g_currentMission.masterHUD) or g_masterHUD
    if hud == nil then
        DepotLogger.info("MasterHUD not detected; depot HUD uses its own draw hook")
        return
    end

    local ok, err = pcall(function()
        hud:subscribe(DepotMasterHUDBridge.HUD_ID, {
            draw = DepotMasterHUDBridge.drawStack,
        })
    end)

    if ok then
        DepotMasterHUDBridge.active = true
        DepotLogger.info("Registered depot HUD with MasterHUD (single draw loop + menu-suspend)")
        if hud.registerEditListener ~= nil then
            hud:registerEditListener(DepotMasterHUDBridge.HUD_ID, {
                enter = function()
                    local dh = mgr ~= nil and mgr.hud or nil
                    if dh ~= nil and dh.enterEditMode ~= nil then dh:enterEditMode() end
                end,
                exit = function()
                    local dh = mgr ~= nil and mgr.hud or nil
                    if dh ~= nil and dh.editMode and dh.exitEditMode ~= nil then dh:exitEditMode() end
                end,
            })
        end
    else
        DepotLogger.warning("MasterHUD registration failed: %s (using own draw hook)", tostring(err))
    end
end
