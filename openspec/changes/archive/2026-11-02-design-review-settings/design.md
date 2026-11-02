# Design

## Context

`AppDelegate` makes a new `SettingsModel` each time the Settings window opens, with `selection = .general`, which is why the last pane is forgotten (S1). `SettingsWindowController` builds a titled, closable, resizable window, so the zoom button is live (S2). The add-extension `TextField` in `ExtensionTokens.swift` passes "Add an extension" as its title and hides it with `labelsHidden()`, with no prompt, so the box is blank (S3). `SettingsView` gives every plugin row `puzzlepiece.extension` (S4).

`PermissionsPane` holds three sections: Accessibility and Control Finder (headed "Space in Finder"), Open at Login, and Default app, with the Default app checks (`refreshDefaults`, `makeDefault`, `DefaultAppRow`) private to it (S6). These controls don't change the config, so they stay usable while it's locked; General's sections are disabled then.

`KeyRecorder.refuse` shows the reason as red caption text and clears it after three seconds, and VoiceOver hears nothing (A2).

The feature's names in code (S5): `Config.quickLookKey` and the config section `quickLook` (`Config.swift`, `ConfigRendering.swift`, `ConfigSchema.swift`), `Shortcut.Rules.quickLook`, `readQuickLook`, `quickLookFinderSelection` in `AppDelegate`, the recorder id `quickLook`, `QuickLookPanel` in `Sources/Host/QuickLook/` (with `FinderBridge` and `HotkeyMonitor`, whose names stay), a log category `quicklook`, the Apple Events usage string in `project.yml`, and `bench/ppbench.py`'s space harness, which still writes the long-gone `quicklook.key = space` dotfile. User-facing text says "Quick look panel", "Space in Finder" and "quick-look key".

## Goals / Non-Goals

**Goals:**
- S1 to S6 and A2 as this change's specs describe.
- One name, the Peek panel, in everything current: user text, code, comments, specs, docs and agent files.

**Non-Goals:**
- M8 (turning off the menu bar icon) and the other open findings.
- Rewriting history: archived OpenSpec changes, the dated reviews in `docs/`, `decisions/`, `research/` and `REPORT.md` keep their wording.
- Renaming benchmark metric ids (`inapp.panel.*`, `space.*`) or results files.
- Accepting `quickLook` as an old spelling of `peekPanel` (the maintainer chose the plain unknown-key problem).

## Decisions

**Plugins name their symbol.** `Plugin` gains `static var symbol: String { get }` with a default of `puzzlepiece.extension` in a protocol extension, so a plugin that names none still works and the host knows no formats. `PluginEntry` carries it; `SettingsView` uses `plugin.symbol`. Image says `photo`, PDF `doc.richtext`, Markdown `number`, Plain Text `doc.plaintext` (the maintainer picked these from rendered mockups).

**The last pane is remembered as a short string.** `SettingsPane` gets a `storageKey` (`general`, `plugin.<id>`, `permissions`, `configFile`) and an initializer from one. `SettingsModel` takes `defaults: UserDefaults?` (`.standard` from the app, nil in tests, which then remembers in memory only, as `SidebarMemory` does), reads `settingsPane` at init and writes it on every selection change. A stored pane that no longer exists (a removed plugin) falls back to General. It lives in preferences, not the config file: it's window state, not a setting.

**Zoom off, resizing kept.** `SettingsWindowController` sets `standardWindowButton(.zoomButton)?.isEnabled = false` after building the window.

**The field's placeholder.** `TextField("Add an extension", text: $draft, prompt: Text("Add an extension"))`, keeping `labelsHidden()` so the title stays the accessibility label.

