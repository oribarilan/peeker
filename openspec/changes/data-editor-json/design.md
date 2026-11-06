# Design

## Context

Plain Text opens `json` and `jsonc` with syntax colors from PeekerSyntax (which already knows JSON), through its own `CodeColoring` glue. PeekerKit provides `ThemedFindTextView`, `TextTheme`, `TextCodec`/`TextFile` (encodings, the UTF-8 offer), `TextEdits` (the recovery format) and `HoverTable`. The Table plugin (2026-11-06) set the pattern for a new plugin: load and parse off the main thread in `@concurrent` code, a document that owns its undo manager, and light views.

## Goals / Non-Goals

**Goals:**
- One model, the text, so the tree and the text can never disagree, and an edit made in either is undone from either.
- Tree edits that touch only their own bytes.
- Opening as fast as plain text did.

**Non-Goals:**
- YAML, XML, property lists and TOML (next change).
- Reformatting, sorting keys, schemas.
- Moving an item to another parent by dragging.

## Decisions

### The text is the model; the tree is a parse of it

- **The model:** the document holds the file's text. The tree is rebuilt by parsing the text whenever it changes, debounced while typing, and at once after a tree edit.
- **Tree edits:** a tree edit computes a text change (a range and its replacement) and applies it through the text view: `shouldChangeText`, `replaceCharacters` and `didChangeText`. The text view's undo then holds every edit, so Undo works the same in both views.
- **The undo manager:** the text view stays in the window, hidden while the tree shows. The document gives its own `UndoManager` to both through `undoManager(for:)` and an outline-view override, as the Table plugin does.
- **Unsaved edits:** they work as Plain Text's do. The document is edited when its text differs from the text last saved, and `unsavedEdits()` is `TextEdits`.
- **Rejected:** a node model with its own undo, which would have to sync with text edits both ways.

### A JSON parser of Peeker's own, keeping places

- **What it builds:** `JSONParser` reads the UTF-8 bytes in one pass into `JSONNode`s (final classes, immutable once built and `@unchecked Sendable`, so a tree built off the main thread can be handed to the view). Each node has:
  - its kind (object, array, string, number, true, false, null);
  - its key text;
  - the byte ranges of its key and value;
  - its children.
- **What it accepts:** `//` and `/* */` comments and trailing commas, in `json` too: the 80% case of config files.
- **Errors:** an error carries a message and its byte offset, turned into a line and column for the bar.
- **Rejected:** `JSONSerialization` or `JSONDecoder`. They keep neither places nor comments, and reject JSONC.

### Text changes for tree edits

All offsets are UTF-8. A change is applied as an `NSRange` converted through the text's indices.

- **Set a value:** replace the value's range with the literal.
  - A string node gets a JSON-escaped string.
  - Any other node gets the typed text when it parses as a number, `true`, `false` or `null`, and an escaped string otherwise.
- **Rename a key:** replace the key's range with an escaped string.
- **Delete an item:** remove from the item's start (its key, or its value in an array) to its end. Also remove the comma after it, or the one before it if it's last, and its line when it had the line to itself.
- **Add an item after a sibling:** insert `,` then a line break with the sibling's indentation, then `"key": null` (a fresh key name, unique among its siblings) or `null` in an array.
- **Add a child:** into an empty `{}` or `[]`, insert the child on its own line, one indent deeper. Otherwise add it after the last child.
- **Move within the parent:** a delete and an insert, in one undo group.
- **Indentation unit:** detected from the first indented line, two spaces if there is none.

### The views

- **The tree:** an `NSOutlineView` with Key and Value columns. Containers show "3 keys" or "5 items", and array items show their index as the key.
- **Light cells:** cells are light, drawn views like the Table plugin's. A text field goes over the cell only while it's edited: double-click or Return starts an edit, Return commits, Escape cancels.
- **Moving items:** dragging reorders within the same parent.
- **Tools:**
  - View: Show Text, a switch through `isOn`.
  - Tools: Add Item, Add Child, Delete Item. Add Item shows in the toolbar.
- **The text view:** a `ThemedFindTextView` with syntax colors from a copy of Plain Text's `CodeColoring`, the second copy. The project waits for a third before sharing.
- **Errors:** a bar above the text shows the parse error.
- **The outline:** a `SidebarPanel` list of the top-level children. Clicking one selects it in the tree, or puts the cursor on its key's line in the text.
- **Remembering the view:** the tree-or-text choice is `PluginPreferences` key `showsText`.

### Limits and speed

- **The editing limit:** files over `TextLimits.editableBytes` (10 MB) are read-only, with the reason.
- **Off the main thread:** loading decodes, parses and scans syntax spans off the main thread. The outline view is lazy; children are asked for only when a node opens.
- **Measuring:** `bench/make-fixtures.swift` writes `small.json` (about 2 KB) and `large.json` (about 3 MB), and `bench/ppbench.py` times them, with TextEdit as Apple's app.

## Risks / Trade-offs

- [Re-parsing the whole text after each edit is O(file)] → About 10 ms per MB in a simple byte loop. Below the 10 MB limit that stays under a frame or two; typing in the text view is debounced.
- [Deleting or moving an item next to a comment might leave the comment behind] → The comment stays where it was; the edit never deletes text it doesn't own.
- [A JSON file with duplicate keys] → Both show in the tree; edits address the node by its place, not its name.
- [Lenient parsing accepts comments in `.json`] → Accepted deliberately; Peeker never adds or removes them.
