# Roadmap: FS25_FertilizerDepot

> Ecosystem role: **Soil and Crops** · Part of the Realistic Farming connected suite
> Status: FILLED from the ecosystem audit/baseline.
> Forward-looking only. Shipped history lives in CHANGELOG.md and the releases.

## How to use this file
- Populate the milestones below from the audit baseline once it lands.
- Each item should be small enough to map to a `TODO.md` entry.
- Keep it honest: near-term is committed, mid-term is intended, long-term is aspirational.

## Current baseline
- Version at baseline: not stamped in source (confirm/stamp modDesc.xml)
- Audit reference: ecosystem-dev-tracking Point 1-5 (FS25_FertilizerDepot, 2026-06-30)
- Baseline date: 2026-06-30

## Near-term (next release cycle)
- [ ] Add the `g_currentMission.depotManager` mission handle (Point 1); keep the `Mission00.load` PREPEND hook (required for placeable registration).
- [ ] NetworkSync: consolidate the 11 custom event classes to two channels, `DepotSync` + `DeliverySync`, to keep delta payloads manageable.
- [ ] MasterHUD: remove the FSBaseMission.draw AND mouseEvent hooks; register the depot HUD draw + mouse through MasterHUD.

## Mid-term (this season)
- [ ] StateLedger: persist depot settings; remove the FSCareerMissionInfo save hook.
- [ ] SettingsHub: register settings; keep the Shift+D DepotSettingsDialog (correct pattern).
- [ ] Expose the 7 companion read functions on `depotManager` (TaxMod spend history, FarmTablet).

## Long-term / aspirational
- [ ] Richer depot logistics (delivery scheduling, capacity tiers) without breaking the read API.

## Cross-mod / ecosystem dependencies
- [ ] SoilFertilizer fill-type stock integration (blocks on: `g_currentMission.soilFertilityManager` + `g_fillTypeManager`; feature confirmation).
- [ ] All four bedrock migrations (blocks on: StateLedger, NetworkSync, MasterHUD, SettingsHub).

## Deferred / parked
- Remove the `g_DepotManager` getfenv alias: parked for v2 (kept now for backward compat).
