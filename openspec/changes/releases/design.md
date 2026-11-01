# Design

## Context

Peeker builds with XcodeGen and `scripts/build.sh`, signed with the maintainer's Apple Development identity (or ad hoc) so macOS keeps its Accessibility and Automation grants across rebuilds. It has no version keys, no hardened runtime, no entitlements file and no embedded frameworks: the plugins and swift-markdown are linked statically. `HostTests` compiles `Sources/Host` directly, so anything the host imports is a test dependency too. It sends Apple Events to Finder (`FinderBridge`, `Permissions`) for the selection. The config (`Config`, `ConfigReader`, `ConfigRendering`, `ConfigSchema`) has two sections, and every change made in Settings rewrites the whole file with defaults. The app menu is built in `MainMenu.make`, the menu bar icon's menu in `MenuBarItem`. CI has one workflow (`bench.yml`) on `macos-26`. The open `settings-window` change adds the General pane to the specs; it should be archived before this one so the `settings` delta lands next to it.

## Goals / Non-Goals

**Goals:**
- A release is one tag push; nothing about it is done by hand except writing the changelog and running the screen tests first.
- The workflow runs end to end without the signing secrets, stopping before anything is signed or published, so it can be tested before the Developer ID exists.
- Launch and open speed stay as they are.

**Non-Goals:**
- A beta channel, delta updates, a DMG background picture, an official Homebrew cask, or a Mac App Store build.

## Decisions

**1. Version from the tag, injected at build time.** `project.yml` sets `MARKETING_VERSION: 0.0.0-dev` and `CURRENT_PROJECT_VERSION: 0`, and the Info.plist reads both. `scripts/release-version.sh vX.Y.Z` checks the tag (three numbers, minor and patch under 100) and prints the version and build number (`X*10000 + Y*100 + Z`); the release build passes them to `xcodebuild`. No version-bump commits, so the tag can't disagree with the code. Considered: a bump commit checked against the tag (one more step per release, and a second source of truth).

**2. Sparkle 2.10.1 behind a small `Updater`.** Added like swift-markdown (`exactVersion`), to the app and to `HostTests`, embedded and signed on copy. `Updater` in `Sources/Host/App` owns an `SPUStandardUpdaterController` created with `startingUpdater: false`. It reports whether this build updates at all (version isn't `0.0.0-dev`), takes `check: Bool` from the config, and checks on request. Info.plist: `SUFeedURL` (the Pages address), `SUPublicEDKey`, `SUEnableAutomaticChecks` YES (on without Sparkle's second-launch question), `SUScheduledCheckInterval` 86400, `SUEnableSystemProfiling` NO, and `SUAllowsAutomaticUpdates` NO so the update window has no "install automatically" box, matching the decision to ask with release notes. Considered: a hand-made GitHub Releases check (no in-place install, no signature checks to lean on).

**3. The config is the only store for the opt-out.** `Config.checkForUpdates` (default true) is read from `updates.check`, written by `ConfigRendering` and described in `ConfigSchema`. `AppDelegate.configChanged` sets `Updater`'s check flag, which writes Sparkle's `automaticallyChecksForUpdates`. Sparkle keeps its own copy in user defaults, but nothing shows Sparkle's settings UI and every launch and config change overwrites it, so the config wins.

**4. The updater starts after launch.** It's created and started on the run loop turn after `applicationDidFinishLaunching`, never in benchmark mode (`PEEKER_BENCH_OUT`) or in a development build. Linking a dynamic framework adds work at launch, so `scripts/bench-ab.sh` runs before the change is done (see Risks).

**5. Hardened runtime everywhere, with one entitlement.** `ENABLE_HARDENED_RUNTIME: YES` for the app in every build, so the screen tests drive what ships, plus `Peeker.entitlements` with `com.apple.security.automation.apple-events`, which the hardened runtime needs before Peeker can ask Finder for its selection. Library validation stays on: Sparkle is re-signed with the app's identity.

**6. One release script, called by CI.** `scripts/release.sh <tag>` builds Release with the version, signs with the Developer ID (`--timestamp`), checks the signature, makes the DMG (`hdiutil`, Peeker.app plus an Applications link), signs it, then notarizes and staples the app and the DMG with `notarytool` (an App Store Connect API key). Without the signing identity it builds unsigned, makes the DMG and says it stopped before signing: the dry run. Keeping the steps in a script lets the maintainer run them locally and keeps the workflow short. Considered: steps written inline in YAML (hard to run or test outside CI).

