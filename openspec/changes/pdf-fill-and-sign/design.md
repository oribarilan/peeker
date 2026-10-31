# Design

## Context

See proposal.md for why; the decisions are in `openspec/config.yaml` (roadmap item 2). What exists:

- **The PDF plugin's model** (`Plugins/pdf/`): `PDFPluginDocument` wraps a `PDFView`.
  - Highlight Selection adds `Highlight` values to a pending list and shows them as annotations in the view's document.
  - `save` hands that list to `PDFPlugin.write`, which opens a fresh copy of the file off the main thread, adds the annotations, and writes `dataRepresentation()` through `FileReplacement`.
  - Recovery encodes the list as `PDFEdits.pdfHighlights`, the shape old records use.
- **The host** (`Sources/Host/Documents/`):
  - `DocumentViewController` owns edited state, saving, the recovery journal, and the document's commands with their shortcuts.
  - `DocumentWindowController` builds the toolbar (Open With, flexible space, one button per command) and the save and close prompts. Its `resolveUnsavedEdits()` asks Save / Don't Save / Cancel.
  - The Commands menu is rebuilt from the key document's commands.
- **The contract** (`Sources/PeekerKit/Plugin.swift`): `PluginDocument` has commands, `perform(_:)`, `onEdit`, `unsavedEdits()`, `restore(encoded:)`, `save(_:accepting:)` and `revertEdits()`. `OpenContext.allowsEditing` is false in the Space panel.
- **What PDFKit gives:**
  - Form widgets with `fieldName`, `widgetStringValue` and `buttonWidgetState`, plus `isReadOnly`.
  - Free-text and ink annotations (`add(_ path:)`), and the `/NM` key (`PDFAnnotationKey.name`).
  - `allowsDocumentChanges`, `allowsCommenting` and `allowsFormFieldEntry` on `PDFDocument`.
  - A `PDFView` lets the user type into form fields at any time. It has no in-place editing for free-text annotations and no XFA support.

## Goals / Non-Goals

**Goals:**
- An additive host edit mode any plugin can opt into, with the PDF plugin as the first user.
- One edit model for every PDF change, which shows live, saves to a fresh copy, recovers after a crash, and undoes.
- Nothing added to the open path: the read view costs what it costs today.

**Non-Goals:**
- Notes, shapes, underline and strikethrough. The interview deferred them.
- Storing signatures, typed or imported signatures, and digital (cryptographic) signing.
- Editing other apps' annotations, flattening forms, and filling XFA forms.
- A configurable Cmd+E, and plugin-supplied toolbar controls beyond command buttons.

## Decisions

### 1. Contract: an optional edit mode, and commands marked as editing tools

Add to `PluginDocument`, each with a default:

```swift
/// .none: no edit mode, edits allowed whenever the window allows them (today's behavior).
var editMode: EditMode { get }          // default .none
func setEditing(_ on: Bool)             // default no-op
```

`EditMode` is `.none`, `.available`, or `.unavailable(reason: String)`. Add `isEditTool: Bool = false` to `CommandSpec`. In a view-only context (the Space panel) a document reports `.none` and leaves its edit tools out of `commands`, as the PDF plugin already drops Highlight there.

*Alternatives:* a separate `EditablePluginDocument` protocol, rejected because a capability check through a cast is harder to follow than a property with a default; a per-plugin toggle drawn inside the plugin's view, rejected in the interview because the next editor would repeat it.

### 2. Host: the toggle, the prompt, and recovery

`DocumentViewController` keeps `isEditing`, which starts false for a document with an edit mode. The rules:

- **Toolbar.** `DocumentWindowController` adds an Edit item after Open With: a toggle button (SF Symbol `pencil.tip.crop.circle`). It's disabled with the reason as its tooltip when the document reports `.unavailable`. Edit tools are left out of the toolbar while not editing.
- **Menu.** The Commands menu gets a host item, Edit Mode (Cmd+E, checked while on), above the plugin's commands. Edit tools stay listed there in both modes, so their shortcuts work from the read view.
- **Running a tool from the read view** turns Edit mode on first, then runs it. If Edit mode is unavailable, it shows the reason in a sheet instead.
- **Turning it off** with unsaved edits goes through `resolveUnsavedEdits()`, the existing Save / Don't Save / Cancel sheet. Save or Don't Save then calls `setEditing(false)`; Cancel leaves it on. Cmd+S never changes the mode.
- **Recovery.** For a recovered record on a document with an edit mode, the host turns Edit mode on before calling `restore(encoded:)`.
- **Text documents** (`.none`) show no Edit item and run as today.

