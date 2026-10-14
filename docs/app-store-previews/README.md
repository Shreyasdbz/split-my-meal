# App Store previews

Two silent 17-second previews show the completed split, item allocation and bill details using continuous native footage. Use each preview's opening frame as its poster. The files have passed local format and sampled-frame design review; they have not been uploaded or accepted by Apple.

| Device | Video | Size | Poster |
| --- | --- | --- | --- |
| iPhone with Dynamic Island, medium display | [Preview](iphone-preview.mp4) | 886 × 1920 | [Opening frame](iphone-poster.png) |
| iPad 13-inch | [Preview](ipad-preview.mp4) | 1200 × 1600 | [Opening frame](ipad-poster.png) |

Both files contain 510 decoded frames at 30 fps, H.264 High 4.0 video and no audio. The encoder targets 10 Mbps. The full native viewport is preserved: the iPhone has one black pixel at each side to fit the required width; iPad footage is uniformly scaled. There are no internal cuts, overlays or speed changes. Constant-rate sampling can repeat held source frames; it does not measure app performance or preserve the original frame count.

The iPhone uses seconds 40–57 of the [native walkthrough](../evidence/store-production3-iphone-walkthrough.mp4); iPad uses seconds 47–64 of its [walkthrough](../evidence/store-production3-ipad-walkthrough.mp4). The [manifest](manifest.json) binds source movies, output bytes, timing, poster frames and unchanged production inputs.

Two independent reviewers inspected nine two-second samples per device and additional iPhone samples. They found no blocking visual or editorial findings. The opening split result communicates the benefit without narration. The iPhone briefly reveals four items and their subtotal; its per-person tax and tip are not fully visible together. iPad secondary text is small, its native layout has generous empty space, and repeated summary states give it leisurely pacing. Full playback, exact transition dwell, assistive technology and physical-device fluidity remain unverified.

Apple's [format specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) were checked on 14 October 2026. The portrait iPad preview differs from the landscape screenshots and can appear in “A Closer Look.” Choose poster time 0 seconds in App Store Connect; the PNGs are review references, not separate video uploads. Follow [Apple's preview guidance](https://developer.apple.com/app-store/app-previews/) and verify processing before adding the assets to review.
