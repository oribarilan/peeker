# Proposal

## Why

Filling in and signing PDF forms is the most common reason the maintainer still opens Preview, and Peeker's milestone is replacing Preview for daily use. Today Peeker can only highlight text in a PDF. This change adds the first full PDF editor: form filling, text boxes and drawn signatures. It also introduces the view-mode/edit-mode split that the roadmap planned for plugins. The decisions come from the maintainer interview of 2026-10-30, recorded in `openspec/config.yaml` (roadmap item 2).

## What Changes

- **Edit mode (host).** A document can declare an edit mode. Such documents open in a read view that never changes the file; an Edit button in the window toolbar and Cmd+E switch to Edit mode, where the plugin's editing tools appear in the toolbar. Leaving Edit mode with unsaved changes asks Save / Don't Save / Cancel. Cmd+S saves without leaving. Recovered edits reopen in Edit mode. A document can say why Edit mode isn't available, and the button is then disabled with that reason. Plain Text doesn't declare an edit mode and keeps editing as it does today. The Space panel stays view-only.
- **PDF in Edit mode** gets three tools: Text Box, Sign and Highlight. **BREAKING**: Highlight Selection no longer works in the read view directly. Its shortcut (Ctrl+Cmd+H) switches to Edit mode and highlights.
- **Form filling.** The fields of a PDF form (text, checkbox, radio, choice) can be filled only in Edit mode, and their values are saved into the form, never flattened.
- **Text boxes** on any page, for flat forms. They use one system font in black with a size control, are placed by clicking, and grow as you type. They're saved as standard free-text annotations.
- **Signatures** are drawn with the trackpad or mouse in a pad, then follow the pointer until a click places them. They're saved as standard ink annotations (vector strokes). A signature is never written to disk by Peeker: the last one drawn is kept in memory until Peeker quits, so signing several pages doesn't mean redrawing.
- **Adjusting.** In Edit mode, text boxes, signatures and highlights that Peeker made can be selected, moved, resized and deleted, whether they're unsaved or were saved earlier. Annotations made by other apps are shown but not changed.
- **Undo and redo** (Cmd+Z, Cmd+Shift+Z) cover every change since the window opened, across saves.
- **PDFs that can't be edited:** XFA forms, PDFs whose permissions forbid changes or form entry, and digitally signed PDFs open in the read view with Edit disabled and the reason shown.
- **Speed:** the edit tools load only when Edit mode turns on, so opening a PDF stays as fast as today.

## Capabilities

### New Capabilities

None. Edit mode is document behavior, and the tools are PDF behavior.

### Modified Capabilities

- `documents`: documents can have a read view and an edit mode, with a host toggle, a prompt on leaving with unsaved changes, recovered edits reopening in Edit mode, and undo across saves.
- `pdf`: Highlight moves into Edit mode, and the plugin gains form filling, text boxes, drawn signatures, adjusting its own annotations, saving them as standard PDF data, and refusing to edit PDFs it can't safely change.

## Impact

- **Plugin contract** (`Sources/PeekerKit/Plugin.swift`):
  - `PluginDocument` gains an optional edit mode: whether it has one, why it's unavailable, and being told when it turns on or off.
  - `CommandSpec` gains a flag for commands that are edit-mode tools, and for ones that switch to Edit mode when used from the read view.
  - All of this is additive with defaults, so the Markdown, Image and Text plugins don't change.
- **Host** (`Sources/Host/Documents/`): the Edit toggle and Cmd+E in `DocumentWindowController` (toolbar, Commands menu), the leave-with-changes prompt using the existing save sheet, and recovery opening in Edit mode.
- **PDF plugin** (`Plugins/pdf/`):
  - Edits become a list of operations (add, change, delete an annotation; set a field) applied live to the view, and again to a fresh copy of the file on save, off the main thread.
  - It needs a selection and drag layer, text-box editing, and the signature pad.
  - The recovery encoding stays able to read today's highlight records.
- **Annotations** Peeker makes get a `/NM` name starting with `peeker-`, which is how it recognizes its own annotations later.
- **No new dependencies:** PDFKit and AppKit only.
- **Docs:** the README's PDF plugin description.
