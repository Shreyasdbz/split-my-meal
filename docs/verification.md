# iOS 27 verification

Evidence recorded on 7–8 October 2026 with Xcode 27.0 (27A266a), Swift 6, SDK 27.0 (24A430), and simulator runtime 27.0 (24A434). Version 2.0.0, build 2; minimum OS 17.4. See the [surface audit](ui-refinement.md), [paired gallery](ui-gallery.md), [validation history](refinement-validation-history.md), and [initial modernization record](verification-modernization.md).

## Current interaction refinement

[Original research and design hypotheses](interaction-research.md) inform exact draft shares, Everyone assignment, finite native amount transitions, assignment completion and the visible Share split action. Current compilation enumerates 56 stable cases: 28 unit/data/editor checks and 28 UI journeys. [Exact enumeration and selection](evidence/satisfaction-final-native-selection-provenance.json) reconcile A with 43 cases and B with 13; enumeration does not execute those cases.

The [first phone pilot](evidence/satisfaction-iphone-pilot-results.json) passed all 28 unit checks. Maintained [phone Everyone](evidence/satisfaction-iphone-final-everyone-results.json), [phone Reduce Motion](evidence/satisfaction-iphone-final-motion-results.json) and [both iPad interaction cases](evidence/satisfaction-ipad-final-interactions-results.json) passed with zero failures or skips. These runs bind source manifest `de0193…`, which predates only the final Home selection tint. They cover exact draft shares, actual native keyboard submission, Save/Cancel, invalid input and process relaunch; the motion cases cover one-cent allocation, largest text, fully visible landscape total and sharing. Native motion preferences and status-bar baselines were restored. They do not establish physical haptics, subjective satisfaction or a full-suite result on the later source.

The earlier [phone A partition](evidence/satisfaction-iphone-a-current-results.json) passed 43 cases and [phone B](evidence/satisfaction-iphone-b-current-results.json) passed 13 on different source manifests; their results cannot be combined into a same-source full-suite claim. After primary metadata styling, [two native library checks](evidence/satisfaction-iphone-library-primary-results.json) passed. The [retained complete inventory](evidence/satisfaction-iphone-library-primary-accessibility-inventory-provenance.json) contains 28 reports; the two earlier people/date contrast reports are absent. Remaining contrast, font-scaling, clipping and unidentified reports are not cleared.

The final [iPhone Demo](evidence/satisfaction-final-iphone-demo-results.json) and [iPad Demo](evidence/satisfaction-final-ipad-demo-results.json) each passed one native case with zero failures or skips on source manifest `5c4da2…`. Each produced 18 original native captures and a finalized recording. Independent design and copy review found no actionable visible finding within those captures. The active dark iPad selection now shows white text on deep teal; the primary action retains black text on mint. The [final video provenance](evidence/satisfaction-final-video-provenance.json) binds the [iPhone](evidence/satisfaction-final-iphone-walkthrough.mp4) and [iPad](evidence/satisfaction-final-ipad-walkthrough.mp4) videos to those runs.

The [final unsigned Release build and analyzer](evidence/satisfaction-release-final-provenance.json) passed on the same `5c4da2…` source. All 33 production/project hashes match, and all 12 DEBUG fixture strings are absent from the binary. The earlier failed iPad activation and input comparisons remain historical evidence; passing maintained checks do not establish their cause or global elimination. Full exact-head hosted validation of all 56 cases per device across A43/B13 remains pending.

## Historical modernization evidence

