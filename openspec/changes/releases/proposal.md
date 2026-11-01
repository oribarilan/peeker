# Proposal

## Why

Peeker has no releases: the only way to run it is to build it from source. To replace Preview for anyone, it needs numbered versions, an install people trust (signed and notarized, through Homebrew), and updates that reach them without a manual download, the way common Mac apps work. Decided on 2026-11-01 as the next change.

## What Changes

- **Versions:** semantic versions from git tags (`v0.1.0` first; 1.0.0 when Peeker replaces Preview for daily use). The tag sets the app's version and a build number derived from it; local builds say `0.0.0-dev`. A hand-written `CHANGELOG.md` has a section per version.
- **Release workflow:** pushing a version tag runs a GitHub Actions workflow that refuses the tag when unit tests fail or `CHANGELOG.md` has no section for it, then builds, signs with a Developer ID, notarizes and staples a DMG, publishes a GitHub Release with that changelog section, updates the update feed, and updates the Homebrew cask. The maintainer runs the screen tests before tagging.
- **Homebrew:** a cask in the maintainer's own tap (`brew install --cask oribarilan/tap/peeker`), marked as updating itself. The official cask comes later, once the app has public interest.
- **Updates in the app (Sparkle 2):** a daily check, on by default, that shows the release notes and offers Install, Skip or Remind Me Later. Updates must carry the project's signature. No system details are sent.
- **Opt-out in the config:** `updates.check` in `config.json` (default true), applied live like other settings; Settings > General gets a "Check for updates automatically" checkbox, a Check Now button and the current version.
- **Check for Updates…** in the app menu and in the menu bar icon's menu.
- **Maintainer guide:** the one-time steps outside the code (Apple Developer Program, Developer ID certificate, notarization key, Sparkle key, the tap repository, GitHub Pages, Actions secrets).
- Everything is built and tested up to signing now; 0.1.0 ships once the Developer ID certificate is in the Actions secrets.

## Capabilities

### New Capabilities

- `updates`: checking for, offering and installing new versions from inside the app, and the user's control over it.
- `releases`: how versions are numbered, built, signed and published, and how Homebrew and the update feed learn about them.

### Modified Capabilities

- `routing-and-config`: the config gains an `updates` section.
- `app-presence`: the menu bar icon's menu gains Check for Updates….
- `settings`: the General pane gains the update controls.

## Impact

- New dependency: Sparkle 2 (MIT) through Swift Package Manager, in the app and the unit tests. It is a dynamic framework, so it's embedded and signed with the app, the first one Peeker ships.
- `project.yml`: version and build number settings, hardened runtime, Sparkle's Info.plist keys (feed URL, public key, daily checks, no profiling).
- `Sources/Host/App`: config reading, rendering and schema for `updates`; an updater owned by the app delegate; menu items. `Sources/Host/Settings/GeneralPane.swift`: the update controls.
- New files: `.github/workflows/release.yml`, release scripts in `scripts/`, `CHANGELOG.md`, a cask template, and the maintainer guide.
- The open path must stay as fast: the updater starts after launch, off the path to the first window, and `scripts/bench-ab.sh` checks it.
- Outside this repository: the `oribarilan/homebrew-tap` repository and GitHub Pages for the update feed, set up by the maintainer.
