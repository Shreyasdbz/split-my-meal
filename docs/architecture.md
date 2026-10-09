# Split My Meal architecture

Updated October 8, 2026. The app is a native SwiftUI and SwiftData iPhone/iPad application, built with Xcode 27 and the iOS 27 SDK. The deployment target remains iOS 17.4. It has no third-party Swift packages or developer-operated backend.

| Boundary | Owner | Contract |
| --- | --- | --- |
| App startup | `SplitMyMeal_Prod_AApp.swift` | Opens the existing store with the migration plan; failed opens preserve data and offer retry. |
| Library and navigation | `HomeScreen.swift` | Queries saved meals; selection uses persistent identifiers and resolves against live results so external deletion cannot leave a stale detail reference. |
| Meal presentation | `MealScreen.swift` | Owns editor, map, receipt, and split presentation. The total includes any unassigned amount. |
| Editing | `MealEditor`, `ItemEditor`, `PersonEditor`, `ChargeEditor` | Value drafts stay local until Save. Cancel never writes. Destructive changes require confirmation. |
| Persistence | `MealStore.swift` | Validates context, ownership, creation intent, names, money, and assignments; explicitly saves coupled changes and restores display state after a failed write. |
| Calculations | `ComputationUtils.swift` | Converts legacy stored values to integer cents, conserves charges, and exposes invalid or unassigned values. |
| Native services | `LocationSearch.swift`, `LocationManager.swift`, `ReceiptViewer.swift` | Cancellable MapKit queries, optional one-shot location, bounded photo decoding, accessible zoom, and native sharing. |

The iPad meal editor and itemized split use focused full-window presentations for receipt/restaurant editing and detailed settlement. Regular text stays in a centered readable column; accessibility text uses the available width. Explicit Cancel/Save and Done/Share remain visible in native toolbars. Smaller editors retain sheets, and iPhone presentations remain sheets. Presentation state belongs to each window, with no global screen-size assumptions.

## Money and assignments

The item editor previews draft shares through the same stable-ID cent allocator used by the saved bill. Everyone changes only the draft consumer set and finishes price entry; Save validates and persists it, while Cancel preserves the original record. The iPad price field requests a numeric keyboard with native submit support; iPhone retains its decimal keypad. Both paths keep the same strict decimal parser and two-fractional-digit limit.

The stored schema retains its original `Double` price and tax/tip fields for compatibility. The calculation boundary converts decimal values to cents once. Fixed amounts take precedence over percentages. Tax uses the item subtotal; percentage tips use the subtotal including tax, preserving the previous app’s rule. Charge previews, mode conversions, validation, and saved calculations share the same decimal rounding helper, including half-cent boundaries.

Each item’s valid, deduplicated consumer IDs are authoritative. Both assignment editors derive their initial selections from those IDs, so a stale historical reverse index cannot erase shares during a name-only edit. Item cents are divided evenly; remaining cents go in stable person-ID order. Tax and tip use proportional largest-remainder allocation. Unassigned items retain their share of charges in an explicit unassigned balance. People’s totals plus that balance equal the bill total exactly. Invalid historical values are flagged and excluded, and split sharing is disabled until they are corrected.

An item editor initially intersects saved consumer IDs with the meal’s current people. This permits repair of hidden historical links that the calculator already ignores, without losing valid shares. Cancel preserves storage; Save canonicalizes the selected assignments. If a person is deleted while the editor is open, the persistence boundary still rejects the stale draft.

`MealStore` derives each person’s reverse item-ID index whenever an assignment changes. Person deletion removes their IDs from items; item deletion removes its IDs from people. Meal deletion explicitly deletes owned records without changing the old schema’s relationship deletion rules.

## Storage and migration

The bundle identifier and iCloud container identifier are retained. Production uses the existing default SwiftData configuration and private CloudKit integration. No iCloud account, CloudKit production schema, or App Store state is changed by local verification or a repository push.

The migration history retains the shipped unversioned schema as V1 and corrects the restaurant inverse relationship in V2. Stored field names, types, optionality, category raw values, and external receipt storage are retained. The historical `lattitude` spelling is intentionally preserved as a stored field.

Restaurant maps validate historical coordinates before creating a camera, marker, or Maps handoff. Invalid coordinates show a recovery screen and retain the saved restaurant until the user replaces or removes it through the meal editor.

Restaurant text search requires no location permission. An explicit nearby request starts one location lookup. A denied request offers a native app Settings link; restricted access keeps text search available without promising a permission change. Denial, revocation, or returning to Ask Next Time clears the cached coordinate and nearby bias. An initial permission prompt is tracked separately from an active GPS lookup; granting access starts GPS only for an explicit outstanding request. Delayed results are checked against current authorization before acceptance. The query and meal draft remain in place during the Settings handoff.

Failed writes call rollback once and restore a snapshot of the affected meal’s graph. This is necessary because older SwiftData versions can clear pending writes without refreshing already-held model values. Restored baseline values can remain pending on those runtimes; a subsequent save persists the original baseline, and a second rollback would discard its restoration. Editors retain their draft and show the error rather than dismissing with apparent success. Tests exercise a native read-only save rejection, verify the held graph and reopened disk baseline, and verify a successful retry through a writable context.

Debug UI tests use a separate `SplitMyMeal-UITesting.store`, disable CloudKit, and generate fictional receipt fixtures. Reset and demo arguments are absent from release behavior. The verification script imports only those fictional photos into its selected simulator.

## Release boundary

Local verification uses simulator unit and UI tests, rendered screenshot review, recorded interactions, and an unsigned device Release build with Xcode analysis. A signed physical-device build, real private-iCloud synchronization, TestFlight distribution, and App Store submission are separate external checks.
