# Design

## Context

Edit mode runs through every layer. The plugin contract (`Sources/PeekerKit/Plugin.swift`) has `EditMode` (`.available`, `.unavailable(reason)`, `.none`), `editMode` and `setEditing(_:)`. `DocumentViewController` keeps `isEditing`, toggles it (`toggleEditing`, asking to save on the way out), restores recovered edits into Edit mode, and filters edit tools out of the toolbar outside Edit mode (`showsInToolbar`). `DocumentWindowController` has the Edit button (`toggleEditMode`), the single-key monitor gated on `isEditing`, and `onEditRefused` for an unavailable Edit mode. `MainMenu` puts Edit Mode (Cmd+E) at the top of Tools. Settings' recorder rules and `shortcutConflict` reserve Cmd+E.

In the PDF plugin, `setEditing(true)` creates the `EditController` (text boxes, signatures, highlighter) and `FormFields`, flips `isEditing` on `PeekerPDFView` (which then takes clicks for tools and fields) and on `PageThumbnails` (which then allow drags), and hands the view the undo manager. That deferral is what keeps opening fast ("Edit mode doesn't slow opening"). The image plugin's `setEditing` only flips flags and hooks the undo manager. The text plugin has no edit mode: it's always editable.

"Command" is the name of plugin actions everywhere: `CommandSpec`, `Plugin.commands`, `PluginDocument.commands`, `PluginEntry.commands`, `activeCommand`, `runCommand`, `rebuildCommands`, `Shortcut.Rules.command`, the config's `plugins.<id>.commands` and its schema, Settings' shortcut list, specs and docs. The PDF document already has a property named `tools` (its `EditController`).

## Goals / Non-Goals

**Goals:**
- The behavior and terminology in this change's specs.
- Opening a PDF or image in the Editor as fast as opening it in the read view today.
- One consistent vocabulary: Peek and the Editor; view tools and edit tools; editability.

