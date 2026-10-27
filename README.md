# Retypo ![Retypo](assets/bubble-128.png) 

![Retypo glass panel docked at the bottom of the screen, showing inline diff highlights over a TextEdit document.](glass-bottom-1-main.webp)

Tiny macOS floating textbox. Run saved prompts on selected text (from any app or manual input), auto-copy the result.

> [!IMPORTANT]
> Personal, opinionated, 100% AI-assisted. Use at your own risk.
>
> Built for me: global shortcut, small textbox, snappy nav, saved prompts, clipboard. That's it.
>
> macOS only. No notarized installer; you run the dev script, which uses a local Apple Development identity when available. Local-first: settings, drafts, history, API keys all live under `~/.retypo/`. No telemetry.

## Why

I keep editing more of my writing through LLMs. Tried voice (Handy is installed), kept drifting back to typing: voice felt like it was sending too much noise into the model. Probably because I write better than I think out loud, and I still don't write well enough.

Other reason: typing long prompts into CLI agents like Codex or Claude Code, then losing the whole thing to a stray keystroke that wipes the input, a crash, or accidentally killing the terminal. Not undoable, gone. Retypo queues every edit and atomically persists the latest draft, then snapshots up to 20 paused-state versions, so the normal recovery path is reopening the panel and picking a snapshot from Settings.

## Caveats