### 3. PDF edits are a list of named operations

Every PDF change becomes a `PDFEdit` (Codable):

- `.add(PDFMark)`: a highlight, text box or signature with a new `id`.
- `.setBounds(id, page, rect)`: a move or resize.
- `.setText(id, text, fontSize)`
- `.delete(id)`
- `.field(name, FieldValue)`, where `FieldValue` is text, checked or a choice.

`id` is the annotation's `/NM`, `peeker-<UUID>`. Peeker treats an annotation as its own exactly when its `/NM` starts with `peeker-`, which is how saved ones stay adjustable and other apps' annotations stay untouched.

The pending list is kept short by folding: a move or text change of an unsaved mark rewrites its `.add`, deleting an unsaved mark drops its `.add`, and a newer value for a field replaces the older one. Each edit is applied twice. Live, it changes the view's document at once. On save, `PDFPlugin.write(_ edits:to:)` opens a fresh copy off the main thread, applies the list in order, and fails without writing if a target page, annotation or field is missing or a value is invalid, naming the edit. Then it writes through `FileReplacement`, as highlights do today. After a save, the edits that were written leave the pending list by identity, so edits made during the save stay pending.

`PDFEdits` gains `.operations([PDFEdit])`. `.pdfHighlights` still decodes, into `.add` operations with new ids, so old recovery records restore.

*As built:* `.setBounds` and `.delete` also carry the mark's type and page, and `.setText` the fitted bounds, so a failed save can name what's missing ("the signature to move on page 1 is no longer in …") without searching every page. A field value is the string PDFKit reports (`widgetStringValue`): the text, the choice, or a button's on-state name. Pending edits are numbered, and the snapshot a save receives carries the last number, so the save drops exactly what it wrote; a move made during a save stays a move instead of re-adding the mark.

*Alternative:* saving the view's own `PDFDocument`. Rejected: it's shared with the view on the main thread, so it can't be serialized off it safely. A list of operations also gives recovery and "Save Anyway" onto a file changed by another app for free.

### 4. A `PDFView` subclass guards the read view and hosts the editing layer

`PeekerPDFView` overrides `mouseDown(with:)`:

- **In the read view**, a click on a widget annotation is swallowed, so fields can't change, and everything else (text selection, links) goes to `super`. This costs nothing at open, unlike marking every widget read-only, which would touch every page of a 2,000-page PDF.
- **In Edit mode**, clicks go to an `EditController` the document creates on the first `setEditing(true)`. That's where the editing objects load lazily.

The `EditController` handles:

- **Tools.** The current tool is none, text box, or placing a signature.
- **Selection.** Hit-testing considers Peeker's own highlight, free-text and ink annotations only, and the selection draws an overlay with corner handles placed through `convert(_:from:)`.
- **Dragging** moves or resizes, and records one `.setBounds` per drag.
- **Delete** records `.delete`.

Resizing a highlight or text box changes its bounds (a text box's text then wraps). Resizing a signature rescales its strokes and rebuilds the ink annotation under the same `/NM`.

### 5. Form fields

When Edit mode first turns on, the controller snapshots the value of every widget on the pages viewed so far, plus each page as it's shown. After each widget interaction, it compares the affected field with its snapshot and records a `.field` edit. The interactions are an annotation hit for buttons and choices, and the end of text editing for text fields. Radio buttons record the group's chosen state. On save, the value is set on every widget sharing the field name in the fresh copy. The form is never flattened.

*As built:* a text field is also read from PDFKit's field editor on each `NSText` change while it's the clicked field, so the document shows as edited while typing, whatever PDFKit does about committing. Whether PDFKit's editor posts those notifications is checked in the built app (task 3.1).

### 6. Text boxes

With Text Box chosen, a click opens a borderless `NSTextView` overlay at that point on the page, with a small size control beside it (− 12 pt +, sizes 8 to 36). Ending the edit (a click outside, Escape, or switching tools) commits a free-text annotation:

- Helvetica at that size, black text. *As built:* not the system font, whose PDF name (`.AppleSystemUIFont`) means nothing outside macOS; every PDF app has Helvetica. PDFKit writes the size into `/DA` as a malformed name and reads 12 pt back, so the size is also kept in the standard `/DS` style string, read back when a saved box is edited or moved.
- clear background, no border
- bounds fitted to the text

That gives an `.add`, or a `.setText` when you double-click an existing box. A box left empty is removed.

### 7. Signatures

Sign opens a sheet with a drawing canvas: an `NSView` that records mouse and trackpad strokes, smoothed by sampling. It has Clear, Cancel and Done, plus Use Last Signature when one exists this session. The strokes are normalized to 0…1 and kept in `SignatureMemory.last`, a static in the plugin that lives only as long as the process. Nothing is written anywhere.

After Done, a translucent copy follows the pointer until a click places it, at about 180 pt wide with its aspect ratio kept. It becomes an ink annotation of black 1.5 pt strokes, built with `add(_ path:)` in annotation space.

### 8. Undo

The plugin registers every change with the view's window `undoManager`, each with the inverse change (`.add` against `.delete`, old bounds, old text, old field value). Applying an inverse records a new pending edit, so undoing a saved change makes the document edited again. The history lives with the window, so it spans saves. `revertEdits()` (Don't Save) removes all of the document's undo actions.

