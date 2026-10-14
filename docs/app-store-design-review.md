# App Store screenshot review · 14 October 2026

Two independent visual reviewers inspected all ten final originals, the 297-pixel iPhone and 560-pixel iPad previews, the contact sheet, and the existing five iPhone and five iPad screenshots from version 1.0.1. Both accepted the final set with no blocking visible finding. Their assessment is that it meets the previous set's overall presentation quality; this is design judgment, not measured user preference or App Store approval.

The [gallery](app-store-assets/README.md) leads with the completed split, then explains shared items, tax and tip, receipt storage, and history. The five headlines use 18 words, compared with 31 in the previous family. The warm neutral canvas, emerald headings, consistent single-screen framing and restrained shadows create a clearer hierarchy. Every poster preserves a complete native screen; the interface is neither reconstructed nor stretched.

| Poster | Visible support for the claim |
| --- | --- |
| See everyone’s share | Total $113.66, three individual shares and Share split |
| Choose who shared each item | Three selected people, $9 divided into $3 portions, and Save |
| Include tax and tip | Subtotal, tax, tip and View split |
| Keep the receipt | Six item rows and a matching $113.66 total; native controls remain visible |
| Find past meals | Three distinct saved meals; iPad also shows the selected meal |

The receipt poster uses the native iPad viewer at 200% zoom with pan, resolving the earlier concern that its content was too small. Remaining composition tradeoffs are small secondary iPad text at thumbnail size and similar detail views in posters 3 and 5. The new sequence does not retain the previous dedicated category and restaurant-location headlines. Both reviewers judged the simpler five-poster story sufficient; these tradeoffs do not imply uniformly better fine-text legibility.

[The composition manifest](app-store-assets/manifest.json), SHA-256 `58093fa5640d63009b4b61e23cdfc9c86a8dcc3afa07061eb5f316ff24def2ff`, binds all ten posters to their exact native captures and the same frozen 50-input source. All 23 generated files reproduced byte for byte. Dimensions, opaque 8-bit RGB output and sRGB profiles were checked separately from visual acceptance.

## Native readability review

Independent review of final native pixels confirms that the previously weak form headings and destructive labels are readable in the sampled light and dark states. Ratios use the screenshot's foreground core colors and adjacent background, not antialiased edge pixels.

| Captured label | Foreground RGB | Background RGB | Contrast |
| --- | --- | --- | ---: |
| People, light | 67, 67, 69 | 242, 242, 247 | 8.846:1 |
| People, dark | 184, 184, 184 | 0, 0, 0 | 10.586:1 |
| Delete meal, light | 180, 35, 43 | 255, 255, 255 | 6.530:1 |
| Delete meal, dark | 255, 143, 147 | 44, 44, 46 | 6.373:1 |

The earlier light samples measured 3.287:1 for the heading and 3.570:1 for destructive text. [Original final captures and hashes](evidence/app-store-final-readability/manifest.json) preserve the measured states. The native tests verify editing, control reachability and cancellation independently of these contrast measurements.

At the largest accessibility text size, “Alex, Jordan, Sam” wraps completely on iPhone and in the same 320-point iPad sidebar that previously clipped the names. Recorded participant text height grows from 18 to 116.67 points on iPhone and from 18 to 174.5 points on both iPads. Title, amount and receipt controls also grow. The iPad native toolbar still abbreviates “Meals” at this size; the repaired participant list remains complete.

These observations cover the recorded states. They do not clear every native audit report or establish physical-device VoiceOver, Switch Control or accessibility conformance. The final iPad inventory retains 23 observational reports, including eight unavailable element identities; optional App Store accessibility labels remain unpublished.
