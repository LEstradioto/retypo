# Retypo Air ![Retypo Air](assets/bubble-128.png) 

![Retypo Air glass panel docked at the bottom of the screen, showing inline diff highlights over a TextEdit document.](glass-bottom-1-main.webp)

Tiny macOS floating textbox. Run saved prompts on selected text (from any app or manual input), auto-copy the result.

> [!IMPORTANT]
> Personal, opinionated, 100% AI-assisted. Use at your own risk.
>
> Built for me: global shortcut, small textbox, snappy nav, saved prompts, clipboard. That's it.
>
> macOS only. No `.app` installer or signing, you run the dev script. Local-first: settings, drafts, history, API keys all live under `~/.retypo-air/`. No telemetry.

## Why

I keep editing more of my writing through LLMs. Tried voice (Handy is installed), kept drifting back to typing: voice felt like it was sending too much noise into the model. Probably because I write better than I think out loud, and I still don't write well enough.

Other reason: typing long prompts into CLI agents like Codex or Claude Code, then losing the whole thing to a stray keystroke that wipes the input, a crash, or accidentally killing the terminal. Not undoable, gone. Retypo writes every keystroke to `draft.txt` and snapshots up to 20 paused-state versions of the draft, so the worst case is reopening the panel and picking a snapshot from Settings.

## Caveats

- macOS 13+, Swift 5.9+, Xcode CLT or Xcode.
- Selection import (`Cmd+Shift+Space` from another app) needs Accessibility permission. Grant once when prompted; pick `build-dev/RetypoAir-dev.app`.
- Terminal prompt import for Codex/Claude Code uses the terminal's accessible text buffer and is on by default.
- VS Code integrated terminal import is experimental and on by default in Settings. It briefly opens VS Code Accessible View with `Option+F2`, reads the buffer through Accessibility, then presses `Esc`.
- BYO API key (Groq, Anthropic, OpenAI, OpenRouter) **or** your existing Claude Code / Codex subscription through the signed-in CLI. See [Subscription providers](#subscription-providers-claude-code--codex).

## Quick start

```bash
cp .env.example .env       # add at least one *_API_KEY. Load order: shell env, .env in CWD, ~/.retypo-air/.env. First wins.
scripts/dev-app.sh         # builds + opens build-dev/RetypoAir-dev.app
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
- Cost tracking: last, session, today. Editable per-model pricing.
- Footer stats: WPM, changed-word delta, char count.
- Auto-correct skips short text, code fences, shell commands, symbol-heavy lines. So it never rewrites a command you're typing.

## Subscription providers (Claude Code / Codex)

Pick **Claude Code** or **Codex** as the provider and the panel shells out to the CLI you are already signed into, so runs bill your subscription instead of an API key. Nothing to configure beyond having the CLI installed and logged in (`claude`, `codex login`).

The panel launches the CLI with its own API keys stripped from the child environment — otherwise Claude Code would find `ANTHROPIC_API_KEY` and quietly bill the API instead of the subscription. It also runs in a scratch directory (no CLAUDE.md/AGENTS.md pickup), one turn only, tools disabled, and Codex sandboxed read-only at low reasoning effort.

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

Edit, rename, disable, shortcut-bind in Settings. Stored in `~/.retypo-air/modes.json`.

## External import precedence

When `Cmd+Shift+Space` from another app:

1. **AX selection**. Fast, no clipboard touched. Native macOS apps.
2. **Accessible terminal buffer**. Parses the focused terminal's visible text for Claude/Codex composer semantics.
3. **Experimental VS Code Accessible View**. Enabled by default (`experimentalVSCodeAccessibleViewImport` in `settings.json` or Settings UI). Sends `Option+F2`, reads the Accessible View, then sends `Esc`.
4. **Synthetic `Cmd+C`** via AX-pressed Copy menu. Clipboard read then restored. Terminals, TUIs.
5. **Existing clipboard**. Whatever was already copied.

If a draft already exists, asks before replacing. Failures: `~/.retypo-air/import-debug.log`.

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

## Files (`~/.retypo-air/`)

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
