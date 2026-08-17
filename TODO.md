# TODO: FS25_FertilizerDepot

> Ecosystem role: **Soil and Crops** · Part of the Realistic Farming connected suite
> Status: FILLED from the ecosystem audit/baseline, kept current.
> Convention: `[ ]` open · `[~]` in progress · `[x]` done · `[!]` blocked. Newest at the top of each section.

## From the ecosystem audit (Arissani)
- [ ] Add `g_currentMission.depotManager` handle; keep the `Mission00.load` PREPEND hook (do not change to APPEND).
- [ ] Remove the FSBaseMission.mouseEvent and draw hooks (same violation class as WorkplaceTriggers addModEventListener); move to MasterHUD.
- [ ] Confirm the SoilFertilizer fill-type stock feature is in scope.

## Bugs
- [x] Money-authority (F15-class, 6 addMoney sites): VERIFIED server-gated in live source. DepotSystem's four (277/350/393/485) each sit behind an early `if not g_server then return` in their function (243/290/363/452); DeliverySystem's two (confirmPickup:173, cancelDelivery:219) run only from server-gated events (DepotDeliveryPickupEvent / DepotDeliveryCancelEvent :run, `if not g_server`), and the FDCancelDelivery console command is guarded too (DepotManager:867). The 2026-07-09 money-authority sweep flagged 6 ungated sites, but it grepped `getIsServer` and missed the `g_server` guards. Not a bug.
- [x] WV-002 hardcoded modName (issue #24): replaced with `g_currentModName` in PlaceableDepot.lua, main.lua (x2), DepotHUD.lua. Commit a0c87d2.

## Features / enhancements

- [x] Esc framework table freeze (Depot guest, #49): shared grid restated per show; 1.0.3.59.
- [~] In-game: Depot table keeps its columns after visiting another Esc guest in the same session.
- [x] Depot pricing integrations (C4, 3320ecf): ProStaff discount (DepotProStaffBridge), MDM price modifier registration (DepotMarketDynamicsBridge), FuelCosts diesel read (DepotFuelCostsBridge). Committed to development 2026-07-28.
- [ ] Companion read API: 7 read functions on `depotManager` (isActive-guarded, read-only).

## Cross-mod integration
- [x] ProStaffCoOp: DepotProStaffBridge reads fertilizer discount from proStaffManager (C4, 3320ecf).
- [x] MarketDynamics: DepotMarketDynamicsBridge registers a FerilizerDepot price modifier (C4, 3320ecf).
- [x] FuelCosts: DepotFuelCostsBridge reads diesel price from fuelCostsManager for display (C4, 3320ecf).
- [x] StateLedger: N/A by design - per-depot state is placeable-attached (base-game placeable save), settings go to SettingsHub. No central SL module (matches Arissani's readiness assessment). Own FSCareerMissionInfo settings save kept as the standalone fallback.
- [x] NetworkSync: C1 bridges shipped (FDNetworkSyncBridge, dual channel DepotSync + DeliverySync). PR #20 merged to main 2026-07-28.
- [x] MasterHUD: `FertilizerDepot_HUD` bridged (commit 69fce53); own FSBaseMission.draw stands down when active. Mouse/interact input stays on the own hook (MasterHUD owns draw ordering, not input).
- [x] SettingsHub: `FertilizerDepot` module bridged (bare name, selfPersisted, 5 settings as enum over the preset tables; commit 69fce53). Shift+D DepotSettingsDialog kept.
- [ ] SoilFertilizer read via `g_currentMission.soilFertilityManager` (detection) + `g_fillTypeManager` (stock); TaxMod consumes spend history.

## Docs / localization
- [x] Version stamped in modDesc.xml (v1.0.3.1).
- [ ] Keep all 26 languages in step for any new setting.

## Blocked / waiting on
- [~] Bedrock migrations: SettingsHub + MasterHUD DONE (commit 69fce53); StateLedger N/A by design. Only the NetworkSync transactional bridge remains (deferred - needs the NS build-brief, see Cross-mod integration).