### 9. Refusing to edit

`PDFPlugin.check`, which already reads the file with CoreGraphics off the main thread, also reads the catalog's `AcroForm` dictionary: an `XFA` entry means XFA, and `SigFlags` bit 1 means the file carries signatures. After loading, `PDFDocument.allowsDocumentChanges`, `allowsCommenting` and `allowsFormFieldEntry` cover permissions. The first reason found becomes `.unavailable(reason:)`, with the spec's wording. Reading two catalog keys adds nothing measurable to the open path.

*As built:* Edit mode needs `allowsCommenting` and `allowsFormFieldEntry` only. Everything it does is a comment or a form entry, and many fillable forms forbid "changes" to the pages while allowing both; requiring `allowsDocumentChanges` would refuse exactly the forms this feature is for.

### 10. Files

- `Plugins/pdf/`:
  - `PDFPlugin.swift`: the checks, plus writing edits.
  - `PDFPluginDocument.swift`: the edit model and the contract.
  - `PDFEdit.swift`: operations, folding, Codable, and the legacy decode.
  - `PeekerPDFView.swift`
  - `EditController.swift`: tools, selection, dragging, undo.
  - `TextBoxEditor.swift`
  - `SignaturePad.swift`
  - `FormFields.swift`: snapshots and diffs.
- Host: `DocumentViewController` and `DocumentWindowController`, plus the additions in `PeekerKit/Plugin.swift`.

Each file stays under about 300 lines.

## Risks / Trade-offs

- [PDFKit gives no direct notice when a form field's value changes] → Compare against a snapshot after each widget interaction (decision 5), and test with a fixture form covering text, checkbox, radio and choice fields. If text-field edits can't be caught reliably, stop and bring it to the maintainer before working around it.
- [Free-text annotations look different across apps (font substitution, padding)] → Use the system font, which Preview renders natively, check the saved file in Preview during the build, and record any differences.
- [Rebuilding a resized signature's ink annotation could lose the `/NM`, or its place in the page's annotation order] → Keep the `/NM` explicitly and test that move, resize and save keep it, and that Preview still shows one annotation.
- [Highlight shortcut users lose the one-step read-view highlight] → It's still one step: the shortcut turns Edit mode on and highlights (spec requirement).
- [Undo spanning saves can surprise, since undoing turns the file back to edited] → That's the decided behavior, like Preview. The edited mark shows it.
- [A widget-click guard in the read view might also swallow link clicks on widgets] → Only widget annotations are guarded. Links are a different annotation type, and a test covers clicking a link in the read view.
- [PDFKit rewrites any button field it touches with a single appearance image and writes `/V` as a string, so a checkbox or radio group changed in Peeker keeps its value in PDFKit apps (Preview included) but loses its on/off appearance states for other apps] → Found while building; Preview writes through the same PDFKit code. Text and choice fields keep their structure. Fixing it would mean writing field values as an incremental update ourselves, a change of its own.
- [PDFKit writes the Mac user's name as the author (`/T`) of each annotation Peeker adds, as Preview does] → Left as PDFKit does it; worth a maintainer decision if it matters.
- [The open path regresses] → The edit objects are created on the first `setEditing(true)`, and `bench-ab.sh` is run against `main` (spec requirement).

## Migration Plan

None for users. Old recovery records with highlights decode into the new operations. Plugins without an edit mode keep the default `.none`, so Markdown, Image and Text compile and behave unchanged.