**7. Release notes from `CHANGELOG.md`.** Keep a Changelog layout: `## [Unreleased]` on top, then `## [0.1.0] - 2026-11-20` sections. `scripts/changelog-notes.sh 0.1.0` prints that section's body and fails when there's none; its output is the GitHub Release body and the Markdown notes file `generate_appcast` puts in the feed (Sparkle shows Markdown notes since 2.9).

**8. Feed on GitHub Pages, from a `gh-pages` branch.** The workflow checks out `gh-pages`, runs Sparkle's `generate_appcast` on the new DMG with its notes, the download address of the GitHub Release asset and the EdDSA key from a secret, with deltas off, and pushes `appcast.xml`. Pages serves it at `https://oribarilan.github.io/peeker/appcast.xml`, a fixed HTTPS address. Considered: the file on `main` read through raw.githubusercontent.com (cached, served as plain text).

**9. The tap is updated from a template.** `packaging/peeker.rb` is the cask with placeholders for version and checksum: GitHub Release URL, `auto_updates true`, `depends_on macos: ">= :tahoe"`, `livecheck` with `strategy :sparkle` on the feed, and `zap` for the app's preferences, caches and recovery folder (not the user's `~/.config/peeker`). The workflow fills it in and commits `Casks/peeker.rb` to `oribarilan/homebrew-tap` with a fine-grained token limited to that repository.

**10. The workflow.** `.github/workflows/release.yml` runs on `v*` tags and on manual dispatch (a version input, always a dry run). In order: check the tag and the changelog section, unit tests, release script, then, only on a tag with every secret present, publish the GitHub Release (`gh release create`), update the feed and update the tap. A failed step leaves the later ones undone. The dry run uploads the unsigned DMG as a workflow artifact. Permissions: `contents: write` for this repository; the tap token is separate.

**11. Menus and Settings.** "Check for Updates…" goes after About Peeker in the app menu and after Settings… in the menu bar icon's menu, both to `AppDelegate.checkForUpdates(_:)`, enabled while no check is running. The General pane gets an Updates section: the checkbox (through `model.save`, like every other setting), Check Now, and "Version 0.1.0 (101)". In a development build the checkbox stays, Check Now and the menu items say updates come only with released builds, and nothing reaches the network.

**12. The maintainer guide.** `docs/releasing.md`: one-time setup (enroll, create the Developer ID Application certificate and export it, create the API key for notarization, run Sparkle's `generate_keys` and put the public key in `project.yml`, create the tap repository, turn on Pages for `gh-pages`, add the secrets with their exact names) and each release (move Unreleased notes into a version section, run `scripts/screen-test.sh`, tag, push the tag). Agents push tags only when the maintainer asks.

## Risks / Trade-offs

- [Sparkle's dynamic framework slows launch] → Measure with `scripts/bench-ab.sh main` before finishing; if launch-to-first-window regresses past the gate, load Sparkle on the deferred turn instead of linking it at launch, and record the numbers either way.
- [Hardened runtime breaks Finder selection or plugin loading] → The entitlement above; the screen-test suite runs on the hardened build before the change is done.
- [The secrets leak or a forged update ships] → Updates need both the EdDSA signature and the same Developer ID; the private keys live only in Actions secrets and the maintainer's Keychain; the tap token can write only the tap.
- [A broken release reaches users] → Remove its item from `appcast.xml` on `gh-pages` to stop offering it, then ship a patch; the GitHub Release can be deleted, and the cask points at the previous version until the next release.
- [The tag and the feed drift] → Both come from the same workflow run, after every earlier step passed.
- [Development builds look the same as releases] → They say `0.0.0-dev` in About and Settings and never check.

## Migration Plan

1. Land the code: config key, updater, menus, Settings, hardened runtime, scripts, workflow, cask template, changelog and guide. Released builds don't exist yet, so nothing checks.
2. The maintainer does the one-time setup from `docs/releasing.md`.
3. Run the workflow by hand as a dry run once the secrets are in, to see signing and notarization pass.
4. Tag `v0.1.0`, then check the release page, `appcast.xml` and `brew install --cask oribarilan/tap/peeker`.

## Open Questions

- The exact `generate_appcast` options for a download prefix and Markdown notes, to confirm against the 2.10.1 tools while writing the workflow.
