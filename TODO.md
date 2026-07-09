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

## Features / enhancements
- [ ] Companion read API: 7 read functions on `depotManager` (isActive-guarded, read-only).

## Cross-mod integration
- [ ] StateLedger: persist depot settings; drop the FSCareerMissionInfo save hook.
- [ ] NetworkSync: `DepotSync` + `DeliverySync` (consolidate the 11 event classes); remove the sendInitialClientState join handshake (getFullState replaces it).
- [ ] MasterHUD: register depot HUD draw + mouse.
- [ ] SettingsHub: register settings; keep Shift+D DepotSettingsDialog.
- [ ] SoilFertilizer read via `g_currentMission.soilFertilityManager` (detection) + `g_fillTypeManager` (stock); TaxMod consumes spend history.

## Docs / localization
- [ ] Stamp a version in modDesc.xml.
- [ ] Keep all 26 languages in step for any new setting.

## Blocked / waiting on
- [!] Bedrock migrations (waits on: adopting the four engines; SoilFertilizer is the reference pattern).
