# Tasks

## 1. Default App in each format pane

- [x] 1.1 Write failing tests in `Tests/SettingsLogicTests.swift` (the `DefaultAppSummaries` suite) for the new summary: one app named (Peeker or another), several apps, can't set; extensions without a type ignored in the count; a settable type with no app counted as "No app"; whether the row expands (several apps, or any extension can't be set).
- [x] 1.2 Change `DefaultAppSummary` in `Sources/Host/Settings/DefaultApps.swift` to the new cases and verify the 1.1 tests pass.
- [x] 1.3 Turn `DefaultAppSection` into a section for one plugin titled Default App: "Opens in <app>" or "Several apps", Make Default unless the one app is Peeker, rows per extension when it expands, the Get Info footer. Refresh on appear, on window key and when the plugin's effective extensions change.
- [ ] 1.4 Put the section in `PluginPane` after Extensions, outside the disabled group, and leave it out while the plugin is off. Remove it from `GeneralPane`. Verify `scripts/build.sh` builds with no warnings and, in the built app, the PDF pane shows the section and General doesn't.

## 2. Format wording

- [x] 2.1 Write failing tests for the config problems: an extension in two lists says it belongs to the Markdown format, an unknown id says there's no format with that id. Change the strings in `Sources/Host/App/Config.swift` and the descriptions in `ConfigSchema.swift`, and verify the tests pass and no `schema.json` description says "plugin".
- [x] 2.2 Change the sidebar heading to Formats, the toggle to "Open <Name> files in Peeker" and its footer, both Open in Editor buttons to Open in Text Editor, and the Appearance footer to "format panes".
- [x] 2.3 Change the no-plugin alert in `AppDelegate.swift` and the recovery messages in `RecoveryRestore.swift` to "Peeker doesn't open …", suggesting a format in Settings. Verify with `grep -rn '"[^"]*plugin' Sources/Host` that no user-facing string still says "plugin".
- [x] 2.4 Update `docs/config.md`: each entry under `plugins` is a format in Settings, the `enabled` line says format, and Settings > Open in Text Editor.

## 3. Screen flows and wrap-up

- [ ] 3.1 Update `scripts/screen/record-flows.sh`: the toggle's new text, General without Default app, and a step that the PDF pane shows Default App and hides it while PDF is off. Run it with the maintainer's go, or queue it in `.local/screen-queue.md`.
- [ ] 3.2 Add a CHANGELOG line under Unreleased. Verify `scripts/build.sh test` passes with no warnings and `openspec validate --all` passes.
- [ ] 3.3 Bump the minor version in `MARKETING_VERSION` in `project.yml`, in its own commit, once v0.40.0 is tagged (the maintainer's call, 2026-11-17: no bump before the first release).

## Workflow follow-up

- Archive the change with `/opsx:archive` once the screen flows have run.
