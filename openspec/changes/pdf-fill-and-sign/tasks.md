# Tasks

## 1. Host edit mode

- [x] 1.1 Add `EditMode` (`.none`, `.available`, `.unavailable(reason:)`), `PluginDocument.editMode` and `setEditing(_:)` with defaults, and `CommandSpec.isEditTool` (default false) to `Sources/PeekerKit/Plugin.swift`; verify `scripts/build.sh test` passes with Markdown, Image and Text unchanged
- [x] 1.2 In `DocumentViewController`, keep `isEditing` (false at open for an edit-mode document), pass changes to `setEditing`, leave edit tools out of the toolbar's command list while not editing, and run an edit tool from the read view by turning Edit mode on first (or reporting the reason when unavailable); verify with tests using a stub document: tools hidden then shown, a tool run from the read view turns Edit mode on, an unavailable document refuses with its reason, a `.none` document behaves as before
- [x] 1.3 Add the Edit toggle to the window toolbar after Open With (disabled with the reason as tooltip when unavailable) and Edit Mode (Cmd+E, checked while on) at the top of the Commands menu; verify with a test that the Commands menu lists Edit Mode only for edit-mode documents, and in the built app that Cmd+E toggles the toolbar tools on a PDF
- [x] 1.4 Turning Edit mode off with unsaved edits goes through `resolveUnsavedEdits()` (Save / Don't Save / Cancel); Cancel stays in Edit mode; Cmd+S keeps the mode; verify with tests for each answer
- [x] 1.5 Reopen recovered edits in Edit mode: turn it on before `restore(encoded:)` for edit-mode documents; verify with a recovery test that a restored edit-mode document is editing and edited

## 2. PDF edit model

- [x] 2.1 Add `PDFEdit` (`.add(PDFMark)`, `.setBounds`, `.setText`, `.delete`, `.field`) with `peeker-<UUID>` ids, folding (moves and text changes rewrite an unsaved `.add`, deleting an unsaved mark drops it, a newer field value replaces the older), Codable as `PDFEdits.operations`, and `.pdfHighlights` still decoding into `.add` operations; verify with tests for each fold, a round trip, and decoding a recorded old-format highlight record
- [x] 2.2 Replace `PDFPlugin.write(_ highlights:)` with `write(_ edits:to:)`: apply the list in order to a fresh copy (annotations get their `/NM`), fail without writing and name the edit when a page, annotation or field is missing or a value is invalid; verify with tests on generated PDFs that each operation lands (read back with PDFKit: types, bounds, `/NM`, free-text contents and font size, ink paths, field values) and that a `.setBounds` on a missing annotation writes nothing
- [x] 2.3 Rework `PDFPluginDocument` around the pending list: apply each edit live, save and drop saved edits by identity, `revertEdits` removes unsaved marks and restores changed ones, `restore(encoded:)` reapplies; keep Highlight working as an edit tool (`isEditTool`); verify the existing PDF plugin tests pass and add one that edits made during a save stay pending

## 3. Form fields (the riskiest part, early)

- [x] 3.1 Add a fixture form generator for tests (a PDF with text, checkbox, radio and choice fields) and `FormFields`: snapshot values for viewed pages, detect a change after a widget interaction, and record `.field` edits; verify with tests that setting each widget type's value programmatically and running the check records the right edit, then check in the built app that typing into a text field and ticking a box are recorded; if text-field edits can't be caught, stop and report before working around it
- [x] 3.2 Add `PeekerPDFView`, which swallows clicks on widget annotations in the read view and passes everything else on; verify with a test that a click on a widget in the read view changes nothing and a click on a link annotation still reaches the view, and in the built app that the read view doesn't accept field input
- [x] 3.3 Save field values into the form without flattening; verify with a test that the saved file's widgets hold the values and are still widgets, and in the built app that Preview shows them and can still change them

## 4. Refusing to edit

- [x] 4.1 In `PDFPlugin.check`, read the catalog's `AcroForm` for `XFA` and `SigFlags` bit 1, and after loading check `allowsDocumentChanges`, `allowsCommenting` and `allowsFormFieldEntry`; report `.unavailable(reason:)` with the spec's wording; verify with tests on hand-built PDFs for XFA, signed and restricted files, and that ordinary PDFs report `.available` (`.none` in the Space panel)

## 5. Adjusting and undo

- [x] 5.1 Add `EditController`, created on the first `setEditing(true)`: hit-test only Peeker's own annotations (`/NM` prefix), draw the selection with corner handles, move and resize by dragging (one `.setBounds` per drag; signatures rescale their strokes and keep their `/NM`), Delete removes; verify with tests for hit-testing (own vs other apps' annotations) and the bounds math, and in the built app on unsaved and saved marks
- [x] 5.2 Register every change with the window's undo manager with its inverse (applying an inverse records a new pending edit), across saves; `revertEdits` clears the document's undo actions; verify with tests: undo after save makes the document edited, redo reapplies, Don't Save clears the history

## 6. Text boxes

- [x] 6.1 Add `TextBoxEditor`: Text Box tool, a click opens an overlay text view with a size control (8 to 36 pt), ending the edit commits a free-text annotation (system font, black, clear background, no border, fitted bounds), double-click edits the text, an empty box is removed; verify with tests for the committed annotation's properties and fitted bounds, and in the built app by filling a scanned-style form and checking the saved file in Preview

## 7. Signatures

- [x] 7.1 Add `SignaturePad`: a sheet with a stroke canvas, Clear, Cancel, Done and Use Last Signature, strokes normalized and kept only in `SignatureMemory.last` for the process; verify with tests for stroke normalization and that nothing is written to disk (no files created under the home folder or Application Support during a signing test)
- [x] 7.2 Place a signature: a translucent copy follows the pointer and a click creates an ink annotation (black 1.5 pt strokes, about 180 pt wide, aspect kept); verify with a test for the built annotation's paths and bounds, and in the built app by signing two pages with one drawing and checking the saved file in Preview

## 8. Docs and checks

- [x] 8.1 Update the README's PDF plugin description (Edit mode, Cmd+E, forms, text boxes, signing, what can't be edited) and the run-peeker skill with a PDF editing flow (Edit mode, fill a field, place a text box, save, check the saved annotations); verify the README tests pass and the flow's checks pass on an unlocked screen
- [x] 8.2 Run `scripts/build.sh test` (no new warnings), `scripts/check-plugin-imports.sh`, `openspec validate --all --strict` and `scripts/bench-ab.sh main`; verify no PDF open time regresses past the gate

## Workflow follow-up

- Archive `settings-window` before this change, as both touch the host's document windows and menus.
- After archiving, update the roadmap in `openspec/config.yaml` (PDF fill, sign and annotate done; page operations and image editing next).
