# UI refinement · 8 October 2026

This follow-up reviews the modernized app against the request for cleaner surfaces, tighter copy and a more native flow. Three independent agents reviewed it from iOS visual design, native interaction/accessibility and product/copy perspectives. Two designers then inspected fresh iPhone and iPad captures; independent engineering and security reviewers checked the changed state and asynchronous boundaries. Source review, inspected pixels and executed interactions are distinct evidence. The [initial modernization audit](ui-audit.md) remains a historical record.

## Native controls and hierarchy

The extra panel behind **View split** came from an app-owned `.background(.bar)` around the already prominent native button. On current systems the refinement uses `safeAreaBar` with the native soft scroll-edge treatment, without that extra panel. The action stays centered and capped at 440 points on wider layouts. Older systems retain their standard bar fallback. This follows Apple's [Liquid Glass adoption guidance](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) and [safe-area bar API](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)); it is not a claim of Apple certification.

The split now presents the total and each person's amount before optional **Bill details**. Invalid and unassigned amounts stay visible outside the collapsed details. Native disclosures retain item portions and the exact calculation explanation. Quiet chevrons identify editable meal rows without adding separate buttons or duplicating their accessibility names. Forms, navigation, Photos, menus, confirmations, MapKit and sharing retain native components.

## Historical refinement flow inventory

This inventory records the earlier refinement; its verification column does not certify the subsequent interaction slice.

| Surface and flows | Refinement or retained behavior | Verification boundary |
| --- | --- | --- |
| Startup loading, storage failure, retry and support | Short retained-data message; technical failure moves into Error details. Retry never discards the store. | Recovery journey expands and collapses the exact injected error before retry. Original-store migration remains covered by integration tests. |
| Library empty/new/open, search/no results/clear, sort and deletion | Empty state retains only its title and New meal. Search meals replaces the long prompt; title/restaurant/person matching remains. | Native library, search/sort, creation/cancellation and deletion journeys; light/dark and largest-text captures. |
| Compact navigation and iPad sidebar/detail | Native navigation and focused iPad editor/split presentations remain. Empty detail uses Select a meal without repeated instructions. | Native phone/iPad journeys and landscape captures; no navigation framework replacement. |
| Meal total, subtotal, tax and tip | Primary action loses the extra panel. Editable charge rows gain quiet disclosure cues. Permanent calculation prose moves to the relevant editor and Bill details. | Normal/dark/landscape pixels, charge conversion and persistence journeys, strict control gate. |
| People and item rows, add/edit/delete and both assignment directions | Edit cues clarify row actions. Empty sections retain the Add action without a second instructional row. | Creation/editing, reverse assignment, assigned-person deletion and historical consumer repair. |
| Invalid and unassigned balances | Short actionable warnings remain visible on meal and split; invalid sharing remains disabled. | Native historical repair and deletion-to-unassigned journeys; exact cent conservation and validation units. |
| Meal title, preset/custom icon, Save/Cancel/swipe and delete | Custom emoji becomes optional native disclosure, initially open for saved custom/invalid values. Photo actions shorten to Add photo/Replace photo while retaining full accessible names. Deletion identifies all affected data. | Native custom icon/category persistence, invalid reset, draft cancellation and large-text editor journeys. |
| Person name and item selection | Item price explicitly identifies the full item cost. Empty copy points to the meal's Items flow. | Both assignment directions and persistence; normal/large-text editor captures. |
| Item name, price, category and people selection | Unassigned and equally-shared guidance is conditional; empty copy identifies where to add people. | Invalid input, localized parsing, category/consumer editing and stale-record integration checks. |
| Tax/tip percentage and amount modes, conversion, Clear/Save/Cancel | Duplicate charge heading removed. Only percentage mode shows its base. Clear changes the draft; Save commits it and Cancel preserves storage. Typing a replacement removes the clear intent. | Native fixed/percentage conversion, Clear/Cancel/typing/mode-switch/Save/relaunch checks; no immediate write on Clear. |
| Receipt add/replace/loading/remove and draft preview | Tapping the complete preview row opens the draft photo for zoom without saving it. Cancel preserves the original photo. Unavailable-photo recovery uses one short sentence. | Real native Photos selection, distinct replacement pixels, draft zoom, Close, Cancel and process-relaunch comparisons. |
| Receipt fit/zoom/pinch/double tap/rotation/Share/Close | Working-image controls remain; unreadable images no longer display a false 100% readout or inactive zoom tools. | Native receipt gestures, sharing and unreadable repair journeys. External recipient delivery remains unverified. |
| Restaurant search, suggestions, exact selection, error/Retry/Cancel | Search instructions shortened. Retry restarts the same query after canceling prior resolution/search work. Use my location accurately describes optional query bias. | Live test injects only the first error, then retries against real MapKit. DEBUG fixture is absent from Release. Existing live permission/revocation journeys remain. |
| Nearby permission, denial, Settings return and revocation | Explicit opt-in, denied-only Settings recovery and permission-free text search remain. | Native live Allow/Deny, retained query/draft, Never/Ask Next Time and explicit new-request checks use synthetic location. Managed restriction remains source-reviewed. |
| Restaurant map, address, Open in Maps, current location, error/Settings and Done | Open in Maps is primary; location is secondary with visible progress. Compact-height layouts put the map beside scrolling details. Accessibility text in regular-height layouts reserves map space above scrolling details. Denied access offers a secondary Open Settings link. | Native provider destination and Settings return, largest-text normal/denied portrait/landscape map checks, normal-map walkthrough captures. |
| Split total, warnings, people disclosures, item portions, Bill details, Share and Done | Settlement amounts come first; breakdown and calculation explanation expand on demand. Full item prices and shared-person counts are explicit. | Exact amounts/export unchanged; native collapsed/expanded, Share and largest-text reachability checks. |
| Light/dark, landscape, Dynamic Type, semantics and keyboard | Semantic fonts, adaptive amount rows, native focus/submit and accessible action names remain. Decorations stay subordinate to content. | Fresh pixels and native control/font/layout gates. Manual spoken VoiceOver, full keyboard/pointer and reduced-motion gesture use remain separate checks. |