**General takes Open at Login and Default app.** The Open at Login section (switch, approval note, footer "The Peek panel works only while Peeker is running.") and the Default app section move into General between the Peek panel section and Updates. The Default app logic moves out of `PermissionsPane` into a `DefaultAppSection` view in its own file, so `GeneralPane` stays short; the Open at Login section becomes `LoginSection` next to it. Neither section gets `.disabled(!store.isUsable)`, so both stay usable while the config is locked, as they were in Permissions. Permissions keeps the two permission rows under the header "Peek panel", and its polling task now only refreshes those.

**The recorder's refusal is announced and kept.** `refuse` drops its timer: the reason clears when recording starts again (`start()` already sets `refusal = nil`). It posts `NSAccessibility.post(element: NSApp, notification: .announcementRequested, userInfo: [.announcement: reason, .priority: NSAccessibilityPriorityLevel.high.rawValue])`. A small `announce(_:)` function makes that one call, so a test can check what was posted by replacing it.

**The rename, by kind.**
- Config: the section is `peekPanel` (`"peekPanel": {"key": "space"}`); `Config.peekPanelKey`; `readPeekPanel`; the schema's property and description. `quickLook` gets no special case: the reader's unknown-key path reports it.
- Code: `Shortcut.Rules.peekPanel`, recorder id `peekPanel`, `peekFinderSelection`, `Sources/Host/PeekPanel/PeekPanel.swift` with class `PeekPanel` (moved with `git mv` so history follows), log category `peekpanel`. `FinderBridge` and `HotkeyMonitor` keep their names.
- User text: General's toggle "Peek panel", its footer, Permissions' header and the Accessibility row's detail ("Lets Peeker see the Peek panel key while you're in Finder."), the menu bar line "The Peek panel needs Accessibility…", the Apple Events usage string, alerts.
- Specs: the `peek-panel` capability takes over `quick-look-panel`'s requirements (retired through this change), and the other specs' requirements that name the panel say Peek panel. OpenSpec won't rename scenarios, so three scenarios keep their titles through the archive ("Space panel" twice in pdf, "Moving the panel to Option-Space" and "Turning the panel off" in settings) and are retitled in the main specs right after it.
- Docs and agent files: README, BENCHMARKS.md prose, AGENTS.md, the run-peeker skill, `openspec/config.yaml` and `openspec/gaps.md` (including capability references `quick-look-panel` → `peek-panel`), comments in scripts and bench. The space harness writes `{"peekPanel": {"key": "space"}}` to a `config.json`.
- Kept: "Quick Look" wherever it means Finder's own (the fallback, the benchmark comparison), and history as listed in Non-Goals.

A final `grep -rniE "quick.?look|space panel|space in finder"` over current files (history excluded) checks that only Finder's Quick Look remains.

**Screen tests.** `record-flows.sh` already opens Settings and changes things in General and a plugin pane. It gains: the General toggle reads "Peek panel" and the menu bar icon's menu names it when Accessibility is missing (or, since the test machine has it granted, the menu has no stale "Space in Finder" line); choosing the PDF pane, closing and reopening Settings shows the PDF pane; General has Open at Login and Default app and Permissions doesn't; the add-extension field's placeholder reads "Add an extension" (the field's `AXPlaceholderValue`). Its config writes switch from `quickLook` to `peekPanel`, and its `cfg` checks read `peekPanel`.

## Risks / Trade-offs

- [A config written by Settings before this change has `quickLook`, so after updating, the Peek panel falls back to Space and the config shows an unknown key.] → Accepted by the maintainer; nothing is released, and the next change in Settings writes `peekPanel`.
- [Renaming `Sources/Host/QuickLook` and types touches many files at once.] → Done as its own task with the build and full tests run right after, before the Settings work, so a break points at the rename.
- [The test machine has Accessibility granted, so the menu bar's Accessibility line never shows in a screen run.] → A unit test checks the line's title; the screen check covers General's wording.
- [`.announcementRequested` reaches VoiceOver only while it runs.] → The test checks what's posted, not what VoiceOver speaks; a hand check with VoiceOver goes in the summary if not done.
