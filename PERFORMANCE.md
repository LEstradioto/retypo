# Performance Plan

Retypo should feel instant while hidden, opening, importing, and typing.
Performance work follows one rule: measure a user-visible path, make one focused
change, and repeat the same measurement before claiming an improvement.

## Baseline

Captured on 2026-09-02 on Apple silicon with the current macOS/Xcode toolchain:

- Release executable: 2.7 MB.
- Debug app bundle: 5.7 MB.
- Installed Debug process after about one hour: 0.0% CPU and 78,800 KB RSS in
  one `ps` sample.
- Quality gate: see `quality_thresholds.json`.

The process sample is orientation only. It is not a regression threshold because
Debug builds, one-off samples, and resident memory do not isolate retained memory
from framework and system caches.

Not measured yet:

- cold launch to first usable editor;
- global shortcut to visible, focused editor;
- typing latency and disk activity for long drafts;
- import capture to confirmation preview;
- result-to-inline-diff latency for long inputs;
- repeated show/hide memory stability.

## Static findings to validate

These are code-review findings, not measured bottlenecks.

1. `AppState.onInputChanged` previously atomically wrote `draft.txt` on every
   keystroke and performed a full localized word scan after the warm-up window.
   Loop 1 moved the draft write off the main actor and bounds the word scan to
   two refreshes per second.
2. Window move and resize callbacks previously encoded and atomically wrote the
   settings file for every callback. Loop 2 now coalesces frame-only changes and
   flushes the final frame at interaction/lifecycle boundaries.
3. Most views observe one large `AppState`. Changes from `CostTracker` and
   `LLMSession` are forwarded through `AppState.objectWillChange`, which can make
   unrelated state changes re-evaluate broad SwiftUI subtrees.
4. `InlineDiffService` uses an O(oldWords * newWords) LCS matrix only within a
   fixed one-million-cell budget. Loop 4 added a linear coarse path for larger
   documents after Release measurements confirmed quadratic growth. `TextDiff`
   replaced it on 2026-10-27; see the track-changes pass under Loop 4.
5. Import debugging creates an unstructured task, timestamp formatter, and file
   handle for each log line. This is bounded during normal imports but should be
   checked in File Activity before changing it.
6. Launch synchronously loads settings, modes, history, pricing, usage, snapshots,
   and the draft before presenting the panel. The files are currently small; App
   Launch profiling should determine whether any belong after first interaction.

## Repeatable scenarios

Record Release builds with stable app data and repeat each scenario at least five
times. Keep the machine, display setup, input files, and network state constant.

1. **Cold launch:** terminated app to a focused, editable textbox.
2. **Warm reveal:** hidden app to a focused textbox through `Cmd+Shift+Space`.
3. **Typing:** append 200 characters to 100-, 1,000-, and 10,000-character drafts.
4. **Window movement:** drag and resize continuously for ten seconds.
5. **Import:** selected text and clipboard fallback at 100, 1,000, and 10,000
   characters, ending at the confirmation preview.
6. **Diff:** compare near-identical and fully rewritten texts at 100, 1,000, and
   10,000 words.
7. **Lifetime:** reveal and hide the app 100 times, then compare retained memory
   and live panel/task counts with the starting state.
8. **Idle:** leave the hidden app untouched for five minutes and inspect CPU,
   wakeups, disk writes, and network activity.

## Tools and signals

- **App Launch + Time Profiler:** launch phase and first-interaction critical path.
- **SwiftUI instrument:** long view updates and unnecessary update groups.
- **Hangs + Time Profiler:** keyboard, import, and panel responsiveness.
- **File Activity:** per-keystroke draft writes, frame persistence, and debug logs.
- **Allocations + Memory Graph:** LCS matrices, temporary strings, tasks, and panel
  lifetime.
- **Energy Log or Power Profiler:** idle wakeups and repeated background work.
- **`OSSignposter`:** app-specific intervals for launch, reveal, import, draft
  persistence, word statistics, model refresh, and diff generation.

Track median and p95 where the tool supports repeated measurements. For memory,
prefer retained-growth and generation comparisons over one absolute RSS number.

## Optimization loops

### Loop 1: typing and persistence

Profile the 10,000-character typing scenario with Hangs, Time Profiler, and File
Activity. If the static finding is confirmed:

- inject a project-owned draft persistence interface;
- serialize writes away from the main actor while preserving their order;
- coalesce only if the accepted crash-recovery window is explicit;
- throttle or incrementally update WPM instead of rescanning the full draft on
  every keystroke;
