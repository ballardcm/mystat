# Hardware interface references

MyStat's macOS 27 M5 Pro/Max CLPC counter identifiers and IOReport descriptor layout are adapted from [vladkens/macmon](https://github.com/vladkens/macmon), specifically `src/clpc.rs`, `src/sources.rs`, and `docs/clpc-discovery.md` (reviewed 2026-10-10). The descriptors are isolated in `Sources/Hardware/CLPC.c`. MyStat does not embed or run the macmon executable.

MIT License

Copyright (c) 2024 vladkens

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

The AppleSMC packet ABI and key protocol were cross-checked against [exelban/Stats](https://github.com/exelban/stats/blob/master/SMC/smc.swift). MyStat implements an independent read-only C client and does not include fan-control or SMC write operations.

## Sparkle updater

MyStat bundles [Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/releases/tag/2.10.0), copyright Sparkle Project and contributors, under its MIT license and bundled third-party licenses. The complete upstream notice is preserved in [ThirdParty/Sparkle-LICENSE.txt](ThirdParty/Sparkle-LICENSE.txt) and copied into the application as `Contents/Resources/Sparkle-LICENSE.txt`.

Sparkle handles update scheduling, authenticated feeds and archives, native update dialogs, download recovery, installation, and relaunch. It is the explicit dependency/network exception to MyStat's otherwise offline design.
