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

## 2026-10-04 (Fred): the shared RF Esc door at the suite's STOCK page set (Wizard, #86)

- [x] The four shared Esc door files (`xml/gui/RfPdaMenuPage.xml`, `src/gui/RfPdaMenuPage.lua`, `src/gui/RfEscModules.lua`, `xml/gui/rfEscProfiles.xml`) are at the set every door mod carries, byte-same in all ten (Wizard's STOCK page chain build, #86, merged at 038c305d): wider sheet cells, the explanation band at up to four lines, the ids and callbacks StockGuard's STOCK page uses (inert without StockGuard), the hidden ids and profiles of DairyCore's herd-advisory panel, ProStaff in the closed-module list, and Soil Fertilizer's AUTO target card kept.
- The door's in-game check is TESTING row 413. Docs by Fred's catch-up, on Tyson's word of 2026-10-04.

## 2026-10-05 (Fred): the Esc side panel's info box clear of the selected tab (Wizard, #88)

- [x] The shared Esc door file `xml/gui/RfPdaMenuPage.xml`, byte-same in all ten door mods (Wizard, #88, merged at 8b4b761c): the side info boxes (`rfSideInfoShell`, `wcSideInfoShell`, `mdSideInfoShell`, `csSideInfoShell`) take an explicit position and size, 16 px further right and 16 px narrower (384 to 368 px), so the dark box starts clear of the selected tab's lime edge and its right edge stays where it was. The side text bodies narrow by the same 16 px, to 352 px (the main side text, from 368) and 348 px (the Worker Costs and Market Dynamics side help, from 364), so the text starts 16 px further right and each line ends where it did.
- The change's in-game check is TESTING row 446. Docs by Fred's catch-up, on Tyson's word of 2026-10-05.

## 2026-10-06 (Fred): the settings dialog's Apply button and the open-settings key readable in Japanese, Korean, Russian and Ukrainian (MAINTENANCE row 220)

- [x] Six translation values (`fd_settings_apply` in jp, kr and uk; `input_FD_OPEN_SETTINGS` in jp, ru and uk) had been saved through the Windows cp1252 code page since 287c7de4 (2026-07-28), so those players saw garbled text on the Apply button and the key binding. Each is restored to the exact text its key was created with (380e626 and 94303bc). The Ukrainian Apply had lost a byte in a later dash fix, so it is taken from that source, not decoded; it matches the decode of 287c7de4. Row 62's count missed these six because a strict cp1252 round trip rejects the byte cp1252 leaves undefined. No other value changes.

## 2026-10-06 (Fred): the mod's title and description readable again in every language (MAINTENANCE row 227)

- [x] 42 lines of the title and description in `modDesc.xml` (lines 8 to 74) had been damaged in one commit, 06ea086 (2026-08-08), and again by a later re-encoding: the text was read through the DOS cp850 code page and saved as cp1252, which turned some letters into '+' or '-' and others into bytes that later became U+FFFD, and the result was then double encoded. 39 of the lines showed garbled characters; three (German lines 8 and 50, Turkish line 22) had lost their letters to plain '+' signs ("D++ngerdepot"). Each line is restored from f437e84 (2026-07-28), the last commit before the damage. Replaying the two damage steps on f437e84 reproduces all 68 lines from 7 to 74 at development exactly, so the restore is exact. The English description's one em dash is written as a spaced hyphen. No other line changes, and the version line stays.

## 2026-10-08 (Fred): the depot sees Soil & Fertilizer in a game (MAINTENANCE row 252)

- [x] `SoilFertilizerBridge:isInstalled` read the bare global `g_SoilFertilityManager`, which Soil sets only in its own mod environment, so the depot logged "SF installed: false" with Soil loaded. It now reads `g_currentMission.soilFertilityManager` first, as the depot's other bridges read theirs. Design origin none (the line is from the first scaffold).
- The in-game check is TESTING row 512.