- add deterministic tests with a named in-memory fake.

Success signal: no synchronous filesystem call on the main thread during typing,
lower keypress-to-frame latency, and a final-draft flush on normal hide or quit
with any abrupt-failure recovery window documented.

#### Draft-write pass — 2026-09-02

The initial measurement isolated the caller cost of the same atomic-write
operation used by `DraftStore`. Five runs of 200 sequential writes of a 50 KB
draft took 67.72, 134.30,
80.47, 61.42, and 72.99 ms (72.99 ms median). The synthetic size makes the
blocking work visible; it is not a claim about typical draft size or frame time.

`AppState` now receives a project-owned `DraftPersisting` dependency. Production
uses a utility-priority serial queue, and only the latest waiting value is kept
while a write is in flight. All editor restore/import paths use the same
persistence path. Hiding or normally terminating the app flushes queued work.

A focused post-change benchmark held the write backend busy to isolate 200
main-actor `save` calls. Five runs took 0.04, 0.03, 0.03, 0.03, and 0.03 ms
(0.03 ms median). This proves the filesystem wait left the typing caller; it does
not measure total storage latency. Deterministic tests verify background writes,
burst coalescing, final-value ordering, injected draft loading, and lifecycle
flushes.

Recovery remains immediate after each completed background write and on normal
hide/quit. An abrupt process or system failure can lose the most recent value
while it is queued or in flight; this short window is the explicit cost of taking
filesystem I/O off the typing path. A Release Instruments trace is still needed
before claiming lower keypress-to-frame latency. The WPM scan is addressed in
the next pass below.

#### WPM pass — 2026-09-02

The baseline ran 200 localized word scans for each draft size. Median totals were
7.67 ms at 100 characters, 12.30 ms at 1,000 characters, and 62.74 ms at 10,000
characters. This synthetic loop represents the old one-scan-per-key-event path;
it does not include SwiftUI rendering.

Per-key work now records only session and pause timestamps. A word scan and WPM
publication occur at most every 0.5 seconds, so the displayed rate remains live
without invalidating the footer for every key. `WordCounting` is injected into
`AppState`, while `LocalizedWordCounter` retains the existing Foundation word
semantics.

For 200 simulated key events at 20 events per second with a 10,000-character
draft, the scan count fell deterministically from 200 to 20. Five post-change
runs took 6.67, 4.20, 4.31, 4.06, and 4.18 ms (4.20 ms median), compared with the
62.74 ms baseline. Tests lock the two-refreshes-per-second ceiling, warm-up and
pause-reset behavior, WPM calculation, and localized word semantics. A Release
Instruments trace remains necessary to connect this reduced work to frame time.

### Loop 2: window frame persistence

Measure writes while dragging and resizing. If write amplification appears,
persist at the end of live resize and debounce moves, with a final flush on hide
or termination.

Success signal: one bounded settings write per interaction without losing the
last window frame.

#### Frame-write pass — 2026-09-02

The baseline used the production `PersistedFile<RetypoSettings>` against an
isolated temporary file. Five runs of 200 frame mutations plus settings writes
took 39.43, 37.90, 36.26, 35.79, and 34.84 ms (36.26 ms median), and performed
200 encodes and atomic writes.

Frame callbacks now update the in-memory setting and debounce persistence for
300 ms. Live-resize end, panel hide/close, and normal termination synchronously
flush the final pending frame. Unchanged callbacks are ignored. Other settings
continue to save immediately, so this pass does not alter preference semantics.
`SettingsPersisting` gives AppState tests a named in-memory fake instead of the
live user file.

Five post-change runs of 200 callback schedules took 0.37, 0.33, 0.33, 0.38, and
0.32 ms (0.33 ms median), excluding the one final persistence call. A regression
test verifies 200 callbacks cause zero immediate writes and exactly one final
write with the last frame. This confirms write amplification is removed; a live
AppKit File Activity trace remains the end-to-end validation.

### Loop 3: SwiftUI change locality

Use the SwiftUI instrument to connect state mutations to update groups. Keep
`ObservableObject` compatibility with macOS 13; do not adopt Observation solely
for speed because it would require macOS 14.

If broad invalidation is visible, let focused child views observe `CostTracker`
and `LLMSession` directly, remove whole-app change forwarding, and split other
state only where a trace shows unrelated view updates.

