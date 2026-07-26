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
- [!] NetworkSync: consolidate the 11 custom event classes. DEFERRED, bundled with the NPCFavor money-authority session (a hardened request/response protocol that pays money server-side, not a mechanical swap). Needs the NS build-brief.
- [~] MasterHUD: HUD draw bridged (69fce53); own FSBaseMission.draw stands down when active. Mouse/interact input stays on the own hook by design (MasterHUD owns draw ordering, not input).

## Mid-term (this season)
- [x] StateLedger: N/A by design (per-depot state is placeable-attached to the base-game placeable save); settings persist via SettingsHub, own FSCareerMissionInfo save kept as the fallback.
- [x] SettingsHub: `FertilizerDepot` module bridged (selfPersisted, 5 settings; commit 69fce53). Shift+D DepotSettingsDialog kept.
- [ ] Expose the 7 companion read functions on `depotManager` (TaxMod spend history, FarmTablet).
- [!] DeliveryHUD right-click keybind conflict (issue #24): raw right-click for edit mode fires during vehicle tool actions. Design decision needed: dedicated InputAction (default UNBOUND) vs modifier combo. See ecosystem ledger 2026-07-26. Wizard ready to build once approved.

## Long-term / aspirational
- [ ] Richer depot logistics (delivery scheduling, capacity tiers) without breaking the read API.

## Cross-mod / ecosystem dependencies
- [ ] SoilFertilizer fill-type stock integration (blocks on: `g_currentMission.soilFertilityManager` + `g_fillTypeManager`; feature confirmation).
- [~] Bedrock: SettingsHub + MasterHUD DONE (69fce53); StateLedger N/A by design; NetworkSync deferred (money-authority class, needs the NS build-brief).

## Deferred / parked
- Remove the `g_DepotManager` getfenv alias: parked for v2 (kept now for backward compat).
