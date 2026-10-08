# Split My Meal

A native iPhone and iPad app for splitting meal expenses, including proportional tax and tip.

Create a meal, add everyone at the table, and enter the receipt’s items. Assign each item to the people who shared it. Add tax and tip as percentages or fixed amounts, then view or share an itemized split. Any unassigned amount stays visible, and rounded shares add up to the bill total.

The modernized app uses Swift 6, SwiftUI, SwiftData, native Liquid Glass controls on current systems, and an adaptive iPad layout. It supports restaurant search, optional nearby search, receipt photos with zoom and sharing, searchable meal history, sorting, and confirmed deletion. Existing saved data is migrated without changing stored prices or receipt formats.

## Screens and walkthrough

| Meal | Split | Dark appearance |
| --- | --- | --- |
| <img src="docs/evidence/iphone-meal-light.png" width="240" alt="Meal total, charges, and each person’s share"> | <img src="docs/evidence/iphone-split-light.png" width="240" alt="Split summary with exact total and per-person amounts"> | <img src="docs/evidence/iphone-meal-dark.png" width="240" alt="Meal detail in dark appearance"> |

Watch the native [iPhone](docs/evidence/iphone-walkthrough.mp4) and [iPad](docs/evidence/ipad-walkthrough.mp4) walkthroughs. Captures use fictional meal data. [Media provenance](docs/evidence/media-provenance.json) records their native attachments and tested source; [iPhone](docs/evidence/video-provenance.json) and [iPad video provenance](docs/evidence/ipad-video-provenance.json) record the original recording hashes, trimmed setup/teardown, and encoding.

<img src="docs/evidence/ipad-meal-landscape.png" width="760" alt="iPad landscape meal detail beside the searchable meal library">

## Build and test

Open `SplitMyMeal-Prod-A.xcodeproj` in Xcode 27, select the shared `SplitMyMeal-Prod-A` scheme, and run on an iPhone or iPad simulator. The app’s minimum deployment target is iOS 17.4; the current build uses the iOS 27 SDK. For a physical device, use an authorized signing team.

Create dedicated iPhone and iPad simulators in Xcode’s Devices and Simulators window. Before each local run, export `SIMULATOR_UDID` with that dedicated device’s identifier, available from `xcrun simctl list devices available`. Run the full unit and native UI suite:

```sh
SIMULATOR_OS=27.0 SIMULATOR_FAMILY=iPhone scripts/verify-ios.sh
SIMULATOR_OS=27.0 SIMULATOR_FAMILY=iPad scripts/verify-ios.sh
```

Local verification requires an explicit dedicated `SIMULATOR_UDID`; GitHub Actions selects a device on its fresh runner. `ARTIFACTS_DIR` and `DERIVED_DATA_DIR` choose output locations. The script keeps toolchain and runtime metadata, fixture hashes, logs, result bundles, and screenshot attachments. Tests use a separate local store with CloudKit disabled. The script checks the unit host’s native launch metadata; UI tests require and record the isolation argument before each explicit app launch. The script imports two fictional photos into the selected simulator once; reuse preserves the fixture marker, and changed photos or an interrupted import require a fresh dedicated simulator.

The GitHub workflow runs the same suite on iPhone and iPad with Xcode 27 and retains verification artifacts. See [verification](docs/verification.md), [UI review](docs/ui-audit.md), [architecture](docs/architecture.md), [privacy](misc/PrivacyPolicy.md), and [support](misc/Support.md).
