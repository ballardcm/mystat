# Dashboard memory investigation and architecture options

Prepared with substantial OpenAI Codex assistance on 2026-10-17. This is research, not qualification of a production fix.

## Finding

The maintainer's approximately 125 MB open-dashboard observation was reproduced. My earlier single 35 MB measurement was an incomplete description: the control's physical footprint fluctuates between low readings and approximately 125–126 MiB during live rendering. Reclaimable graphics accounting does not make that higher working footprint acceptable for this project.

An isolated prototype replaces only the three SwiftUI Canvas sparklines with NSViewRepresentable-wrapped AppKit NSViews drawing the same baseline, stroke and gradient with Core Graphics. The rest of the SwiftUI dashboard, scrolling, core grid, metrics reader, sampling interval and menu-bar implementation are retained. This short experiment reduced measured open-dashboard footprint substantially without changing the implementation language.

## Method and measurements

Host: physical Apple M5 Pro, 48 GB, macOS 27.0.1. Compiler: Xcode 27.1, optimized arm64 builds. Source base and existing performance changes are identified in [the qualification record](2026-10-17-memory-footprint.md).

Built separate research bundles under ignored `build/dashboard-research/`, with separate bundle identifiers. Both variants suppress updater startup identically; neither performs updater traffic. The owner's local test app remained running in the background during both variants. Research variants were run sequentially, with default two-second sampling. The control uses the current Canvas implementation. The Quartz variant substitutes an NSView chart renderer and invalidates it only when values or color change. Both keep the 60-sample history limit.

Used passive `proc_pid_rusage(RUSAGE_INFO_V4)` physical-footprint readings, one per second, twelve readings per window. This avoids relying on a single detailed memory snapshot. The repeated control was a fresh process; the repeated Quartz window was the same process after more live updates. This is a short diagnostic comparison, not a randomized long-duration benchmark. Live dashboards were inspected through the actual UI; the Quartz screenshot visibly contained working charts and all normal dashboard sections.

| Variant/window | Minimum MiB | Median MiB | Maximum MiB |
| --- | ---: | ---: | ---: |
| Current Canvas control | 35.14 | 125.66 | 125.95 |
| Core Graphics charts | 29.86 | 30.24 | 30.53 |
| Core Graphics charts, later repeat | 29.44 | 29.47 | 29.83 |
| Current Canvas control, fresh-process repeat | 34.53 | 124.99 | 125.27 |

Median reduction is approximately 76% in this experiment. This is physical footprint, not RSS, private heap, package size, or a guarantee of Activity Monitor's exact display. RSS remained approximately 81 MiB for the prototype and 86 MiB for the control; mapped/shared pages and graphics accounting make these metrics different. There are no measured results yet for this renderer on macOS 26, long-term growth, energy consumption, or UI interaction latency. No claim of complete functionality/accessibility equivalence or production performance qualification is made.

The experiment provides strong evidence that the Canvas rendering path is a principal contributor on this host. It does not identify a particular internal Metal allocation or establish an operating-system leak. The AppKit drawing code remains inside a SwiftUI hosting hierarchy; this is not evidence that all SwiftUI must be removed.

Research source, helper, build script, and raw readings are in ignored `build/dashboard-research/`. Production sources and the previously qualified test binary were not modified by this experiment. Both research processes were quit afterward.

## Options, in recommended order

1. **Retain Swift and replace Canvas charts with AppKit/Core Graphics.** This has direct local evidence, small scope and no new runtime dependency. Keep native scrolling, controls, accessibility, settings, updates and the existing sensor backend. Harden color handling, resizing, clipping, non-finite/missing data, accessibility grouping and teardown before implementation is considered complete. Apple explicitly supports embedding AppKit through [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable). Its [view drawing guidance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaViewsGuide/Optimizing/Optimizing.html) recommends limiting invalidation and unnecessary drawing. This is the first implementation candidate.

2. **Move the whole dashboard to AppKit while keeping Swift.** Replace NSHostingController/SwiftUI layout with NSScrollView, native controls and a small number of custom drawing views. Keep existing C sensors, Swift metrics, menu bar and Sparkle. This gives more explicit control over view allocation, redraw regions and backing layers. It is a moderate UI rewrite and needs deliberate accessibility, appearance, resizing and interaction work. Further savings beyond option 1 are unmeasured. Apple notes that [layer backing has memory overhead and should be measured](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/CoreAnimationBasics/CoreAnimationBasics.html). Use this if option 1 misses the budget.

3. **Objective-C or Objective-C++ with AppKit/Core Graphics.** This is the most direct alternative if removing Swift itself becomes a goal. The existing hardware backend is already C, and the native AppKit drawing design can be retained. It could remove direct Swift/Combine usage from application code, but actual savings beyond Swift plus AppKit are unknown; transitive frameworks must also be audited. Porting metrics, application lifecycle, updater integration and tests increases scope. This is a viable longer-term path, not justified by the present renderer result alone.

4. **Rust with AppKit/Core Graphics.** Technically feasible with native [objc2 AppKit bindings](https://docs.rs/objc2-app-kit/latest/objc2_app_kit/struct.NSView.html), but still uses the same native drawing infrastructure. It adds a Rust toolchain, third-party binding maintenance, Objective-C interoperability and unsafe boundaries. No memory advantage over a well-designed Swift/AppKit renderer has been measured. Do not choose this solely for the language's low-overhead reputation.

A web UI is a poor fit for this objective and the native/no-additional-runtime-dependency repository policy. [Tauri](https://tauri.app/concept/architecture/) uses HTML rendered in a WebView even though the core is Rust; a small download is not evidence of a small running footprint. [Electron](https://www.electronjs.org/docs/latest/tutorial/process-model) adds Chromium's process architecture and a Node.js main process. Neither is the proposed route to reduce this small dashboard's memory use.

Within SwiftUI, narrower observation and a single presentation snapshot remain secondary opportunities: Monitor publishes metrics plus three histories, and Dashboard observes the whole model. Apple's [performance guidance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance) explains unnecessary updates from broad ObservableObject dependencies. These changes may reduce update work; they have not been shown here to remove the large graphics footprint.

## Proposed acceptance gates

Before release, qualify the selected production implementation on macOS 27 and macOS 26. Proposed budgets on the current host are at most 50 MiB steady open-dashboard footprint, at most 65 MiB during normal open/close operation, and approximately 35 MiB or less settled closed footprint. These are proposed engineering targets, not promises for all hardware or display scales.

Measure a one-hour visible-panel run, full histories, 100 open/close cycles after warm-up, and 1/2/5-second sampling. Compare settled retained growth, peak footprint, RSS, CPU/energy and responsiveness against the control. Keep all displayed readings, history length, controls and update behavior. Repeat the actual-app visual/accessibility checks on both supported OS versions, including display resizing with the panel open and light/dark appearance. Do not trade away sampling frequency, charts or readability to reach a memory number.

Recommendation: implement and qualify option 1 first; reserve option 2 for a demonstrated budget miss. A language rewrite currently has much weaker evidence than the focused renderer change.
