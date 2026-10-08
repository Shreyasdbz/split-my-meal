# iOS 27 verification

Verified October 7–8, 2026 with Xcode 27.0 (27A266a), Swift 6, SDK 27.0 (24A430), and simulator runtime 27.0 (24A434). Version 2.0.0, build 2; minimum supported OS 17.4.

## Executed checks

| Check | Result | Evidence and scope |
| --- | --- | --- |
| Complete iPhone suite | 51 passed; zero failures or skips | [Native results](evidence/iphone-complete-results.json): 27 unit/data/editor tests and 24 UI journeys, including original-store migration, editing, assignments, charges, Photos, receipt gestures, sharing, persistence, historical repair, search/sort and large text. |
| Later iPhone presentation replay | Seven passed; zero failures or skips | [Affected journeys](evidence/iphone-presentation-results.json): editing/navigation, Cancel and native swipe dismissal, sharing/persistence, large text, diagnostic collection and strict accessibility gate after the focused iPad presentation change. |
| Complete focused iPad suite | 51 passed; zero failures or skips | [Native results](evidence/ipad-complete-results.json): all 27 unit/data/editor tests and 24 native UI journeys on iPad (A16), including the strict four-type control gate, Photos, receipt gestures, large-text editing and recovery. |
| Final localized-input replay | Seven passed; zero failures or skips | [Five units and two native journeys](evidence/localized-input-results.json): whole-string numeric parsing, locale grouping rejection, invalid-input cancellation, assignments and fixed/percentage charge conversion, Cancel and Clear. |
| Disposable store lifetime replay | 11 passed; zero failures or skips | [Storage tests](evidence/storage-test-lifetime-results.json): explicit saves remain unchanged; disposable test contexts disable autosave. The complete local log has no SQLite vnode/unlinked diagnostic. |
| Hosted timeout correction replay | Two passed on each device; zero failures or skips | [Four native checks](evidence/ci-budget-replay-results.json): complete creation/editing/sharing/persistence and historical-consumer repair with measured per-journey execution allowances. No assertions, individual control waits, retries or teardown behavior changed. |
| Live Apple Maps and permission flows | Four passed; zero failures or skips | [Provider results](evidence/live-maps-results.json): actual autocomplete/selection, settled native Maps destination, fresh Allow/Deny prompts, Settings return with draft/query intact, Never/Ask Next Time revocation and explicit retry. Coordinates are synthetic. |
| Latest device Release build and analysis | Both passed | [Source and binary provenance](evidence/release-provenance.json): unsigned SDK 27 build, current source hashes and absent DEBUG fixture/launch strings. |
| Independent engineering, security and UX review | No remaining actionable production findings within the reviewed boundaries | [Architecture](architecture.md) and [UI audit](ui-audit.md) describe reviewed invariants, native component decisions, rendered evidence and limits. Independent source review does not replace runtime or external checks. |

Each result links its exact source manifest. The complete phone run predates the focused iPad presentation; the seven-path phone replay checks the affected phone boundaries. Both presentation suites predate the final locale-grouping guard and its test extension, covered by the five-unit/two-native replay, plus the test-only autosave correction covered by the later 11-storage-test replay. The latest Release build includes all production changes. These results are source-bound local evidence rather than an assertion that every earlier suite ran again after every edit. The [failed hosted run](evidence/ci-timeout-results.json) separately retains both native summaries, three total-duration timeout failures and all reported runtime warning counts.

The migration fixture was produced by the actual 2024 app source on iOS 26.5. Tests verify original entity hashes, migrate on iOS 27, preserve stable IDs and external receipt bytes, edit all owned record types and charges, then reopen the store and verify assignments, coordinates, categories and the 1,980-cent total. [Fixture provenance](../SplitMyMealTests/Fixtures/Legacy26Fixture.bundle/PROVENANCE.md) records its origin. Failed-save tests prove rollback/restoration after an actual read-only store rejection; they do not simulate a writable-disk I/O failure.

## Accessibility and rendered evidence

