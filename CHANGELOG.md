# Changelog

All notable changes to FS25_FertilizerDepot will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Changelog tracking for this mod begins **2026-08-22** under the suite-wide ruling
(see the ecosystem ledger, entry for Arissani and Wizard). Prior history lives in
the repo's git history and README.

---

## [Unreleased]

## [1.1.0.0] - 2026-10-12

> **This is not a final release.** It gives everyone, testers and players, new or returning, everything we have built so far, so nobody has to wait on an old version any longer. The Realistic Farming suite is far from done: we are still building and expanding every mod, and completing it could take months, possibly a year. Expect changes and rough edges along the way, and please report anything that looks wrong.

### Added
- **A new depot building:** the depot's storefront is now an industrial fertilizer production hall, with the full production machinery: every Soil & Fertilizer product can be made from its base inputs, and the hall's loading points all work.
- Bags and tanks can be ordered from a depot that holds no stock: stored litres are used first and the rest is bought in at the same price, the same as filling a trailer. Before, any order larger than the stock was refused.
- The Fertilizer Depot page on the Realistic Farming Esc menu shows the production hall's stock.

### Fixed
- The production and storage output point opens a product picker instead of loading the first product automatically, so you can choose fungicide, insecticide or any other product to load.
- Multiplayer: depot purchases, sales and orders are checked on the server and charged to the farm of the player who made them, and the result you see is the server's real result. The depot also works on a host without Network Sync.
- The depot detects Soil & Fertilizer correctly.
- Changes made in the depot's own settings dialog show in the Farm Tablet's System Settings (with Settings Hub's update).
- Translations: the depot's production parameters, products, stations, board actions, messages and its Esc page are translated into every language; garbled characters in many strings, the settings dialog's Apply button and the open-settings key are fixed; the mod's name and description read correctly in the mod manager in every language.

### Added
- Changelog file established (suite ruling 2026-08-22).
- Playtest fixes: DepotManager/Pricing/Settings/HUD, FD_HUD_DRAG (RShift+1), 26-language translation sync.
- Control Center action: FD_OPEN_SETTINGS opens depot settings from the suite Control Center (requires SettingsHub).

### Fixed
- **The depot reads in every language.** The production names (the fertilizer and its ingredients), the new fill types, the loading station names, the info-board switches and the dialog's "request could not be sent" message were English-only; in the 25 other languages the production names showed the game's "Missing" text. All are now translated. English is unchanged. (MAINTENANCE row 114.)

## [1.0.3.59] - 2026-08-22

- First entry under changelog tracking.
