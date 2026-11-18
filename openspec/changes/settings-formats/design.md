# Design

## Context

See proposal.md for why. Today `DefaultAppSection` in General loops over every plugin and shows a `DefaultAppRow` per plugin, summarized by `DefaultAppSummary` (all, some of N, none, can't set) from `DefaultApps.check`, which asks Launch Services for each extension's app. `PluginPane` holds the toggle, the extension tokens and the tools, all inside one `.disabled(!store.isUsable)` group. User-facing "plugin" text lives in a handful of string literals in `Sources/Host`.

## Goals / Non-Goals

**Goals:**
- Each format pane shows and sets its own default app, reusing `DefaultApps` as it is.
- Change only user-facing words; identifiers, config keys and specs keep "plugin".

**Non-Goals:**
- A plural noun per plugin in the plugin contract ("PDFs", "images"). The text uses "<Name> files".
- Renaming the `plugins` config key or any type.

## Decisions

**The summary names an app instead of counting Peeker.** The row now says "Opens in <app>", so `DefaultAppSummary` changes from all / some / none / can't set to: one app (with its name, Peeker or another), several apps, or can't set, counting only settable extensions. Make Default shows unless the one app is Peeker. The row expands when there are several apps or any extension can't be set, so `.conf` and `noExtension` stay visible. A settable type with no app counts as "No app". The alternative, keeping the Peeker count and adding the app name beside it, needs two lines of text for one fact.

**One section per pane, not one list for all.** `DefaultAppSection` becomes a section that takes one plugin and sits in `PluginPane` after Extensions, outside the disabled group so it works while the config is locked. It's left out while the plugin is in `config.disabled`. It refreshes on appear, when the window becomes key (another app may have taken a type), and when the plugin's effective extensions change, since adding an extension in the pane above adds a row. Checking one plugin's extensions on pane switch is a few Launch Services calls, cheaper than today's check of every plugin on opening General.

**Strings change in place.** The alert in `AppDelegate`, the recovery messages in `RecoveryRestore`, the config problems in `Config`, the descriptions in `ConfigSchema`, the sidebar heading, the toggle and footer, Open in Text Editor (both buttons) and the Appearance footer. No string table: the app has no localization yet.

## Risks / Trade-offs

- [The screen flows find controls by their text ("Open files with Image", "Default app")] → Update `scripts/screen/record-flows.sh` in the same change; the run waits for the maintainer's go.
- [Tests that compare problem or alert text] → Update them with the text; a failing test first for the summary and the hidden section.
- ["Image files", "Table files" read stiffly] → Accepted for now; a per-plugin noun can come later without changing the layout.
