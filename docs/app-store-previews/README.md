# App Store previews

Two silent 17-second previews show the completed split, item allocation and bill details using continuous native footage. Use each preview's opening frame as its poster. The corrected files have passed local video/audio checks, retain the reviewed visuals and now load from Apple. Opening posters have been saved; final poster generation/readback is pending.

| Device | Video | Size | Poster |
| --- | --- | --- | --- |
| iPhone with Dynamic Island, medium display | [Preview](iphone-preview.mp4) | 886 × 1920 | [Opening frame](iphone-poster.png) |
| iPad 13-inch | [Preview](ipad-preview.mp4) | 1200 × 1600 | [Opening frame](ipad-poster.png) |

Both files contain 510 decoded video frames at 30 fps, H.264 High 4.0 video and an enabled silent stereo AAC track at 48 kHz (requested 256 kbps). The video encoder targets 10 Mbps. The full native viewport is preserved: the iPhone has one black pixel at each side to fit the required width; iPad footage is uniformly scaled. There are no internal cuts, overlays or speed changes. Constant-rate sampling can repeat held source frames; it does not measure app performance or preserve the original frame count.

The iPhone uses seconds 40–57 of the [native walkthrough](../evidence/store-production3-iphone-walkthrough.mp4); iPad uses seconds 47–64 of its [walkthrough](../evidence/store-production3-ipad-walkthrough.mp4). The [manifest](manifest.json) binds source movies, output bytes, timing, poster frames and unchanged production inputs.

Two independent reviewers inspected nine two-second samples per device and additional iPhone samples. They found no blocking visual or editorial findings. The opening split result communicates the benefit without narration. The iPhone briefly reveals four items and their subtotal; its per-person tax and tip are not fully visible together. iPad secondary text is small, its native layout has generous empty space, and repeated summary states give it leisurely pacing. Both Apple-hosted previews were separately played to the end with no media error. Continuous visual review, exact transition dwell, assistive technology and physical-device fluidity remain unverified.

Apple's [format specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) were checked on 14 October 2026. The portrait iPad preview differs from the landscape screenshots and can appear in “A Closer Look.” Poster time 0 seconds has been selected and saved in App Store Connect; the PNGs are review references, not separate video uploads. The version passed its final completeness check and is Ready for Review. Apple is still generating the saved poster frames; verify those images before final submission. Follow [Apple's preview guidance](https://developer.apple.com/app-store/app-previews/).

The [first video-only uploads](../evidence/app-store-preview-first-upload-failure.json) returned Apple’s generic save error and had no playable source. They omitted the specified audio track. The [AAC correction proof](../evidence/app-store-preview-aac-repair-proof.json) verifies every compressed video sample and timestamp is unchanged, plus 816,000 exactly silent decoded audio frames. The audio track reports 16.956 seconds while the movie remains 17 seconds; no complete audio-boundary equivalence or proven cause for the initial error is claimed.
