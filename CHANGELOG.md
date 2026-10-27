# Changelog

All notable changes to Retypo are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- Header mode picker on `Cmd+D`: pill row for switching modes, add/edit/delete
  modes, and per-mode shortcut recording that rejects duplicates with the
  owner's name.
- Preset themes: Monokai, Tokyo Night, Catppuccin — alongside Light, Dark,
  and System.
- Window opacity slider (50–100%) and an editor font color picker (Auto by
  default).
- models.dev pricing fetch backfills missing model prices when refreshing
  models.
- Smart paste from clipboard: global-hotkey and terminal imports are staged,
  the header dot lights up, and the smart-paste shortcut (`Cmd+Shift+V` by
  default) or a click on the dot pastes them. Nothing is ever pasted
  automatically.
- "Follow active display": the panel opens on the display holding the app you
  are working in, falling back to the mouse position.
- Editable system prompt in Settings: replaces the built-in rewrite posture,
  with one-click Reset. The mode instruction and output format stay appended.
- Live translation (experimental, off by default): translates the input as
  you type into a card below the editor — one target language at a time with
  a quick switcher, debounced ~700ms, preview only (never touches the input).
  Engine picker: Auto (Apple on-device where available, LLM fallback),
  Apple, or your LLM model.
- Enhanced modes: switch **Enhanced** on in the mode editor, attach files or
  folders (button or drag from Finder) and optionally web search. Up to ~60k
  characters go whole with every run on any provider; larger sources are
  researched with read-only `list_files` / `search_files` / `read_file`
  tools (Anthropic API), or with Claude Code's and Codex's own read-only
  tools. On the Anthropic API every path is confined to what was attached;
  Claude Code reads only the attached folders and per-run copies of
  attached files; Codex reads with its read-only sandbox (any file), so it
  gets no web search. Web search costs are added to the cost readout. PDF,
  Word, RTF and ODT text is extracted.
- Each Claude Code / Codex run starts in its own empty folder instead of the
  shared temporary directory, and Claude Code runs keep no session
  transcript (`--no-session-persistence`).
- Standard editing shortcuts (`Cmd+C/V/X/A/Z`, `Shift+Cmd+Z`) in every text
  field: the mode prompt editor, mode names, Settings and the Freeform prompt.
  The app now has a real Edit menu; only the main editor handled them before.
- The mode prompt box in `Cmd+D` resizes like a textarea: drag the corner grip.
  The height is remembered, and the panel grows (upward when docked low) once
  the editor below reaches its minimum.

### Changed
- Renamed Retypo Air to Retypo: app, Swift package, bundle id
  (`app.retypo.dev`), and data directory. The first launch moves
  `~/.retypo-air/` to `~/.retypo/` and leaves a symlink at the old path.
  macOS asks for Accessibility permission again because the bundle id changed.
- Settings slimmed to an opinionated minimum: editor layout picker, auto-run,
  hide-after-copy, and the import debounce are gone.
- Solid light/dark palettes replace translucency; panels get their appearance
  from the theme (Light/Dark/System map to system appearance).
- Footer simplified: no mode/model echo, no layout or auto toggles, no
  candidates button.
- History is a single whole-list accordion in Settings, collapsed by default.
- `Cmd+D` only ever shows/hides the header picker; runs and the candidates
  flow no longer touch it, and the pill row follows mode shortcuts.
- Single runs no longer pop the candidates overlay; run-all still does.
- Detected imports with smart paste disabled go straight into the editor,
  since there is no dot or shortcut to paste them with.

### Fixed
- Live translation now shows the text as it stands *after* a mode is
  applied: it holds back while a run is in flight and re-translates the
  resulting editor text instead of the pre-mode draft.
- Live translation: the Apple engine no longer spins forever when the system
  session stalls — jobs resolve exactly once (session, timeout, or cleanup)
  and Auto falls back to the LLM. The session gets an explicit language pair
  (source detected via NaturalLanguage), and a missing language pack now
  fails fast with an actionable message instead of blocking on a download UI.
- Question-shaped input is rewritten instead of answered: the system prompt
  now frames text as content to edit (never a message to reply to), and the
  payload is wrapped as "Text to edit:" on every request.
- Auxiliary panels hide when Retypo loses focus.
- The shortcut-capture error state clears when switching modes.
- Imports reset the candidates overlay through the panel host, so a stale
  candidates window can no longer stay on screen.
- Re-activating the window while the mode picker is open no longer steals
  focus from it.
- The legacy "lighter" theme setting persists as Light.

### Removed
- Paste-confirmation modal and pending-import preview.
- Auto-paste on external import.
- Visual-effect blur views.
