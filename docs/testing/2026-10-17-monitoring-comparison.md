# Menu-bar memory and CPU comparison — 2026-10-17

Prepared with substantial OpenAI Codex assistance.

MyStat 0.2.2 used 40.6% less median physical memory than popular paid monitoring software on the tested MacBook Pro. Average CPU use was similar: 0.548% versus 0.535% of one core. The two VM observations also showed a lower MyStat memory footprint. These results describe the configurations below, not every workload or competing product.

## Tested configuration

- MyStat 0.2.2, build 7, release source `d2994a9d6fad9c3af0f5e1494ccd8b6a010658cd`. The installed executable matched release SHA-256 `eead82e405a0b516ed26055a0a4c8872e00e46f12aecbe4485dfa06497a6fbb7` in all three environments.
- Comparison software: a purchased Mac App Store edition of popular paid monitoring software, configured for CPU/GPU and memory, with other monitoring modules disabled. Its optional privileged sensor helper was not installed. Its “Medium” setting maps to a nominal two-second statistics-update delay, verified by read-only inspection of the installed build. Feature sets and internal subsystem schedules are not identical between the products.
- Physical host: M5 Pro MacBook Pro, 18 CPU cores, 20 GPU cores, 48 GiB RAM, macOS 27.0.1 (26A434). MyStat used two-second refresh. The user confirmed that the comparison software's CPU, memory, and GPU menu-bar numbers were visible and updating.
- macOS 27 guest: macOS 27.0.1 (26A434), four virtual CPUs, 8 GiB RAM. Both apps used nominal two-second refresh. The comparison software displayed a GPU value of 0%; MyStat displayed an unavailable dash. This is virtual hardware, not physical GPU validation.
- macOS 26 guest: macOS 26.6 (25G72), four virtual CPUs, 8 GiB RAM. MyStat retained its five-second refresh preference; the comparison software used two seconds. CPU and memory menu items were observed; physical GPU telemetry was unavailable.

Both apps ran together in each environment, with settings and dropdowns closed during measurement. The host retained its usual workload and test VMs; this was not a dedicated idle-system benchmark. The macOS 26 guest shut down around minute 17 of the host capture while setup continued in the other guest. MyStat's host dashboard had been opened during setup and was closed before the timer. VM results should not be compared directly with the physical host to infer OS or sensor costs.

## Results

Each row summarizes the first approximately 1,200 elapsed seconds. Later settings verification, resizing, and shutdown are excluded.

| Environment / application | Median footprint | Sampled peak | CPU seconds | Average CPU, one core |
| --- | ---: | ---: | ---: | ---: |
| MacBook Pro / MyStat | 27.88 MiB | 29.91 MiB | 6.567 | 0.548% |
| MacBook Pro / paid software | 46.92 MiB | 62.80 MiB | 6.421 | 0.535% |
| macOS 27 VM / MyStat | 11.80 MiB | 11.85 MiB | 2.211 | 0.184% |
| macOS 27 VM / paid software | 43.52 MiB | 47.69 MiB | 3.211 | 0.268% |
| macOS 26 VM / MyStat | 10.22 MiB | 10.30 MiB | 0.858 | 0.071% |
| macOS 26 VM / paid software | 40.52 MiB | 45.03 MiB | 2.119 | 0.177% |

MyStat's median footprint was 40.6% lower on the host, 72.9% lower in the macOS 27 VM, and 74.8% lower in the macOS 26 VM. The last VM's CPU numbers use different refresh rates and do not establish a matched-rate efficiency advantage.

On the host, first-minute and last-minute median footprints were 27.97 → 28.38 MiB for MyStat and 46.50 → 53.99 MiB for the paid software. VM footprints changed little: 11.74 → 11.80 MiB versus 43.38 → 43.58 MiB on macOS 27, and 10.19 → 10.25 MiB versus 40.42 → 40.58 MiB on macOS 26. Intermittent history subprocesses contributed to the paid software's sampled peaks. Twenty minutes cannot distinguish normal caching from longer-term growth or establish leak freedom.

## Measurement and validation

A separate lightweight native sampler enumerated the apps' processes about once per second and read `proc_pid_rusage` with `RUSAGE_INFO_V4`. Memory is `ri_phys_footprint`, in MiB of 1,048,576 bytes, summed across observed matching processes at each timestamp. It is not RSS, installation size, or total system memory attributable to an app. The settings application was absent during the analyzed windows; intermittent history services were included when present.

CPU uses changes in cumulative user and system counters. Raw Mach ticks were converted with each environment's `mach_timebase_info` ratio of 125/3 nanoseconds per tick; converted lifetime totals agreed with `ps` CPU time to 0.01 seconds. For processes present at the start, initial counters were subtracted. For subprocesses first observed during the run, lifetime CPU through their last observation was included. Very short unseen processes and work between a subprocess's final observation and exit can be missed. CPU percentage is CPU seconds divided by elapsed seconds, multiplied by 100; 100% means one fully occupied core.

The host window contained 1,189 paired timestamps over 1,199.394 seconds; macOS 27 contained 1,103 over 1,198.957 seconds; macOS 26 contained 1,123 over 1,199.926 seconds. Both apps were present at every analyzed timestamp, and per-process CPU counters were monotonic. Raw diagnostics and executable inspection artifacts remain outside version control; only this reviewed summary is published.

This was one observation per environment, with no synthetic load, randomized trials, energy measurements, or independent sensor-accuracy validation. Nominally matching refresh rates does not match every feature or unit of work. CPU differences this small should not be read as evidence of better battery life. macOS 27 remains the primary target, macOS 26 remains supported, and experimental sensor mappings retain that status.