| Check | Recorded result | Evidence and scope |
| --- | --- | --- |
| Complete local iPhone suite | 53 passed; zero failures or skips | [Exact native cases](evidence/refinement-iphone-complete-results.json): 27 unit/data/editor tests and 26 UI journeys. |
| Live iPhone provider and permission flows | Five passed; zero failures or skips | [Native cases](evidence/refinement-iphone-live-results.json): real MapKit selection/Maps handoff, Allow/Deny, Settings return, revocation, cancellation and same-query Retry. |
| Live iPad provider and permission flows | Five passed; zero failures or skips | [Native cases](evidence/refinement-ipad-live-results.json): the same five checks on iPad (A16). Synthetic GPS and the single DEBUG first-error injection are explicit. |
| Dedicated walkthroughs | One passed per device; zero failures or skips | [iPhone](evidence/refinement-iphone-demo-results.json) and [iPad](evidence/refinement-ipad-demo-results.json) bind the published videos to their native cases. |
| Device Release build and analyzer | Both passed | [Source/binary provenance](evidence/refinement-release-provenance.json): unsigned SDK 27 build; all twelve DEBUG fixture strings absent. |
| Independent design, engineering and security review | No remaining actionable production findings within the reviewed boundaries | [Audit](ui-refinement.md): three design perspectives, fresh phone/iPad pixels, draft ownership, cancellation and Settings boundaries. |

Each result preserves its exact native outcomes, runtime, source hashes and warning counts. Gallery captures and recordings predate later test-helper corrections; their production hashes match the Release build. Final live checks use the same revised test inputs on both devices. The subsequent interaction-refinement slice changes production and test sources, so the historical results below do not execute or validate that newer slice. Local manifests record the parent commit and working-tree file hashes; hosted manifests record the checked-out commit and its file hashes. A current file-hash comparison establishes which inputs match, without treating an older run as execution of a newer script.

The retained complete iPad attempts include keyboard-disappearance and individual-allowance failures. The unpartitioned hosted candidate completed all 53 cases with [47 passes and six failures](evidence/refinement-ipad-candidate-ci-results.json); its phone job completed with [52 passes and one initial-launch failure](evidence/refinement-iphone-candidate-ci-results.json). These failed runs are preserved separately from successful local, focused and live checks. Passing later checks do not establish the cause or elimination of earlier failures. The [validation history](refinement-validation-history.md) also retains interrupted runs and rejected private diagnostics.

## Hosted coverage contract

