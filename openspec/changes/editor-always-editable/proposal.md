# Proposal

## Why

Peeker has two ways to look at a file: the Peek panel (Space in Finder, view-only) and a window's read view, which looks the same and needs an extra Edit step before anything can be changed. Opening a file from Peek lands in that identical read view, then asks for Edit. The maintainer decided (2026-11-02) that Peek is for viewing and a window is for working: windows are always editable, there's no read view or Edit toggle, and the words change with it.

## What Changes

- **BREAKING** Windows (the "Editor" inside the project) open every file ready to edit. The read view, the Edit button, Tools > Edit Mode and Cmd+E go away, along with "leaving Edit mode asks to save"; closing with unsaved edits still asks.
- Edit tools are in the toolbar and Tools menu from the start; their machinery loads on first use, so opening stays as fast as the old read view.
- PDF form fields fill directly in the Editor, as in Preview.
- Single-key tool shortcuts (C for Crop) work whenever the Editor is in front and no text field has the keyboard.
- A file Peeker can't edit (XFA, protected, signed or locked PDFs; images it can't write) shows its edit tools greyed out with the reason as tooltip, plus a one-line note under the toolbar.
- The Peek panel stays view-only; its button reads "Open in Peeker", so the panel can be told apart from Quick Look.
- With no edit tools (Markdown), the Tools menu shows a greyed-out No Tools item.
- **BREAKING** "Commands" become "tools" everywhere current: view tools (View menu) and edit tools (Tools menu). In code `CommandSpec` becomes `ToolSpec`; in the config `plugins.<id>.commands` becomes `plugins.<id>.tools`, and the old key is reported as unknown.
- The plugin contract's `EditMode` and `setEditing` become `Editability` (`.editable`, `.readOnly(reason)`, `.notEditable`).
- Inside the project (specs, docs, comments) the window's role is called the Editor; user-facing text keeps "Peek panel" and names no editor.
- Like the Peek panel rename, the terminology reaches user text, code, comments, specs, README, AGENTS.md, skills and screen flows; history stays as written.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `documents`: the always-editable Editor replaces the read view and Edit mode; read-only files with a reason; edits only in the Editor.
- `pdf`: tools always available and loaded on first use; forms fill directly; read-only PDFs; page tools; wording.
- `image`: image tools always available; images Peeker can't edit are read-only; wording.
- `plugin-host`: tools instead of commands; single-key shortcuts without Edit mode; the Tools menu without Edit Mode; wording.
- `routing-and-config`: the config's `tools` section; wording.
- `settings`: tools instead of commands in the plugin panes.
- `peek-panel`: the Open in Peeker button and the Editor.
- `text`, `app-presence`: wording.

## Impact

- Plugin contract (`Sources/PeekerKit/Plugin.swift`): `ToolSpec`, `tools`, `activeTool`, `Editability`; `setEditing` goes. Every plugin and test plugin follows.
- Host: `DocumentViewController` and `DocumentWindowController` lose Edit mode (toggle, Edit button, leave prompt), gain the read-only note and greyed tools; `MainMenu` loses Edit Mode and lists tools; the single-key monitor checks editability; the Peek panel's button text; config reading, rendering and schema use `tools`; Settings' plugin panes and shortcut rules follow.
- Plugins: PDF sets up its editor machinery on first use and fills forms in the Editor; image and text follow the contract.
- Tests: Edit mode tests become Editor and read-only tests; renames throughout.
- Screen flows: no Edit Mode steps; pdf-edit, pdf-pages, image-edit and recovery change accordingly.
- Docs: README, AGENTS.md, the run-peeker skill, `openspec/config.yaml` (product direction), `openspec/gaps.md`.
