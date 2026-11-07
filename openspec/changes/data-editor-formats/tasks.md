# Tasks

## 1. A node for every format

- [ ] 1.1 Rename `JSONNode` to `DataNode` and `JSONError` to `SyntaxError` (made from a message and byte offset); `DataNode` gains a built form holding a decoded key and value and a start offset, and `Kind.element`; the node moves to `DataNode.swift`. Existing tests pass unchanged in behavior.

## 2. Parsers

- [ ] 2.1 Failing tests, then `YAMLParser`: mappings, sequences (including `- key:` items and dashes at the key's indent), flow collections, plain, quoted and block scalars, comments, anchors, tags, aliases, documents; scalar kinds; errors with lines; complex keys report the form the tree can't show.
- [ ] 2.2 Failing tests, then `TOMLParser`: tables, arrays of tables, dotted and quoted keys, inline tables and arrays, the four string forms, numbers, booleans, dates; duplicate keys and malformed lines are errors with lines.
- [ ] 2.3 Failing tests, then `XMLReader` with the element mapping and the property list mapping: attributes in order, text, entities, CDATA, comments and doctype skipped, mismatched and unclosed tags as errors; plist dict, array and values.

## 3. Document and routing

- [ ] 3.1 Failing tests: format chosen by extension and first bytes; YAML, TOML, XML and plist open as trees; their edit tools are unavailable with the reason and double-click doesn't edit; editing their text updates the tree; a binary property list shows its XML read-only and Save As copies it.
- [ ] 3.2 Implement the format choice in `DataPlugin.load` and `DataDocument`; move `xml`, `yaml`, `yml`, `toml` from Plain Text to Data and add `plist`; readable types; routing and default extension tests updated.

## 4. Checks and docs

- [ ] 4.1 `bench/make-fixtures.swift` writes `small.yaml` and `large.yaml`; `bench/ppbench.py` times them; run `scripts/bench-ab.sh` and `ppbench.py space`.
- [ ] 4.2 Screen tests: routing cases for the new extensions; the `data-edit` flow adds Space on a YAML file and a binary property list's tree and read-only text; `run-peeker` skill updated.
- [ ] 4.3 `scripts/build.sh test` passes with no new warnings; review by the oracle before committing.
- [ ] 4.4 README, CHANGELOG, backlog (tree editing for these formats); `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; run the screen flows; archive, push and install.
