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

- [x] Esc framework table freeze (Depot guest, #49, 2026-08-15): the shared 4-bay column grid is restated on every show, including the even-4-bay variant. Merged; 1.0.3.59.
- [x] NetworkSync migration: C1 bridges shipped (FDNetworkSyncBridge, dual channel DepotSync + DeliverySync). PR #20 merged to main 2026-07-28.
- [x] Depot pricing integrations (C4, 3320ecf): ProStaff discount (DepotProStaffBridge), MDM price modifier registration (DepotMarketDynamicsBridge), FuelCosts diesel read (DepotFuelCostsBridge). Committed to development 2026-07-28.
- [ ] Add the `g_currentMission.depotManager` mission handle (Point 1); keep the `Mission00.load` PREPEND hook (required for placeable registration).
- [x] MasterHUD: HUD draw bridged (69fce53); own FSBaseMission.draw stands down when active. Mouse/interact input stays on the own hook by design (MasterHUD owns draw ordering, not input).

## Mid-term (this season)
- [x] StateLedger: N/A by design (per-depot state is placeable-attached to the base-game placeable save); settings persist via SettingsHub, own FSCareerMissionInfo save kept as the fallback.
- [x] SettingsHub: `FertilizerDepot` module bridged (selfPersisted, 5 settings; commit 69fce53). Shift+D DepotSettingsDialog kept.
- [ ] Expose the 7 companion read functions on `depotManager` (TaxMod spend history, FarmTablet).
- [x] DeliveryHUD right-click keybind conflict (issue #24): Wizard build COMPLETE (dedicated unbound FD_HUD_EDIT InputAction). Pending PR to main.

## Long-term / aspirational
- [ ] Richer depot logistics (delivery scheduling, capacity tiers) without breaking the read API.

## Cross-mod / ecosystem dependencies
- [x] ProStaffCoOp: fertilizer discount read via DepotProStaffBridge (C4).
- [x] MarketDynamics: price modifier registration via DepotMarketDynamicsBridge (C4).
- [x] FuelCosts: diesel price read via DepotFuelCostsBridge (C4).
- [ ] SoilFertilizer fill-type stock integration (blocks on: `g_currentMission.soilFertilityManager` + `g_fillTypeManager`; feature confirmation).
- [x] Bedrock: ALL FOUR DONE — SettingsHub + MasterHUD (69fce53), NetworkSync C1 bridges shipped (PR #20 merged), StateLedger N/A by design.

## Deferred / parked
- Remove the `g_DepotManager` getfenv alias: parked for v2 (kept now for backward compat).
