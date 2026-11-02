# Proposal

## Why

The design review (`docs/design-review-2026-11-01.md`) found rough edges in Settings: it always opens on General, its zoom button is live, the add-extension field is a blank box, all four plugin panes share one icon, the Space feature goes by four names, Permissions also holds Open at Login and the Default app list, and a refused shortcut's reason vanishes after three seconds without VoiceOver hearing it. This change fixes S1 to S6 and A2, the Settings theme agreed with the maintainer.

## What Changes

- Settings reopens on the pane last shown, across launches (S1). Its window keeps resizing but its zoom button is disabled (S2).
- The add-extension field shows "Add an extension" as its placeholder (S3).
- Each plugin names a symbol for its Settings pane: Image a photo, PDF a rich-text page, Markdown a number sign, Plain Text a plain-text page; plugins that name none get a default (S4).
- **BREAKING** The feature is called the Peek panel everywhere current: Settings, the menu bar icon's menu, alerts, README, docs, agent skills, AGENTS.md, comments, code and specs. The config key `quickLook` becomes `peekPanel`, and an old `quickLook` key is reported as unknown like any other. The spec capability `quick-look-panel` becomes `peek-panel`, and the code folder `Sources/Host/QuickLook` becomes `Sources/Host/PeekPanel`. Finder's own Quick Look keeps its name where it's meant. Archived changes, the dated reviews and decision records stay as written (S5).
- Open at Login and the Default app list move from Permissions to General, which then reads Peek panel, Open at Login, Default app, Updates; Permissions keeps Accessibility and Control Finder (S6).
- When the shortcut recorder refuses a key, VoiceOver announces the reason, and the reason stays on screen until the next recording (A2).

## Capabilities

### New Capabilities

- `peek-panel`: the Peek panel (Space on a file in Finder shows it in Peeker's floating panel), taking over every requirement of `quick-look-panel` under the new name, with the `peekPanel` config key.

### Modified Capabilities

- `quick-look-panel`: every requirement removed, moved to `peek-panel`; the capability is retired.
- `settings`: the sidebar remembers its pane, shows each plugin's icon and disables zoom; General takes the Peek panel key, Open at Login and Default app; Permissions keeps only what the Peek panel needs; the extension field's placeholder; the recorder's refusal announced and kept.
- `routing-and-config`: the config key is `peekPanel`; wording in the requirements that name the panel.
- `app-presence`: the menu bar icon's Accessibility line names the Peek panel; wording.
- `plugin-host`, `documents`, `image`, `pdf`: wording only, in requirements that name the Space panel or quick-look panel.

## Impact

- Host: `Sources/Host/Settings/` (window, sidebar, General, Permissions, extension field, recorder), `Sources/Host/App/` (config key and schema, menu bar icon, app delegate, shortcut rules), `Sources/Host/QuickLook/` renamed to `Sources/Host/PeekPanel/` with its types.
- Plugin contract: an optional `symbol` on `Plugin` in `Sources/PeekerKit/Plugin.swift`, with a default; each built-in plugin names one.
- Config: `peekPanel` replaces `quickLook` in `config.json` and `schema.json`. Settings writes the new key; a hand-written `quickLook` is an unknown-key problem.
- Tests: config, schema, Settings logic, hotkey and test-support code follow the rename; new tests for the remembered pane, plugin symbols, the zoom button, the placeholder and the recorder's refusal.
- Screen flows: `record-flows.sh` checks the Peek panel wording, the remembered pane, General's Open at Login and Default app, and the placeholder; flows that write `quickLook` write `peekPanel`.
- Docs: README, BENCHMARKS.md wording, AGENTS.md, the run-peeker skill, `openspec/config.yaml`, `openspec/gaps.md`, bench scripts' comments. Benchmark metric ids stay as they are.