The [GitHub workflow](https://github.com/Shreyasdbz/split-my-meal/actions/workflows/ios.yml) runs two fresh native partitions for each device family. Partition A contains 28 units and 15 UI journeys; B contains the remaining 13 UI journeys. Their disjoint union covers all 56 stable cases per device. This is full coverage across two native partitions. Partitioning keeps each journey’s setup, interactions and existing assertions intact.

The [explicit catalogue](../scripts/stable-test-partitions.json) is checked against Xcode’s compiled [native enumeration](https://developer.apple.com/documentation/xcode-release-notes/xcode-15-release-notes). Missing, unexpected or duplicate cases fail selection. Each native result must exactly match its selected identities with every case passed; missing cases, skips, failures and incomplete results fail verification even when a total count happens to match. Artifacts include enumeration, selection, native cases, source/fixture hashes, result bundles and logs for 14 days. Artifact names include the device, partition and checked-out commit. Check all four jobs for the exact pushed commit; a local pass or successful artifact upload does not establish hosted success.

Case limits stay four minutes, with seven minutes for three long multi-launch journeys; individual control waits and native quiescence remain unchanged. Each hosted job retains its 75-minute limit. Partitioning leaves room for native execution and evidence export without retrying failed cases. The separate system-wide diagnostics collector remains disabled after an earlier stall; native result bundles and app evidence remain retained.

## Data and interaction coverage

Native journeys cover creation, editing, both assignment directions, exact settlement/share preparation, draft cancellation and process relaunch; custom icons/categories; fixed/percentage conversion and staged Clear/Save/Cancel; actual Photos selection and replacement-pixel preservation; draft receipt zoom; library search/sort and confirmed deletion; historical invalid values/coordinates/consumers; startup recovery; Dynamic Type and rotation. Largest-text map checks require full rendered address height, useful unoccluded map area, reachable controls and foreground app identity. The denied variant opens Settings and preserves the saved restaurant on return.

The migration fixture comes from the actual 2024 app on iOS 26.5. Integration tests verify original entity hashes, stable IDs, external receipt bytes, owned-record/charge edits, reopening and the exact 1,980-cent total. [Fixture provenance](../SplitMyMealTests/Fixtures/Legacy26Fixture.bundle/PROVENANCE.md) records its origin. Failed-save tests use a real read-only store rejection; they do not simulate writable-disk I/O failure. Synthetic temporary stores remain for sandbox disposal rather than being unlinked while SwiftData may retain a connection.

## Accessibility and rendered evidence

The historical separate strict native control gate passed without exemptions for hit regions, descriptions, traits and element detection across library, meal, split and editor. The observational all-type inventories retain 31 reports on [iPhone](evidence/refinement-iphone-accessibility-inventory-provenance.json) and 37 on the [hosted candidate iPad](evidence/refinement-ipad-candidate-ci-accessibility-inventory-provenance.json), including one and ten unavailable identities respectively. Every report and exact type count remains available. Collection success and the strict control gate do not clear contrast, font-scaling, clipping or unidentified reports.

Named total, title and receipt controls have font-growth and largest-text interaction checks. The independent [diagnostic review](evidence/refinement-visual-review.json) binds earlier phone/iPad inventories to their matching native pixels; it does not clear unrelated or unidentified current reports. A specific native destructive-red sample measured 3.57:1 by default and 4.56:1 with Increase Contrast. Apple’s [contrast criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria) permit that setting path only after sufficient contrast is verified; that sample does not clear other controls or appearances. Manual spoken VoiceOver and full keyboard/pointer use remain unverified. Maintained native Reduce Motion journeys passed on both devices on the `de0193…` source described above; the final Home tint is a later presentation change. These journeys do not establish complete assistive-technology coverage.

Native input/editor transitions still emit “Invalid frame dimension (negative or non-finite).” Source review found no evidence-backed app-calculated negative dimension in the reviewed title-focus path; inspected geometry has no negative sizes, and the warning supplies no stack trace. Exact occurrence counts remain in the native results. Healthy pixels and passing interactions do not establish a harmless or framework-owned cause. The audit includes bounded unpublished diagnostic follow-ups.

The historical [gallery](ui-gallery.md) contains 80 native states that predate the current interaction-refinement slice. [Media provenance](evidence/refinement-media-provenance.json) binds unaltered screenshots to their original attachments, passing cases and source hashes. The [iPhone walkthrough](evidence/refined-iphone-walkthrough.mp4) and [iPad walkthrough](evidence/refined-ipad-walkthrough.mp4) show actual navigation, editors, split disclosures, map rotation, receipt and appearances. [Phone](evidence/refinement-iphone-video-provenance.json) and [iPad video provenance](evidence/refinement-ipad-video-provenance.json) retain original/output hashes, encoding, trim ranges, durations and inspected frame times. Setup/teardown trimming preserves interaction speed.

## Reproduction

Use Xcode 27 and dedicated simulators. The script imports two fictional receipt images once; changed or interrupted import requires a fresh dedicated simulator. Every test-host launch uses isolated local storage with CloudKit disabled.

```sh
SIMULATOR_UDID=<dedicated-iphone> SIMULATOR_OS=27.0 SIMULATOR_FAMILY=iPhone scripts/verify-ios.sh
SIMULATOR_UDID=<dedicated-ipad> SIMULATOR_OS=27.0 SIMULATOR_FAMILY=iPad scripts/verify-ios.sh
```

Select live checks or a single recording explicitly on the matching dedicated device:

```sh
export SIMULATOR_UDID=<dedicated-simulator-identifier>
scripts/verify-ios.sh -only-testing:SplitMyMealUITests/LiveMapKitTests
RECORD_DEMO_VIDEO=1 scripts/verify-ios.sh -only-testing:SplitMyMealUITests/MealJourneyTests/testDemoWalkthrough
```

## External verification boundary

Signed physical-device operation, real private-iCloud synchronization/deletion, TestFlight/App Store distribution, delivery to a sharing/support recipient and complete manual assistive-technology use remain unverified. The iOS 17.4 fallback is source-reviewed; the executed runtime is iOS 27. iPad rotation and largest-text navigation are exercised; arbitrary multitasking-window resizing remains unverified. Direct Device Hub inspection was interrupted by a locked Mac and is not counted as complete manual interaction proof. No Apple HIG or complete-accessibility certification is claimed.
