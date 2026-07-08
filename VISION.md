# Vision: FS25_FertilizerDepot

> Ecosystem role: **Soil and Crops** · Part of the Realistic Farming connected suite
> Status: FILLED from the ecosystem audit (Point 1-5, ecosystem-map, notes).
> Last updated: 2026-07-08

## 1. One-line purpose
A bulk fertilizer depot: placeable storage you stock in bulk and draw deliveries from, so fertilizer becomes a logistics and inventory decision instead of buying full-price bags one at a time.

## 2. Problem it solves
FS25 fertilizer is bought per pallet or bag at full price with no bulk economy and no on-farm storage logistics. FertilizerDepot adds a depot you fill in bulk and schedule deliveries from, giving fertilizer supply an inventory and cost dimension.

## 3. Design pillars
- **Placeable-driven.** Depot placeables register with the DepotManager at load. The `Mission00.load` PREPEND hook is required and must stay PREPEND (the manager must exist before placeables initialize).
- **Bulk economy.** Storing in bulk is the point; the depot is cheaper and more organised than per-bag buying.
- **Multiplayer-correct deliveries.** Depot and delivery state are server-authoritative and synced.
- **Soil-aware stock.** When SoilFertilizer is present, its fill types can appear in the depot's stock list, read through SoilFertilizer's public surface (and `g_fillTypeManager`), never SF internals.

## 4. Role in the ecosystem
- Public handle: `g_currentMission.depotManager` (added by the audit; the old `g_DepotManager` getfenv alias is backward-compat only, to remove in v2).
- Reads from (consumes): SoilFertilizer via `g_currentMission.soilFertilityManager` (detection) plus `g_fillTypeManager` for the SF fill-type stock integration.
- Read by (consumers): TaxMod (spend history), FarmTablet, and companions, via 7 read functions on `g_currentMission.depotManager` (all isActive-guarded, read-only).
- Core-API registration status (specced in Point 1-5, not yet wired):
  - StateLedger (save/load): planned, depot settings serialized; removes the FSCareerMissionInfo save hook.
  - NetworkSync (MP state): planned, TWO channels `DepotSync` + `DeliverySync`, consolidating the current 11 custom event classes (the highest count in the ecosystem).
  - MasterHUD (overlays): planned, depot HUD draw + mouse; removes the FSBaseMission.draw AND mouseEvent hooks.
  - SettingsHub (admin settings): planned. The Shift+D DepotSettingsDialog (`g_gui:showDialog`) is the correct pattern and stays, coexisting with the SettingsHub registration.

## 5. Explicit non-goals
- Not a replacement for SoilFertilizer's fertilizer mechanics. The depot is stock and logistics; the soil sim is SF's.
- Does not read SoilFertilizer internals. It uses the public handle and `g_fillTypeManager`.

## 6. Success criteria
- Bulk stock and deliveries work correctly and stay consistent in multiplayer.
- SoilFertilizer fill types appear in the depot stock when SF is installed, and the depot is fully functional when it is not.
- The 11 event classes collapse to two channels with manageable delta payloads.

## 7. Open questions for the audit
- Confirm the SoilFertilizer fill-type addition feature (adding SF types to the depot stock list) is desired and in scope.
- Confirm the seven companion read functions are the surface TaxMod and FarmTablet need.