The separate strict native gate audits hit regions, sufficient descriptions, traits and element detection on library, meal, split and meal editor. It passes without exclusions. The all-type diagnostic inventories contain nonzero contrast, font-scaling and clipping reports; a successful collection is not an accessibility pass. [Phone inventory provenance](evidence/iphone-accessibility-inventory-provenance.json), [iPad inventory provenance](evidence/ipad-accessibility-inventory-provenance.json) and the [UI audit](ui-audit.md) retain counts, unidentified elements, direct pixel/geometry checks and unresolved findings. Manual spoken focus order, keyboard/pointer behavior and reduced-motion traversal remain unverified.

The iPad full-window meal editor and split report use more space for in-depth editing and itemized content. The passing focused pilot verifies largest-text title editing/Cancel, reachable receipt controls and the unchanged strict accessibility gate. Regular content is centered; accessibility sizes use available width. Smaller editors retain native sheets, and the phone retains its sheet and swipe-dismiss behavior.

The first CI run also reported a disposable test database being unlinked while a SQLite connection remained open after its save/reopen assertions. Test contexts now disable background autosave because their writes are explicit. The local 11-test replay and completed follow-up CI logs contain no such diagnostic; this absence does not establish the retaining framework operation. Production never performs this test directory teardown, and the earlier warning does not establish production data loss.

Native executions retain an “Invalid frame dimension (negative or non-finite)” warning during editor input/focus. Its cause is not localized; result exports preserve occurrence counts. Healthy pixels and passing interactions are separate evidence and do not prove the warning is harmless or framework-owned.

[Media provenance](evidence/media-provenance.json) binds every published screenshot to an unaltered native attachment and tested source. The [iPhone recording](evidence/iphone-walkthrough.mp4) and [iPad recording](evidence/ipad-walkthrough.mp4) show actual native interactions, rotation and appearance changes. Only initial setup/final teardown are trimmed; playback speed is preserved. [Phone video provenance](evidence/video-provenance.json) and [iPad video provenance](evidence/ipad-video-provenance.json) retain original/output hashes, exact source ranges and encoding.

## Reproduction

Use Xcode 27 and an explicit dedicated simulator. The script imports two fictional receipt images into its Photos library once; changed or interrupted import requires a fresh dedicated simulator. Every test-host launch requires isolated local storage with CloudKit disabled. Select the matching device for each command:

```sh
SIMULATOR_UDID=<dedicated-iphone> SIMULATOR_OS=27.0 SIMULATOR_FAMILY=iPhone scripts/verify-ios.sh
SIMULATOR_UDID=<dedicated-ipad> SIMULATOR_OS=27.0 SIMULATOR_FAMILY=iPad scripts/verify-ios.sh
```

Live provider checks and a single-journey recording are selected explicitly on the dedicated device:

```sh
export SIMULATOR_UDID=<dedicated-simulator-identifier>
scripts/verify-ios.sh -only-testing:SplitMyMealUITests/LiveMapKitTests
RECORD_DEMO_VIDEO=1 scripts/verify-ios.sh -only-testing:SplitMyMealUITests/MealJourneyTests/testDemoWalkthrough
```

Output includes source/fixture hashes, checked launch arguments, toolchain/runtime metadata, native result bundles, logs and screenshot attachments. The separate Xcode system-wide diagnostics collector is disabled because it stalled after completed failures; native results and app evidence remain retained. GitHub Actions runs the complete stable suite on both device families and retains artifacts for 14 days. The [first publication run](https://github.com/Shreyasdbz/split-my-meal/actions/runs/37731810116) was superseded after exposing the disposable-store diagnostic. The [completed follow-up](https://github.com/Shreyasdbz/split-my-meal/actions/runs/37733118650) passed all 27 unit tests on each device, plus 23 phone and 22 iPad UI journeys. Creation/editing/sharing/persistence on both devices and historical-consumer repair on iPad reached the four-minute total execution allowance while continuing native interactions; the run failed and retained its artifacts. Those two long journeys now have a bounded seven-minute allowance; the default remains four minutes, the job budget remains 50 minutes, and assertions and their control-specific waits are unchanged. Check the exact latest pushed commit’s workflow result separately.

## External checks

This delivery does not establish signed physical-device behavior, real private-iCloud synchronization/deletion, TestFlight/App Store distribution, delivery to a sharing/support recipient or complete manual assistive-technology use. The iOS 17.4 fallback is source-reviewed; the executed runtime is iOS 27. iPad rotation and largest-text navigation are exercised; arbitrary multitasking-window resizing remains unverified. No Apple HIG or complete-accessibility certification is claimed.
