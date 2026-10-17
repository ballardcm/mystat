# Memory footprint changes and pre-signing qualification

This report records the first sampler/meter candidate. The later [Core Graphics chart qualification](2026-10-17-core-graphics-charts.md) supersedes its executable identity and adds the completed dashboard-memory comparison and one-hour soak.

Prepared with substantial OpenAI Codex assistance on 2026-10-17.

## Candidate identity

Branch `perf/reduce-sampling-memory`, based on `01d8036b0126d8606f5bb64a5e259b6abd79824a`. The tested source was uncommitted; the following SHA-256 hashes identify every changed source/test/build-script file relative to that base. No app source changed after the final candidate was built and visually qualified.

| File | SHA-256 |
| --- | --- |
| Sources/MyStat/AppDelegate.swift | `0e705e838e0377b97fdfd3265a44e5098a96aeddf01838cc726b290bfc2b6055` |
| Sources/MyStat/Dashboard.swift | `611a3030744f43ba7a6c00533d316d3cd784c6b9d7108ec714e3fe6b76a82077` |
| Sources/MyStat/MenuBarMeter.swift | `2778426d03131cf78c4ddb96771bdca825f8326b016180c5454ead8354e25c64` |
| Sources/MyStat/Metrics.swift | `f88c956c2808d33cf8c4d620e2d98f61c31c45776e29c84ace847c46bd3f1e1e` |
| Tests/MenuBarMeterTests.swift | `9d067384448301b1203b2ebaf35198ea09117ebd6ca6199d7fe0aec45a1c896d` |
| Tests/MetricsTests.swift | `8aeb8a8462b24b04cb460398027b34a69233da035a1512348af9ff6a054c71c1` |
| scripts/test.sh | `eb034e2b95edac14831402123f65b7591021ea38b000d468885fafa35f4a9ff6` |

Built with Xcode 27.1 (27A9275), macOS SDK 27.0, using `scripts/release.sh --adhoc`. Xcode is now the system-selected developer directory at `/Applications/Xcode.app/Contents/Developer`. The prior Command Line Tools installation lacked the SwiftUI macro plugin; full Xcode resolved that build blocker.

Test-only candidate retains version 0.2.1, build 6; it is not a published release. Final executable SHA-256: `71ca125c7e56612a45cefc8a7e58f58b66217b5c580024a8d0fe916d15710d5d`. Final ad-hoc ZIP SHA-256: `f66a5db49be77d579edbc6fdb46705cd733619a87524c5f77d84d00545efc2b0`. Both guests ran the same extracted candidate, with its executable hash checked against this value and its running path checked to exclude the installed release.

## Changes and automated checks

- Reuse one reader-owned Mach host send right and release it when the reader is destroyed.
- Keep only scalar battery readings in the existing ten-second cache, preserving signed-current conversion and SMC fallback.
- Drain temporary Foundation objects in an autorelease pool around each sample.
- Reuse a single cached menu-bar image when displayed strings are unchanged; replace the button image only when its identity changes.
- Correct the information panel's obsolete target-policy text: macOS 27 is primary, macOS 26 remains supported, and macOS 27 power mappings remain experimental.

The complete test suite passed with Xcode 27.1, including battery conversion/lifetime tests, repeated-reader Mach-right ownership checks, cache identity/eviction tests, and the existing meter layout/raster cases. Regression binaries also passed on macOS 26.6. The real Sparkle integration suite passed archive/feed rejection, defer/cancel/error paths, install/relaunch, and preference preservation. That integration pass preceded only the information-panel text correction; the final ad-hoc build reran the full normal suite after that correction.

## Performance and hardware smoke observations

An interleaved same-process sampler comparison used 70 pairs, discarding ten warm-up pairs. Mean CPU time was 3.884 ms before and 3.805 ms after; median was 3.995 ms in both cases. Mean wall time was 18.385 ms before and 18.345 ms after; p95 was 19.979 ms before and 20.012 ms after. No meaningful sampler performance regression was observed in this short run.

Mach send-right references in the baseline grew from 1 to 122 across 60 samples and remained there after reader destruction. The candidate went from 1 to 3 and then 2 after destruction: one framework-cached reference plus the reader-owned reference, without per-sample growth. Isolated sampler footprint differed by only one 16 KB page (3,228,128 to 3,211,744 bytes); this is not evidence of a substantial whole-app resident-memory reduction. A 10,000-iteration identical-meter microbenchmark averaged 4.353 ms with repeated rendering and 0.080 ms with the cache; this is not an end-to-end application benchmark.

On the physical host, both baseline and candidate provided CPU in 59/60 samples, GPU in 60/60, temperature in 60/60, CPU power in 59/60, and battery readings in 60/60. The first baseline-dependent counter sample is expected to be unavailable. These are availability smoke checks, not independent sensor-accuracy validation. Experimental mappings retain that status.

## Actual-app visual qualification

The final ad-hoc app was tested interactively in the disposable Parallels guests below. Rendered fixtures supplemented the actual-app pass; they did not replace it.

| Environment | Actual-app observations |
| --- | --- |
| macOS 27.0.1 (26A434), MyStat macOS 27 Experimental Test | Passed light/dark appearance, normal and small displays, resizing with the dropdown open, complete scrolling panel and information text, header/footer placement, settings, interval change, pause/resume, close button, outside-click dismissal, and Escape dismissal. |
| macOS 26.6 (25G72), MyStat macOS 26 Release Test | Passed the same actual-app checks. Sampling changed from five seconds to one second and was restored to five seconds. Existing login preference remained enabled and automatic update checks remained off. |

Observed VM-window captures ranged from approximately 2704 × 1698 pixels at the larger size to 1354 × 850 at the small size; macOS 26 also used a 2050 × 1124 intermediate size. These are capture dimensions, not claims about logical display resolution. At small sizes, the header and footer stayed visible while all content remained reachable by scrolling. The dropdown remained usable when the guest display was resized while it was open. Unavailable GPU/power values in the VMs were displayed as dashes, as expected for virtual hardware.

On both OS versions, an interactive native status-item fixture exercised single digits, two digits, 100%, pause, and unavailable values. Values stayed centered and the neighboring status item did not move. The status-item width remained 105 points across settled states. Light/dark 1× and 2× fixture rasters were also inspected. The fixture uses the production meter/cache implementation; forced readings are supplementary evidence, not real sensor readings.

The information-panel policy correction was found during qualification. The app was rebuilt, and the final candidate was checked on both OS versions after that change. No remaining visual defect was observed in this pass.

## Scope and cleanup

Only an ad-hoc candidate was produced. No PR, push, release, Developer ID signing, or notarization was performed. Release versioning, final signed-artifact checks, and release install/update qualification remain separate release steps. Any subsequent UI change requires repeating the affected visual checks before signing.

Both test VMs were shut down after testing. The macOS 26 original installed application was relaunched before shutdown; the host's installed application and clean baseline clones were preserved. The temporary VM-local transfer server was stopped. Raw diagnostics, packages, and transfer artifacts remain under ignored `build/` and `dist/`; no screenshots of unrelated applications were added to the repository.