**Non-Goals:**
- Markdown editing (it stays rendered and read-only; Open With > Plain Text edits its source).
- Changing the Peek panel's behavior beyond its button's text.
- Renaming classes that name a window rather than the role (`DocumentWindowController`, `DocumentViewController`); comments say Editor.
- Rewriting history (archived changes, dated reviews, decision records, `openspec/config.yaml`'s dated roadmap entries).

## Decisions

**The contract: `ToolSpec`, `tools`, `Editability`.**
- `CommandSpec` becomes `ToolSpec` (fields unchanged: `isEditTool`, `showsInToolbar`); `Plugin.commands` and `PluginDocument.commands` become `tools`; `activeCommand`/`onActiveCommandChange` become `activeTool`/`onActiveToolChange`; `unavailableReason(for command:)` takes `tool:`; `isOn(_:)` stays.
- `EditMode` becomes `Editability` with `.editable`, `.readOnly(String)` and `.notEditable`; `editMode` becomes `editability`; `setEditing(_:)` goes. A document decides its editability when it opens (from `OpenContext.allowsEditing` and the file), and can change it only by replacing itself (as an unlocked PDF does today).
- The PDF document's own `tools` property is renamed `editController` first, so the rename doesn't collide.

**The host shows editability, it no longer toggles it.**
- `DocumentViewController` drops `isEditing`, `toggleEditing` and the leave-Edit-mode prompt; `showsInToolbar` keeps only `ToolSpec.showsInToolbar` (edit tools always show in the Editor).
- For `.readOnly(reason)`, every edit tool reports that reason as unavailable (the host answers it without asking the plugin), so menu items and buttons grey out with the reason as tooltip through the existing unavailable-tool path; an edit tool's shortcut shows the reason (the existing `onEditRefused` message).
- A one-line note under the toolbar: a small `ReadOnlyNote` view (an `NSTextField` with the reason, pinned to the content's safe-area top, as the text plugin's note already is) that `DocumentViewController` adds above the plugin's content for `.readOnly`. It takes no clicks and goes when a replacement becomes editable.
- `DocumentWindowController` drops the Edit button and `toggleEditMode`; the single-key monitor runs an edit tool when the document's editability is `.editable` and no text view has the keyboard.
- Recovered edits apply straight to the document (no Edit mode to turn on first).

**Menus and Settings.** `MainMenu` drops Edit Mode; when the front document has no edit tools (or no Editor window is in front) Tools shows a greyed-out "No Tools" item, which keeps every window's menu bar the same. `rebuildCommands` becomes `rebuildTools`, `runCommand` becomes `runTool`. `Shortcut.Rules.command` becomes `.viewTool`; Cmd+E is no longer reserved (`Shortcut.editMode` and its refusal go). Settings' plugin panes list "Tools", and the fixed-menu-key list loses Edit Mode automatically.

**The config's `tools` section.** `ConfigReader.readCommands` becomes `readTools` and reads `plugins.<id>.tools`; `commands` gets no special case, so the unknown-key path reports it. Rendering writes `tools`; the schema describes `tools` with each plugin's tool ids. `Config.keyID` and stored keys keep the `plugin.tool` shape.

**PDF: editor machinery on first use.**
- At open, an editable PDF sets `PeekerPDFView.isEditing` and `PageThumbnails.isEditing` to true and gives the view the undo manager: these are flags, no setup.
- `editController` and `FormFields` are created by a `prepareEditing()` call the first time a tool runs (`perform` of text-box, sign, highlight, page tools) or the first time the view sees a click on a widget or one of Peeker's annotations. `PeekerPDFView` asks the document through a closure, so the view stays dumb.
- Form fields: `PeekerPDFView` stops refusing widget clicks when editable (today it refuses them outside Edit mode), and the first such click prepares `FormFields` before PDFKit handles it, so the change is recorded as an edit.
- Read-only PDFs (XFA, permissions, signed, unlocked-from-password) keep `isEditing` false: fields refuse input and thumbnails don't drag, as in today's read view.
- The benchmark (`bench-ab.sh`) checks opening stays as fast; the "edit tools don't slow opening" requirement holds it.

**Image.** An editable image hooks the undo manager at open; `C` and Rotate & Resize work from the start. Read-only images use `.readOnly(reason)` with today's reasons.

**Peek panel.** Its button title becomes "Open in Peeker" (`PeekPanel.swift`). Space falls back to Quick Look for files Peeker can't read, and the button's name is how people tell the two apart; no badge, border or logo over the content. The button stays the system's plain push button: an accent tint was tried, but macOS draws tinted buttons grey in a window that isn't key, and the panel never is, since Finder keeps the keyboard. Documents opened there use `.notEditable` or a read-only state as today (`allowsEditing` false), and never show the note (the panel has no toolbar).

**Terminology pass.** After the code compiles: user text ("Open in Peeker", Settings' "Tools" heading), comments ("Editor", "tool"), README, AGENTS.md, the run-peeker skill, `openspec/config.yaml`'s Direction paragraph (it describes "a fast view mode and a full editor (Edit mode in the same tab)") and `openspec/gaps.md`. A grep for "Edit mode", "read view", "command" (in the plugin sense) and "document window" over current files checks what's left.

**Screen tests.** Every `menu Peeker Tools "Edit Mode"` step goes. pdf-edit: its "the read view ignores typing" check moves to the Peek panel (Space on the form, click the field, nothing typed); fields fill right after opening. pdf-pages: its last part (unsaved page edits, then leaving Edit mode with Don't Save) becomes closing the window with Don't Save and checking the file. image-edit: crops right after opening. recovery: the PDF comes back with its edits (no Edit mode check). A new check in pdf-edit: a digitally signed or permission-locked PDF shows greyed tools and the note (`pdf-tool` gains a `locked-permissions` fixture if needed).

## Risks / Trade-offs

- [A form field click in a freshly opened PDF now makes an edit; closing then asks to save.] → Chosen by the maintainer (like Preview).
- [Single keys (C) now act whenever an image window is in front.] → Never while a text field, text view or text box has the keyboard, and never in the Peek panel; chosen by the maintainer.
- [Preparing `FormFields` on the first widget click could miss that click's change.] → `prepareEditing()` runs before PDFKit handles the click, and a unit test types into a field right after opening.
- [Renaming `commands` breaks configs written by today's build.] → Nothing is released; the old key shows as unknown and Settings' next save writes `tools`.
- [The rename is wide (about 48 files).] → Contract and host first, then plugins, then tests, each step built and tested; terminology prose last.
