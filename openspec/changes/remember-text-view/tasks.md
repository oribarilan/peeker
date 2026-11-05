# Tasks

## 1. The store

- [x] 1.1 Write failing tests: `PluginPreferences` prefixes keys with the plugin id and reads back doubles and bools, absent values are nil; `OpenContext` without preferences has none; the host's open context carries the app's.
- [x] 1.2 Add `Sources/PeekerKit/PluginPreferences.swift`, `OpenContext.preferences` (default nil) and pass it from `DocumentViewController`; verify the tests pass.

## 2. The plugins

- [x] 2.1 Write failing tests for plain text: a zoom and a wrap change are stored and the next document opens with them; a stored size out of range is ignored; Actual Size goes to 12 and stores it; without preferences nothing is stored.
- [x] 2.2 Implement them in `TextPlugin` and `TextDocument`.
- [x] 2.3 The same for Markdown's text size in `MarkdownPlugin` and `MarkdownEditor`.

## 3. Checks and docs

- [x] 3.1 Run `scripts/build.sh test`; verify everything passes with no new warnings.
- [ ] 3.2 Screen: zoom and unwrap a text file, quit, relaunch and open another; check it opens the same way (a step in the viewer flow).
- [ ] 3.3 CHANGELOG line, the backlog's T2 line removed, the design review's T2 marked fixed; `openspec validate --all --strict`.

## Workflow follow-up

- Commit the change, then bump the minor version in its own commit; archive.
