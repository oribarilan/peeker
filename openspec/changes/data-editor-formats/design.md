# Design

## Context

The Data plugin (`Plugins/data/`) parses JSON into `JSONNode`s that keep byte ranges and decode lazily, shows them in `DataTreeView`, and edits them as text changes. This change adds four formats whose trees are read-only, so they need nodes for showing and for the outline's jump to a line, not ranges for editing.

## Decisions

- **One node type for every format.** `JSONNode` becomes `DataNode`. A JSON node keeps reading its key and value from the shared bytes, and builds its children lazily. A node from another parser is built whole, holding its decoded key and value and the byte offset where it starts (for the outline). The tree view and document keep one item type, and JSON's speed work stays. `Kind` gains `element` for XML elements, shown as "N children".
- **Errors.** `JSONError` becomes `SyntaxError`, made from a message and a byte offset, and every parser reports through it. A form a parser doesn't read reports "uses a form the tree can't show", so the bar doesn't call a valid file broken.
- **YAML: our own line-based reader** (maintainer, 2026-11-06: small and fast over complete). Indentation decides block structure; `- key: value` starts a mapping in a sequence item; flow collections, quoted and block scalars, comments, anchors, tags, aliases and several documents are read. Scalars resolve by the YAML 1.2 core schema (null, true/false, numbers), everything else being a string. Not read: complex keys, merge keys as merges (they show as a key named `<<`), and tabs used for indentation (an error, as in YAML).
- **TOML: our own reader**, building mutable tables first, since `[a.b]` can add to a table opened earlier, then the nodes. A key defined twice is an error. Dates and times show as written.
- **XML: our own reader rather than Foundation's `XMLParser`,** which reports attributes as an unordered dictionary, positions as line and column, and errors as numbered codes. Ours keeps attribute order and byte offsets, writes plain messages, and never loads external entities. It reads elements, attributes, text, the five named entities and numeric references, CDATA, comments, processing instructions and a doctype (skipped).
- **Property lists from the XML reader.** A file whose root element is `plist` maps `dict`, `array`, `key` and the value elements to nodes, keeping key order. A property list that isn't XML text (binary, or the old OpenStep form) is read with `PropertyListSerialization` and written back as XML, which becomes the shown text, read-only; Save As copies the original file.
- **Choosing the format.** By extension: `json`/`jsonc`, `yaml`/`yml`, `toml`, `plist`, `xml`. An `xml` file with a `plist` root is a property list. Another extension given to the plugin in Settings is chosen by its first bytes: `bplist` is a property list, `<` is XML, anything else JSON.
- **Tree editing stays JSON's.** The edit tools, double-click editing and dragging check the format; elsewhere they're unavailable with "Edit YAML in the text: View > Show Text." (the format's name changing).

## Risks / Trade-offs

- **Coverage.** The YAML reader handles what configs and manifests use; an unusual file opens in its text with the bar. That's the trade the maintainer chose.
- **Speed.** Other formats build every node at once rather than lazily. A YAML fixture in the benchmark measures it against Quick Look; if it falls behind, its nodes can turn lazy as JSON's did.
