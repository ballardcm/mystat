# Core Graphics chart implementation and qualification

Prepared with substantial OpenAI Codex assistance on 2026-10-17. This extends the [memory fixes](2026-10-17-memory-footprint.md) and follows the [renderer investigation](2026-10-17-dashboard-memory-research.md).

## Candidate and implementation

Qualified source revision: `e3aafdd25ae8c50d4177a0e18e0c1b68676ff678` on branch `perf/reduce-sampling-memory`, based on `01d8036b0126d8606f5bb64a5e259b6abd79824a`. The candidate was built before committing; all source/test/script hashes were checked unchanged against the qualification manifest before the commit. Xcode 27.1 (27A9275), macOS SDK 27.0, optimized arm64 ad-hoc candidate, test-only version 0.2.1/build 6.

Executable SHA-256: `6c7d8779c4b819f7586d54e8d00b57f36777aa1504965e80f80dcba967485c29`.

ZIP SHA-256: `55105eb3e82d0ede0b63de64e0ca5627c6f3e5da317987805b79409cdb557bf1`.

The three sparklines now use AppKit NSViews wrapped by NSViewRepresentable, drawing baseline, rounded line and gradient area through Core Graphics. The rest of the SwiftUI dashboard remains. Histories retain the 60-sample limit and right-aligned partial-history axis. Non-finite samples produce gaps, out-of-range percentages are clamped, and degenerate geometry is rejected. The view requests redraw only when normalized samples or color change, and invalidates on effective-appearance changes. The metric cards retain their existing accessibility labels/values; decorative chart content remains hidden from accessibility.

Changed source hashes relative to the base (including the earlier memory work):

| File | SHA-256 |
| --- | --- |
| Sources/MyStat/AppDelegate.swift | `0e705e838e0377b97fdfd3265a44e5098a96aeddf01838cc726b290bfc2b6055` |
| Sources/MyStat/Dashboard.swift | `640e9b65109c36387bc3ad5d6c090f79909f9a6bf1c69e27e728d22802376a51` |
| Sources/MyStat/MenuBarMeter.swift | `2778426d03131cf78c4ddb96771bdca825f8326b016180c5454ead8354e25c64` |
| Sources/MyStat/Metrics.swift | `f88c956c2808d33cf8c4d620e2d98f61c31c45776e29c84ace847c46bd3f1e1e` |
| Sources/MyStat/Sparkline.swift | `a378987cdf543bfe5c8beb63b11968a5b60625f4d72ca96fb33ec4f72cc44bc6` |
| Tests/MenuBarMeterTests.swift | `9d067384448301b1203b2ebaf35198ea09117ebd6ca6199d7fe0aec45a1c896d` |
| Tests/MetricsTests.swift | `8aeb8a8462b24b04cb460398027b34a69233da035a1512348af9ff6a054c71c1` |
| Tests/SparklineTests.swift | `96e4e4c107f06cd90b75f876b127c5dfc3ca77b40f492e3657555b5f8d269777` |
| scripts/test.sh | `132d754ed3f9e6166d421784d60aa11132c2102a3cd53bac3627168b387918fc` |

The complete local source/test/script manifest is in ignored `build/dashboard-qualification/source.json`; its canonical hash is `44653e566f2057490478cb4ef3576eb3f52e63e740f2eec48b16fde1280d1973`.

## Automated and actual-app checks

`scripts/release.sh --adhoc` completed the full automated suite and built the candidate. Chart tests cover empty/single/full/partial histories, bounded retention, clamping, non-finite gaps, invalid dimensions, and baseline/line/gradient rendering in light/dark appearances at 1× and 2×. The same chart test binary passed in both supported OS guests. The complete Sparkle integration suite passed signed-feed/archive rejection, selection, defer/cancel, download errors, install/relaunch and preference preservation. No sensor mappings or sampling cadence were changed by the renderer work.

Both guests ran the exact executable hash above from their `Applications/ChartQualification/MyStat.app` folders, with running process paths checked to exclude prior copies.

| Environment | Observed result |
| --- | --- |
| macOS 27.0.1 (26A434), MyStat macOS 27 Experimental Test | Actual app passed normal/small display, light/dark chart appearance, resizing while open, scrolling through all sections, information text, settings, pause/resume, close button, Escape, and outside-click dismissal. One-second refresh was exercised. |
| macOS 26.6 (25G72), MyStat macOS 26 Release Test | Actual app passed the same appearance/layout/dismissal/settings checks, including 1/2/5-second interval selection. The original five-second setting was restored. Launch-at-login remained checked; automatic updates remained off. |

