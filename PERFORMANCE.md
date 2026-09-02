# Performance Plan

Retypo Air should feel instant while hidden, opening, importing, and typing.
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

1. `AppState.onInputChanged` atomically writes `draft.txt` on every keystroke and
   performs a full localized word scan after the warm-up window. Both happen on
   the main actor and scale with draft length.
2. Window move and resize callbacks synchronously encode and atomically write the
   settings file for every callback.
3. Most views observe one large `AppState`. Changes from `CostTracker` and
   `LLMSession` are forwarded through `AppState.objectWillChange`, which can make
   unrelated state changes re-evaluate broad SwiftUI subtrees.
4. `InlineDiffService` builds an O(oldWords * newWords) LCS matrix. That is simple
   and correct for normal prompts, but time and memory can grow sharply for large
   documents.
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
lower keypress-to-frame latency, and unchanged recovery behavior.

### Loop 2: window frame persistence

Measure writes while dragging and resizing. If write amplification appears,
persist at the end of live resize and debounce moves, with a final flush on hide
or termination.

Success signal: one bounded settings write per interaction without losing the
last window frame.

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