Success signal: fewer unrelated body evaluations for typing, token updates, model
loading, and cost changes, with no visual behavior change.

### Loop 4: long-text diffing

Benchmark `InlineDiffService` in Release before changing the algorithm. If the LCS
matrix dominates time or allocation, first add an explicit input budget and a
safe coarse fallback; consider a lower-memory diff algorithm only if the product
needs exact highlighting for very large documents.

Success signal: bounded memory and latency at the supported maximum input while
existing diff fixtures remain identical.

#### Bounded-diff pass — 2026-09-02

The Release baseline changed one middle word in otherwise identical documents.
Median times were 0.10 ms at 100 words, 3.27 ms at 1,000 words, and 26.05 ms at
3,000 words, demonstrating the expected quadratic curve. A 10,000-by-10,000 LCS
was not run before the fix because its `Int` cells alone would require about
800 MB, excluding row and allocator overhead.

Exact LCS now has a one-million-cell budget. Above it, the diff compares common
prefix and suffix tokens and marks the remaining corrected span. This is linear,
keeps a single localized edit precise in a long document, and bounds a full
rewrite. The explicit tradeoff is that multiple distant edits or reordering in a
large document may highlight the intervening corrected text as one coarse span.

Post-change Release medians were 0.11 ms at 100 words, 3.13 ms at 1,000 words,
0.66 ms at 3,000 words, and 2.07 ms at 10,000 words. Tests preserve all exact
small-input fixtures, lock the cell-budget boundary, validate a precise
10,000-word single replacement, and cover a large full rewrite.

#### Track-changes diff — 2026-10-27

`TextDiff` replaced the words-only LCS so punctuation, capitals, line breaks
and removals show. It trims the common prefix and suffix, aligns words,
punctuation and line breaks with Myers' O(ND) algorithm, compares the spaces
between kept tokens, then merges short kept stretches between edits. The
ceiling moved from text length to edit count: up to 1,000 removed plus added
tokens the diff stays exact at any length (the Myers trace holds about
(D+1)² Ints, the same 8 MB the LCS budget allowed); past that the changed
middle shows as one replaced block.

Release medians on this Mac (Apple Silicon), from a `/tmp` harness compiled
with `-O` against `Core/TextDiff.swift` and the three `Core/Diff*.swift` files:

| Words | One middle word | A word every 50 | Full rewrite |
| ---: | ---: | ---: | ---: |
| 100 | 0.40 ms | 0.39 ms | 0.43 ms |
| 1,000 | 3.00 ms | 3.06 ms | 3.42 ms |
| 3,000 | 8.74 ms | 9.04 ms | 10.00 ms |
| 10,000 | 29.31 ms | 29.93 ms | 36.25 ms |

A change every 20, 10 or 5 words in 10,000 words, past the edit limit,
stayed at 35–37 ms, and peak process footprint stayed under 20 MB. Time is
linear in length and mostly tokenizing and interning both texts, not the
alignment. Against the previous pass, short texts cost a few tenths of a
millisecond more, and long texts pay about 3 ms per 1,000 words to stay
exact where the coarse path marked one span.

### Loop 5: launch, logging, and idle work

Profile cold launch and a complete import. Defer only work that appears on the
critical path. Reuse or buffer debug-log resources only if File Activity shows a
meaningful cost. Verify model refresh, timers, and tasks do not create hidden idle
wakeups.

Success signal: shorter first-usable-editor time and no measurable hidden idle
work, without delaying required state restoration.

## Regression policy

Each optimization gets its own commit and includes:

1. the baseline scenario and evidence;
2. the smallest source change tied to that evidence;
3. correctness and performance regression coverage where deterministic;
4. the same after-measurement;
5. `bin/quality` results;
6. a baseline update only after repeated measurements are stable.

Performance tests should not join the fast pre-push gate until their variance is
known. Store traces outside Git; commit small summaries and stable numeric
baselines only.

## Skill and platform references

- [OpenAI SwiftUI performance audit](https://github.com/openai/plugins/blob/main/plugins/build-ios-apps/skills/swiftui-performance-audit/SKILL.md)
- [iOS Performance Agent Skills](https://github.com/Livsy90/iOS-Performance-Agent-Skills)
- [Swift Concurrency Agent Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill)
- [Apple SwiftUI performance analysis](https://developer.apple.com/documentation/swiftui/performance-analysis)
- [Apple Instruments tutorials](https://developer.apple.com/tutorials/instruments)
- [Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/)
