# Design

## Context

File > Open With is filled by `DocumentWindowController.fillOpenWith` from `openWithChoices` (the plugins that read the file) and enabled only when there are two or more; items carry their index as a tag and call `reopenWithMenu`. Switching a plugin resolves unsaved edits through `resolveUnsavedEdits()` (Save, Don't Save, Cancel). `DocumentWindowController.swift` is at its line ceiling (655 in `scripts/long-files.txt`).

The Peek panel already lists apps: `AppChoice` (an app's bundle ID, name and URL), `PeekOpenWithMenu.items` (default first, A to Z, without Peeker or duplicates), `listApps` through `NSWorkspace.urlsForApplications(toOpen:)`, `openInApp` through `NSWorkspace.open(_:withApplicationAt:configuration:)`, and `chooseOtherApp`, an `NSOpenPanel` sheet over `/Applications` with an optional Always checkbox. All of it is in the Host module, but the picker is private to `PeekPanel`.

## Goals / Non-Goals

**Goals:** one way of listing and opening apps for the panel and the Editor; the apps cost nothing until the menu opens; the plugin switching and its tests stay as they are.

**Non-Goals:** apps in the toolbar's Open With control; setting default apps from the Editor; watching the file for the other app's changes beyond what file watching already does.

## Decisions

- **Shared app code in `Sources/Host/App/AppChoices.swift`.** `AppChoice` moves there from `OpenWith.swift`, with `AppChoices.sorted(_:systemDefault:excluding:)` (the ordering and de-duplication `PeekOpenWithMenu.items` does today, which then calls it), `AppChoices.list(for:)`, `AppChoices.open(_:in:)` and `AppChoices.pickOther(for:on:always:completion:)` (the `NSOpenPanel` sheet; `always` is the checkbox title or nil). The panel keeps its closures for tests, now defaulting to these. Alternative: a protocol both windows adopt; more code for two callers.
- **Menu items carry their action in `representedObject`.** The plugin items keep their tags and `reopenWithMenu`; app items call `openInApp(_:)` with the `AppChoice` in `representedObject`, Other… calls `openInOtherApp(_:)`. Validation treats the new selectors as always enabled. The submenu is enabled whenever a document is showing. Each app item's icon uses the image helper from `peek-panel-title-fixes` when that change is in; otherwise it sets the image the panel's way.
- **Unsaved edits get their own question.** A new `askToOpenElsewhere` sheet ("Save changes to “notes.md” before opening it in TextEdit?") with Save, Open Without Saving and Cancel, injectable like `askToSave` for tests. Save reuses `save(_:)` and opens only once it succeeds. Open Without Saving leaves the document untouched. Alternative: reuse `resolveUnsavedEdits`; its Don't Save discards the edits, which is wrong when the window stays open.
- **The move keeps the file under its ceiling.** `fillOpenWith`, `reopenWithMenu` and the new actions go to `DocumentWindowController+OpenWith.swift`, and the ceiling in `scripts/long-files.txt` drops to the new length.

## Risks / Trade-offs

- [Launch Services can list many apps for a plain text file] → The same list the panel shows today; no change in what users see there.
- [The other app opens the file while Peeker still has it open, and saves to it] → File watching already reloads a changed file or offers to when there are unsaved edits; nothing new.
- [A screen check that File > Open With is greyed for a photo] → The flow's photo step checks the toolbar control, which stays hidden; its comment and the new menu list are updated.
