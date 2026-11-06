# Proposal

## Why

CSV and TSV files open as plain text today, so reading a column means counting commas, and changing a value means editing raw text without breaking the quoting. These are tables, and Peeker should show and edit them as tables. This is the first of the text-format splits the roadmap left open (`openspec/config.yaml`, "Text-based formats"). The maintainer settled them on 2026-11-06: CSV and TSV get an editable table, JSON/YAML/XML/TOML get a data editor next, and logs stay plain text.

## What Changes

- **A new Table plugin** (`table`) owns `csv` and `tsv` by default. Plain Text gives them up and still opens them through Open With. Like every plugin, it can be turned off or given other extensions in Settings.
- **The view:** a table with row numbers, a header row guessed from the first row, and a detected delimiter (comma, semicolon, tab or pipe; `tsv` is always tab). The View menu shows and switches the header row and the delimiter, remembered per file.
- **Editing in the Editor:**
  - edit cells (double-click or Return; Return moves down, Tab moves right, Escape cancels);
  - add, delete and move rows and columns;
  - each change is one undo step, and changes stay pending until Cmd+S.
- **Saving** keeps the delimiter, encoding, byte order mark and line endings, quotes only where needed or where the file already quoted, and writes rows that weren't changed exactly as they were. Text the encoding can't hold asks before saving as UTF-8, as Plain Text does.
- **Sorting:** clicking a column title sorts the view only, never the file.
- **Large files:** files over 50 MB open as a read-only table. Opening reads the file off the main thread and stays at least as fast as TextEdit and Quick Look.
- **The Peek panel** shows the table without editing.
- **Out of scope:** Find and Print in tables, sorting saved into the file, formulas, and column types. Find and Print go to the backlog.

## Capabilities

### New Capabilities

- `table`: showing and editing CSV and TSV files as a table.

### Modified Capabilities

- `text`: `csv` and `tsv` leave Plain Text's default list.
- `settings`: the sidebar lists a Table pane between Markdown and Plain Text.

## Impact

- **New module `Plugins/table/` (`PeekerTable`):** the plugin, a CSV reader and writer, the table document and its view. It imports only PeekerKit and Apple frameworks, and reuses PeekerKit's `TextCodec`, `TextFile` and `FileReplacement` for encodings and safe writes.
- **`project.yml`:** the new target, the app's dependencies and both test bundles.
- **The host:** `PluginCatalog.builtIn` adds `TablePlugin` before `TextPlugin`, and `TextPlugin.defaultExtensions` drops `csv` and `tsv`. The config schema and the Settings pane follow from the catalog.
- **Tests:**
  - new Swift Testing suites for parsing, delimiter and header guesses, editing, undo, saving and recovery;
  - updates to `RoutingTests`, `PluginToolsTests` and `DefaultExtensionsTests`.
- **Screen tests:** a `table-edit` flow, and routing cases for `csv` and `tsv`.
- **Benchmark:** the existing `small.csv` and `large.csv` fixtures join `bench/ppbench.py`'s files.
- **Docs:**
  - README's plugin list, CHANGELOG, the `run-peeker` skill;
  - `openspec/config.yaml`'s open question, answered;
  - `openspec/backlog.md`: the data editor (next change), and Find and Print in tables.
- **Version:** a minor bump.
