# Proposal

## Why

JSON files open as colored text, so finding a value in a nested file means scrolling and counting braces, and changing one risks a missing comma. The maintainer settled the text-format split on 2026-11-06 (`openspec/config.yaml`): structured data gets an editor of its own, opening as a collapsible tree with an outline, with the text one toggle away. JSON comes first, with editing in the tree; YAML, XML, property lists and TOML follow in a second change as read-only trees.

## What Changes

- **A new Data plugin** (`data`) owns `json` and `jsonc` by default. Plain Text gives them up and still opens them through Open With.
- **The tree:** a collapsible tree of keys and values, with the first level open. Comments and trailing commas are accepted, as in JSONC and many config files.
- **Tree or text:** View > Show Text switches to the file's text, colored and editable, and back. Peeker remembers the choice for every data file.
- **Outline:** the sidebar lists the top-level keys (or items), and clicking one goes to it in the tree or the text.
- **Syntax errors:** a file that doesn't parse opens in the text view, under a bar naming the line and the problem. The tree comes back once the text parses.
- **Editing in the tree** (Editor only):
  - edit values and rename keys;
  - add an item after the selection, or a child to an object or array;
  - delete items, and move them within their parent by dragging;
  - each change is one undo step, shared with the text view's undo, and changes stay pending until Cmd+S.
- **Saving:** a tree edit changes only its own part of the text, so formatting, comments and the order of everything else stay as they were. Saving keeps the file's encoding and line endings, and offers UTF-8 when needed, as Plain Text does.
- **Limits:** files over 10 MB open read-only, as text files do. The Peek panel shows the tree without editing.
- **Out of scope:** YAML, XML, property lists and TOML (the next change), formatting or minifying a whole file, sorting keys, and JSON Schema validation.

## Capabilities

### New Capabilities

- `data`: showing structured data as a tree with an outline, switching to its text, and editing JSON in the tree.

### Modified Capabilities

- `text`: `json` and `jsonc` leave Plain Text's default list.
- `settings`: the sidebar lists a Data pane between Table and Plain Text.

## Impact

- **New module `Plugins/data/` (`PeekerData`):**
  - a JSON parser that keeps each key's and value's place in the text;
  - tree edits as text changes;
  - the document, the outline view and the text view;
  - a copy of Plain Text's coloring glue, the second copy of it.
- **Dependencies:** it imports PeekerKit, PeekerSyntax and Apple frameworks; no new ones.
- **The host and build:**
  - `project.yml` adds the target;
  - `PluginCatalog.builtIn` adds `DataPlugin` after `TablePlugin`;
  - `TextPlugin.defaultExtensions` drops `json` and `jsonc`;
  - `scripts/check-plugin-imports.sh` lets `data` import PeekerSyntax.
- **Tests:** Swift Testing suites for parsing, edits, the document and the view; updates to the routing, extension and tool tests.
- **Screen tests:** a `data-edit` flow, and routing cases for `json` and `jsonc`.
- **Benchmark:** JSON fixtures join `bench/ppbench.py`.
- **Docs:** README, CHANGELOG, the `run-peeker` skill and the backlog. Minor version bump.