## Historical rendered captures

The earlier refinement’s 80-capture [paired iPhone and iPad gallery](ui-gallery.md) covers meal/split, all editors, empty and validation states, receipt preview, startup recovery, largest text and normal/denied maps. Screenshots preserve native pixels and orientation metadata. Each capture belongs to an individually passing native case; complete-suite outcomes remain separate in verification. The [independent review record](evidence/refinement-visual-review.json) binds three design perspectives and fresh original-pixel reviews to exact captures; manual assistive-technology and arbitrary iPad window resizing remain separate.

## Copy decisions

| Earlier copy | Current copy and context |
| --- | --- |
| Add receipt photo / Replace receipt photo | Add photo / Replace photo under Receipt; full receipt wording remains in accessibility names. |
| Meals, restaurants, or people | Search meals; matching behavior unchanged. |
| Percentage tip uses the subtotal including tax. | Applied to subtotal plus tax. Only shown in Percentage mode. |
| This saved photo couldn't be opened. Replace or remove it. | Photo unavailable. Replace or remove it. |
| No restaurants found. Try a name, address, or city. | No results. Try another name, address or city. |
| Search near me / Nearby search enabled | Use my location / Using your location. |

The app keeps actionable warnings and destructive consequences. It removes repeated instructions and makes secondary detail optional; monetary calculation, stored values, CloudKit identity and export behavior remain unchanged.

## Validation and limitations

Native pilots exposed and corrected disclosure identity, receipt-preview hit testing, map viewport/address layout and scrolled navigation overlap. Recovery checks now require the foreground app, fully visible actions and preserved state. The [validation history](refinement-validation-history.md) retains failed, interrupted and focused attempts, including the iPad native animation waits and the phone recovery-row targeting defect; none count as final full-suite passes.

