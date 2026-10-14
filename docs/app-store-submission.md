# App Store submission preparation

Prepared on 13 October 2026 for Split My Meal, App Store Connect app 6575395076, version 2.0.0, build 2. The draft is configured for manual release. Preparing the draft does not submit it for review or release it.

Apple's completeness validation passed: the version is Ready for Review, and its draft submission says Item Ready to Submit with the final Submit for Review action available. [The captured draft](evidence/app-store-ready-draft.png), [iPhone gallery](evidence/app-store-ready-iphone-gallery.png) and [iPad gallery](evidence/app-store-ready-ipad-gallery.png) show the saved provider state. Submit for Review has not been clicked.

## Build and product page

The Release archive and static analysis succeeded. The App Store export passed signature verification and contains production CloudKit/push entitlements, no development debugging entitlement, the privacy manifest, and the non-exempt-encryption declaration. Apple accepted the upload, processed build 2 to Ready to Submit, and the build is selected in the version draft. The local exported IPA hash identifies the inspected export; it does not claim byte identity with Apple's processed upload.

[Store copy](app-store-metadata.json) records the saved English (U.S.) name, subtitle, description, keywords, release notes, support/privacy URLs and review instructions. Existing review contacts, pricing, availability, license and trader status are preserved; private contact details are excluded from this repository. The published privacy disclosure remains Data Not Collected. Optional accessibility labels remain unpublished because complete device/assistive-technology verification has not been established.

The age-rating questionnaire records infrequent alcohol references for the selectable champagne charm and no other applicable content categories: 13+ on current systems and 12+ on older systems. The privacy and support pages were verified publicly reachable without account authentication. Privacy and Support are also reachable from Help in the meal library.

## Screenshots and design review

The [ten store posters](app-store-assets/README.md) use real native captures and fictional meal data. They lead with the split result, then explain shared-item assignment, tax/tip, receipt storage and history. Five 1206 × 2622 iPhone posters and five 2752 × 2064 iPad posters were uploaded in that order. Legacy placements in the new version draft are removed where they override the new gallery; the published version and Asset Library are preserved.

Two independent visual reviewers compared the originals, small previews and the five existing store screenshots. The final set has no blocking visual findings. Review identified shorter concrete headlines, stronger hierarchy and cleaner single-screen framing. Detailed iPad form text remains small at thumbnail scale; the tax/tip and history posters share similar detail views. These are composition tradeoffs, not evidence of universally better legibility or user preference approval. The iPad receipt was recaptured using native 200% zoom and pan so the restaurant header, six item rows and total remain visible.

[Capture and composition manifests](app-store-assets/manifest.json) bind each uploaded poster to exact native source and file hashes. Nine captures use the initial frozen source; the final iPad receipt uses a second source manifest whose only difference is the UI test's capture sequence. All production source hashes match the signed archive. The renderer reproduces all 24 generated files byte for byte on the recorded local system.

## CloudKit and verification

Production CloudKit initially contained only Users. The reviewed development schema was deployed and production readback confirmed CD_Meal, CD_MealItem, CD_MealPerson and CD_RestaurantDetails, with 78 indexes. An independent security review checked the schema permissions against the application's private-database usage. No user records were queried, imported or deleted. Schema deployment does not prove end-to-end private iCloud synchronization.

The maintained storefront capture case passed on the dedicated iPhone 17 and iPad Pro 13-inch simulators; the refined iPad receipt capture passed again. It verifies totals, equal shared-item previews, cancellation without persistence, saved history, receipt controls and the native Help links. The stable catalogue contains 57 cases per device family, partitioned 44/13. The [native proof](evidence/app-store-native-proof.json) records the actual local capture, archive and export evidence. Fresh full-suite hosted verification runs after publication through the [iOS verification workflow](https://github.com/Shreyasdbz/split-my-meal/actions/workflows/ios.yml); the final delivery report identifies the actual completed run and outcome rather than treating queued work as passed.

Physical-device behavior, actual VoiceOver/Switch Control use, haptics and private-account iCloud synchronization remain unverified. The paired iPhone's connection is unavailable and Developer Mode is disabled; no device permissions were changed. Simulator evidence, provider build processing and static visual review do not establish App Review approval.

## Apple references

- [Screenshot sizes](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [uploading screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/).
- [Submission workflow](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review/), [privacy disclosures](https://developer.apple.com/app-store/app-privacy-details/) and [encryption declaration](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations).
- [Age ratings](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions) and [accessibility labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels).
- [CloudKit schema deployment](https://developer.apple.com/documentation/CloudKit/deploying-an-icloud-container-s-schema).