- macOS 13+, Swift 5.9+, Xcode CLT or Xcode.
- Selection import (`Cmd+Shift+Space` from another app) needs Accessibility permission. Grant once when prompted; pick the copy you launch (`build-dev/Retypo-dev.app`, or `/Applications/Retypo-dev.app` when installed). Developer signing keeps the permission stable across rebuilds; without a local signing identity, macOS may ask again after the binary changes.
- Terminal prompt import for Codex/Claude Code uses the terminal's accessible text buffer and is on by default.
- VS Code integrated terminal import is experimental and on by default in Settings. It briefly opens VS Code Accessible View with `Option+F2`, reads the buffer through Accessibility, then presses `Esc`.
- BYO API key (Groq, Anthropic, OpenAI, OpenRouter) **or** your existing Claude Code / Codex subscription through the signed-in CLI. See [Subscription providers](#subscription-providers-claude-code--codex).
- Renamed from Retypo Air. The first launch moves `~/.retypo-air/` to `~/.retypo/` and leaves a symlink at the old path, so an old build still finds its data. The bundle id changed too (`app.retypo.dev`), so macOS asks for Accessibility permission again; delete `/Applications/RetypoAir-dev.app` once the new app works.

## Quick start

```bash
cp .env.example .env       # add at least one *_API_KEY. Load order: shell env, .env in CWD, ~/.retypo/.env. First wins.
scripts/dev-app.sh         # builds + opens build-dev/Retypo-dev.app
RETYPO_BUILD_CONFIGURATION=release scripts/dev-app.sh  # optimized local app
RETYPO_BUILD_CONFIGURATION=release RETYPO_INSTALL_APP=1 scripts/dev-app.sh  # install + open /Applications copy
```

In Settings, pick a provider and click Refresh to load its models.

## Features

- One global shortcut. `Cmd+Shift+Space` in, edit, out.
- Easy go-and-back: hide restores focus to the app you came from.
- Selection import from any app.
- Codex/Claude Code prompt import from terminal windows without manual selection.
- 13 pre-made prompts. Freeform mode: type the prompt live each run.
- Auto-copy and auto-correct.
- Inline or stacked diff. Changed words underlined green.
- History, restorable. Don't lose your drafts.
- Undo/redo.
- Whitespace and newlines trimmed off LLM replies.
- macOS native spellcheck still works underneath.
- 2 Themes: Glass, Lighter. 
- Always-on-top.
- Automatic show on active screen for multi-screen setups.
- Multi-provider: Groq, Anthropic, OpenAI, OpenRouter — plus Claude Code and Codex via subscription, no API key.
- Per-mode and per-model shortcuts.
- Enhanced modes: attach files, folders and web search to a mode; it researches before it answers. See [Enhanced modes](#enhanced-modes).
- Cost tracking: last, session, today. Editable per-model pricing.
- Footer stats: WPM, changed-word delta, char count.
- Auto-correct skips short text, code fences, shell commands, symbol-heavy lines. So it never rewrites a command you're typing.

## Subscription providers (Claude Code / Codex)

Pick **Claude Code** or **Codex** as the provider and the panel shells out to the CLI you are already signed into, so runs bill your subscription instead of an API key. Nothing to configure beyond having the CLI installed and logged in (`claude`, `codex login`).

The panel launches the CLI with its own API keys stripped from the child environment — otherwise Claude Code would find `ANTHROPIC_API_KEY` and quietly bill the API instead of the subscription. It also runs in a scratch directory (no CLAUDE.md/AGENTS.md pickup), one turn only, tools disabled, and Codex sandboxed read-only at low reasoning effort. [Enhanced modes](#enhanced-modes) are the exception: they allow the CLI's read-only and web tools and more turns.

Worth knowing before you switch:

| | API key | Claude Code | Codex |
| --- | --- | --- | --- |
| Latency, short edit | 1–2.5s | ~5–7s | ~6–8s |
| Tokens per call | ~50 | ~11–18k | ~15–16k |
| Billing | per token | subscription | subscription |

The token overhead is each CLI's own harness context, sent on every call; `claude --bare` would trim it but reads `ANTHROPIC_API_KEY` only, which defeats the purpose. Because of that, **auto-run is forced off while a CLI provider is selected** — the footer shows `Manual` and `Enter` runs the mode. Use these for the heavy modes and keep an API provider for auto-correct.

Failures come back with the CLI's own message in the status bar (click it to copy). A transient `Not logged in · Please run /login` right after the CLI rotates its token is one of those — just run again.

Model choice is a short curated list (no CLI exposes a list endpoint); `default` sends no model flag, so `~/.codex/config.toml` or your Claude Code config decides. A model your plan does not include fails with the CLI's own message in the status bar.

## Modes (saved prompts)

A mode is a saved system prompt. **Freeform** is special: type the prompt live each run (popup on Enter, type, Enter to apply).

Built-in: Correct, Typos & Grammar, Improve Writing, Translate, Simplify, Summarize, Bullets, Better way of saying, Make this Tweet Fit, Generate 3 variations, How to respond 3 ways, Caveman, **Freeform**.

Press `Cmd+D`, then click the pencil on a mode card to rename it or edit its prompt in place. Drag the corner grip of the prompt box to resize it; the standard editing shortcuts work there and in every other field. Changes save automatically; built-in modes also offer **Reset default**. Edit, disable, and shortcut-bind modes in Settings. Stored in `~/.retypo/modes.json`.

## Enhanced modes

A plain mode is one request and one answer. Switch **Enhanced** on in the mode editor (`Cmd+D` → pencil) and the mode can consult reference material before it answers:

- **Files and folders.** Click *Add files or folders* or drop them from Finder. Markdown, text, PDF, Word (`.docx`, `.doc`), RTF and ODT are read; images, archives and binaries are skipped, and so are hidden files and `node_modules`, `build` or `dist` folders.
- **Web search** (checkbox).

Retypo picks how the material reaches the model from its size, the way Claude Projects does:

| Attached text | How it is sent | Providers |
| --- | --- | --- |
| Up to ~60k characters (about 15k tokens, 40 files) | Whole, with every run, in a prompt-cached system prompt. One request. | All |
| More than that | The model researches: `list_files`, `search_files` (case- and accent-insensitive, `a\|b` alternatives) and `read_file`, for up to 8 rounds. Lines over 2,000 characters (a Word paragraph, minified JSON) are split into numbered parts, so every part can be found and read | Anthropic, Claude Code, Codex |
| Web search on | Anthropic's server-side search (max 5 per run, $10 per 1,000 searches, added to the cost readout); Claude Code's `WebSearch` | Anthropic, Claude Code |

The mode editor shows which row applies ("sent in full · 3 files · 12k chars" or "searched on demand · 1,240 files") and warns when the selected provider can't run the mode. Enhanced modes carry a ✦ on their pill. The status line follows the research: *Thinking…*, *Searching "reembolso"*, *Reading kb/planos/clinica.md*.

The research loop is deliberately small: read-only tools, a bounded number of rounds, and only the final text comes back to the editor. Attached text and web pages are presented to the model as reference data, not instructions. What the model can reach depends on the provider:

- **Anthropic API:** only what you attached. Every path the model sends is resolved (symlinks and `..` included) and refused outside the attached sources; hidden files (`.env`) and dependency folders are refused even by exact path, unless you attached that file by name.
- **Claude Code:** the attached folders (`--add-dir`) and a fresh per-run folder holding copies of attached single files. The read tools are never allow-listed, because a bare `Read` rule approves reads anywhere; Claude Code denies reads outside those folders. Nothing writes, runs commands or fetches URLs (`WebFetch` stays off; `WebSearch` only when the mode searches the web).
- **Codex:** its read-only sandbox, which can read any file your user can; the mode editor says so. Web search is not offered on Codex: it would give a planted instruction a way to send out what the sandbox read.

Claude Code runs with `--no-session-persistence`, so they leave no transcript of your text or of the files they read under `~/.claude/projects`.

Running an old Retypo Air build after enhancing a mode drops that mode's Enhanced settings the next time the old build saves its modes.

Measured on Claude Haiku 5.5 (live smoke tests, `Tests/RetypoTests/LiveEnhancedSmokeTests.swift`): small documents sent whole, 1.8s; a ~120k-character folder searched in 2 rounds, 5.6s and ~7k input tokens; one web search, 6s. Haiku 5.5 thinks adaptively by default, which is the "thinking" in the loop. Claude Code (haiku) took 6.8s and Codex 13.7s on the same folder.

## External import precedence

When `Cmd+Shift+Space` from another app:

1. **AX selection**. Fast, no clipboard touched. Native macOS apps.
2. **Accessible terminal buffer**. Parses the focused terminal's visible text for Claude/Codex composer semantics.
3. **Experimental VS Code Accessible View**. Enabled by default (`experimentalVSCodeAccessibleViewImport` in `settings.json` or Settings UI). Sends `Option+F2`, reads the Accessible View, then sends `Esc`.
4. **Synthetic `Cmd+C`** via AX-pressed Copy menu. Clipboard read then restored. Terminals, TUIs.
5. **Existing clipboard**. Whatever was already copied.

Every imported value is previewed and asks for confirmation before it replaces
the editor, including imports received while the editor is empty. Failures:
`~/.retypo/import-debug.log`.

## Keyboard

| Shortcut | Action |
| --- | --- |
| `Cmd+Shift+Space` | Show/hide panel (global). From another app: also imports selection, visible terminal prompt, or clipboard |
| `Cmd+Shift+Enter` | Run all enabled modes against current draft |
| `Enter` | Run current mode, auto-copy |
| `Shift+Enter` | New line |
| `Esc` | Hide panel |
| `Cmd+D` | Toggle Candidates overlay |
| `Cmd+S` | Toggle Settings |
| `Ctrl+Tab` | Cycle focus: editor, footer |
| `Tab` / `Shift+Tab` / `Left` / `Right` | Nav within footer, Candidates, Settings |
| `Cmd+1`...`Cmd+0` | Pick a mode (default, editable) |
| `Cmd+Opt+]` / `Cmd+Opt+[` | Cycle accepted models |
| `Cmd+C/V/X/A`, `Cmd+Z`, `Shift+Cmd+Z` | Standard editing |
| `Option+Left/Right`, `Shift+Option+Left/Right` | Move/select by word |
| `Home` / `End` (`Cmd+` for doc) | Line/document boundaries |
| `Ctrl+U` / `Ctrl+K` / `Ctrl+Y` | Kill to line start/end, yank |
| `Cmd+Q` | Quit |

`Cmd+Shift+Space` is not Spotlight (`Cmd+Space`) or emoji viewer (`Ctrl+Cmd+Space`). A few apps may bind it but it's usually safe.

## Files (`~/.retypo/`)

| File | Purpose |
| --- | --- |
| `settings.json` | Prefs |
| `modes.json` | Editable modes/prompts |
| `pricing.json` | USD per 1M tokens (editable) |
| `history.json` | Run history (input, output, diff, prompt sent) |
| `usage-ledger.json` | Token/cost ledger |
| `draft.txt` | Realtime draft recovery |
| `draft-history.json` | Draft snapshots |
| `import-debug.log` | Selection-import diagnostics |

## Contribute / quality

Pre-push hook runs `bin/quality`: SwiftLint, Periphery, tests, coverage. All ratcheted from `quality_thresholds.json`. See `QUALITY.md`.

```bash
bin/quality          # run all gates
bin/quality-bump     # ratchet baseline lower after improvements
swift test           # tests only
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