Historical refinement evidence records 53 passing local phone cases, five passing live-provider/permission cases per device, and the 80-capture gallery. Retained iPad and hosted attempts also include failures; the validation history preserves their exact outcomes. Those results belong to their recorded sources and do not certify the subsequent interaction changes.

The historical unsigned device Release build and analyzer passed; [Release provenance](evidence/refinement-release-provenance.json) identifies that binary and its production sources.

The current interaction slice enumerates 56 native cases, partitioned as 43 in A and 13 in B; enumeration establishes selection coverage, not execution. The first phone pilot passed 28 units. Maintained [phone Everyone](evidence/satisfaction-iphone-final-everyone-results.json), [phone Reduce Motion](evidence/satisfaction-iphone-final-motion-results.json) and [both iPad interaction cases](evidence/satisfaction-ipad-final-interactions-results.json) passed with zero failures or skips on `de0193…`, before the final Home selection tint. Those checks retain exact values, native keyboard submission, cancellation, saving, relaunch and native preference restoration. Earlier failed activation/input comparisons remain in the history without a cause or elimination claim.

The final [iPhone Demo](evidence/satisfaction-final-iphone-demo-results.json) and [iPad Demo](evidence/satisfaction-final-ipad-demo-results.json) each passed one native case on `5c4da2…`, with 18 original captures per device. Independent design and copy review found no actionable visible findings within the reviewed captures. The selected dark iPad row uses white text on deep teal; the primary action remains black on mint. [Final media provenance](evidence/satisfaction-final-media-provenance.json) binds the [iPhone](evidence/satisfaction-final-iphone-walkthrough.mp4) and [iPad](evidence/satisfaction-final-ipad-walkthrough.mp4) recordings. The [unsigned Release build and analyzer](evidence/satisfaction-release-final-provenance.json) passed on that same source, with all 12 DEBUG fixture strings absent.

Two [native library checks](evidence/satisfaction-iphone-library-primary-results.json) passed after the primary metadata correction. The [complete inventory](evidence/satisfaction-iphone-library-primary-accessibility-inventory-provenance.json) retains 28 reports; the earlier people/date contrast reports are absent, while remaining reports are still available for review. Full hosted acceptance requires all 56 exact case identities per device on the pushed head; local evidence does not establish that outcome. [Verification](verification.md) separates historical, focused, media and Release proof.

Automated accessibility diagnostics are retained without blanket exclusions. Passing the separate control gate does not clear contrast, font-scaling, clipping or unidentified-element reports. Screenshots do not establish complete accessibility. Signed physical-device operation, real CloudKit synchronization/deletion and manual assistive-technology use remain unverified.

## Unpublished diagnostic follow-ups

The repository had no existing issues when refreshed on 8 October 2026. These bounded maintenance drafts remain unpublished; no GitHub Project was designated for this audit.

- **Task: reconcile native accessibility diagnostics.** Retained all-type inventories report contrast, font-scaling, clipping and unidentified elements. Their presence prevents a complete-accessibility claim. Acceptance: trace each current report to its visible element or document the missing identity, reproduce at the reported text size and appearance, repair any confirmed app-owned defect, and retain the original report alongside the new native result. Manual spoken navigation and keyboard/pointer checks remain separate.
- **Task: localize the native invalid-frame warning.** Native editor/input runs emit “Invalid frame dimension (negative or non-finite)”; the source is not established. Acceptance: isolate the triggering native transition with a stack trace or rendering diagnostic, identify the responsible boundary, and verify an in-scope correction through the same interaction without suppressing the warning. Healthy captures and passing tests do not determine its cause.

The [research-informed interaction changes](interaction-research.md) add Everyone as a draft shortcut, exact item-share previews before tax and tip, finite native amount changes with Reduce Motion support, All items assigned as allocation completion, and visible Share split. Neither the research nor simulator evidence demonstrates a causal satisfaction gain.
