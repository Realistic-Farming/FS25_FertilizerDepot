# TODO: FS25_FertilizerDepot

> Ecosystem role: **Soil and Crops** · Part of the Realistic Farming connected suite
> Status: FILLED from the ecosystem audit/baseline, kept current.
> Convention: `[ ]` open · `[~]` in progress · `[x]` done · `[!]` blocked. Newest at the top of each section.

## From the ecosystem audit (Arissani)
- [ ] Add `g_currentMission.depotManager` handle; keep the `Mission00.load` PREPEND hook (do not change to APPEND).
- [ ] Remove the FSBaseMission.mouseEvent and draw hooks (same violation class as WorkplaceTriggers addModEventListener); move to MasterHUD.
- [ ] Confirm the SoilFertilizer fill-type stock feature is in scope.

## Bugs
- [ ] None flagged by the audit.

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