Normal VM captures were approximately 2704 × 1698 pixels; small captures approximately 1354 × 850 pixels. These are capture dimensions, not logical display-resolution claims. Headers and footers remained visible at the small size; all body sections were reachable by scrolling. The live meter remained aligned across observed one/two-digit CPU readings, pause glyphs and unavailable GPU readings. The prior forced maximum-width meter fixture remains supplementary evidence for the unchanged meter implementation; this pass repeated actual-app checks for the changed chart UI.

On macOS 27, 100 actual open/close cycles were driven through the guest UI, with settled footprint measured before and afterward. Median closed footprint changed from 27.08 to 27.14 MiB (approximately 0.06 MiB); the recorded three-minute window during the later cycles peaked at 28.67 MiB. A subsequent 79-second visible-panel window was 28.41–28.53 MiB. This guest run was stopped to finish the other OS pass; it was not a one-hour test.

During 126 seconds of macOS 26 visual checks, including appearance/size/interval changes and pause/resume, the sampled footprint was 23.14–26.33 MiB, median 24.28 MiB. This is an interactive short run, not a continuous stationary-panel benchmark.

Both VMs were shut down afterward and the original macOS 26 app was relaunched before shutdown. The temporary transfer server was stopped. Clean baseline VMs were preserved. At the end of this qualification pass, no Developer ID signing, notarization or release had been performed. The source and this evidence are being submitted for PR review; release remains subject to owner approval.

## Physical-host validation

The host is an Apple M5 Pro with 48 GB on macOS 27.0.1. The previous local test copy was used as the Canvas control, then quit; the new candidate was launched from `dist/chart-test/MyStat.app`. Both use the same sampling/meter memory fixes and differ in the chart implementation. Native accessibility inspection still exposes the metric-card labels and values while decorative charts remain absent from the accessibility tree. Live physical CPU/GPU/temperature/power/fan readings were present; this is availability smoke testing, not independent sensor-accuracy validation.

Physical-host memory/CPU comparison and the completed longer visible-panel run are recorded below. Raw readings remain under ignored `build/dashboard-qualification/`.

At the same two-second refresh interval, each physical-host comparison window contained 61 once-per-second footprint samples. The new candidate first warmed for 121 seconds to fill all 60 history slots. The control already had full histories. Median footprint was 127.30 MiB for Canvas (range 37.00–127.36) versus 29.59 MiB for Core Graphics (29.47–30.03), about 77% lower. `ps` total process CPU time advanced by 0.80 seconds for the control and 0.67 seconds for the candidate over their approximately 61-second windows. These are short sequential runs under the host's existing workload, not randomized trials or a dedicated energy/latency benchmark. No CPU regression was observed in this comparison.


### One-hour visible-dashboard soak

The same physical-host candidate ran with the dashboard open at a one-second refresh from 2026-10-17 19:32:51 UTC to 20:33:07 UTC. Passive process-footprint monitoring collected 3,601 samples over 60.26 minutes. Periodic actual-app observations, including the final observation, confirmed that the panel remained live with physical readings and charts.

| Measurement | Result |
| --- | ---: |
| Median physical footprint | 32.25 MiB |
| Maximum sampled footprint | 32.81 MiB |
| Kernel-reported process lifetime peak | 33.27 MiB |
| First-minute median | 32.55 MiB |
| Last-minute median | 30.14 MiB |
| Final sampled footprint | 30.20 MiB |

There was no upward memory trend, crash, or observed loss of functionality. Total process CPU time increased by 70.81 seconds over approximately 3,616 seconds (about 1.96% of one core) at the one-second refresh. This includes the complete app, not just drawing. The display-awake assertion used for the soak ended with the monitor. The host refresh interval was restored to two seconds afterward; the ad-hoc candidate remains running for local testing.

The large reduction comes from replacing Canvas graphics allocations; it should not be attributed entirely to the separate Mach send-right leak fix. The original sampler acquired two additional send-right references per sample and retained them after reader destruction. The new ownership test and before/after experiment show bounded references and release of the reader-owned right. See the earlier memory report for that experiment and sampler timing results.

No source/UI changes followed this qualification. Release versioning, Developer ID signing/notarization, and final signed-artifact installation/update checks remain release steps after review and approval. VM UI checks do not independently validate physical sensors; the macOS 27 mappings remain experimental.
