# Proposal

## Why

The Data plugin shows JSON as a tree, but YAML, TOML, XML and property lists still open as plain text, so reading a nested Kubernetes manifest, a `Cargo.toml` or an `Info.plist` means scrolling and counting indentation. The maintainer's 2026-11-06 plan puts these formats in the Data plugin as a second change: read-only trees with text editing, using small parsers of Peeker's own that favor speed over covering every corner of each format.

## What Changes

- **The Data plugin owns `yaml`, `yml`, `toml`, `xml` and `plist` by default.** Plain Text gives them up and still opens them through Open With.
- **Each format opens as a tree** with the same outline, Show Text toggle and syntax-error bar as JSON:
  - **YAML:** block and flow mappings and sequences, plain, quoted and block scalars, comments, anchors and tags (shown without their markers), aliases (shown as written), and several documents in one file (shown as items 0, 1, …). Complex keys (`? `) and other rare forms open in the text with a bar saying the tree can't show them.
  - **TOML:** tables, arrays of tables, dotted and quoted keys, inline tables and arrays, every string form, numbers, booleans and dates.
  - **XML:** each element by name; an element with only text shows the text, one with attributes or child elements opens to show `@attribute` rows, its child elements and any `#text`.
  - **Property lists:** shown as their keys and values (dictionaries, arrays, strings, numbers, booleans, dates and data), not as XML elements. A binary property list opens as a tree too; Show Text shows its XML form, read-only.
- **Editing:** these trees are read-only. Their text edits as JSON's does, and the tree follows the text. The tree's edit tools say to edit the text instead.
- **Out of scope:** editing these formats in the tree (later changes), XML namespaces beyond showing prefixed names, YAML merge keys (`<<`), and DTD or schema validation.

## Capabilities

### Modified Capabilities

- `data`: the plugin opens YAML, TOML, XML and property lists as read-only trees.
- `text`: `xml`, `yaml`, `yml` and `toml` leave Plain Text's default list.

## Impact

- **`Plugins/data/`:**
  - the node type becomes format-neutral (`DataNode`), with JSON's lazy nodes beside fully built ones;
  - new parsers for YAML, TOML and XML, with property lists read from the XML;
  - the document picks a format from the extension and the first bytes, and turns tree editing off for every format but JSON.
- **The host:** none. `TextPlugin.defaultExtensions` drops `xml`, `yaml`, `yml` and `toml`; `DataPlugin` adds them and `plist`.
- **Tests:** a Swift Testing suite per parser; document tests for format detection, read-only trees and binary property lists; routing and default extension tests updated.
- **Screen tests:** the `data-edit` flow adds a YAML file in the Peek panel and a binary property list in the Editor; routing cases for the new extensions.
- **Benchmark:** a YAML fixture joins `bench/ppbench.py`.
- **Docs:** README, CHANGELOG, backlog. Minor version bump.
