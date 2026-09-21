# Changelog

All notable changes to Retypo Air are documented here.
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

### Changed
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
