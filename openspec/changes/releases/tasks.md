# Tasks

## 1. Version numbers

- [x] 1.1 Add `MARKETING_VERSION: 0.0.0-dev` and `CURRENT_PROJECT_VERSION: 0` to `project.yml` with the Info.plist reading both; verify the built app's Info.plist has `0.0.0-dev` and `0`, and About Peeker shows it
- [x] 1.2 Write `scripts/release-version.sh <tag>` printing the version and build number (`X*10000 + Y*100 + Z`) and refusing anything else (no `v`, four parts, a part of 100 or more, leading zeros); verify with `v0.2.1` → `0.2.1 201`, `v1.0.0` → `1.0.0 10000`, and each refusal exiting non-zero with a message
- [x] 1.3 Add `CHANGELOG.md` (Keep a Changelog, an Unreleased section) and `scripts/changelog-notes.sh <version>` printing that version's section body; verify it prints a sample section, and fails with a message for a missing version and for Unreleased

## 2. Config and updater

- [ ] 2.1 Add `updates.check` to the config: `Config.checkForUpdates` (default true), reading with problems for a wrong type or unknown key under `updates`, rendering, and the schema; unit tests first for a missing key, false, a string value and an unknown key, and for a Settings rewrite including `"updates": {"check": true}`
- [ ] 2.2 Add Sparkle 2.10.1 to `project.yml` (app, embedded and signed on copy, and `HostTests`) with the Info.plist keys from design decision 2 (`SUPublicEDKey` a placeholder until task 6.2); verify `scripts/build.sh` passes with no new warnings and `codesign --verify --deep --strict` passes on the built app
- [ ] 2.3 Write `Updater` (design decision 2): whether this build updates, the check flag, check now, and a development-build answer; unit tests first that a `0.0.0-dev` build never starts or checks and that the flag follows the config
- [ ] 2.4 Have `AppDelegate` create `Updater` on the turn after launch (not in benchmark mode) and pass `checkForUpdates` from every config change; verify with a unit test that a saved `{"updates": {"check": false}}` turns the flag off, and with `scripts/bench-ab.sh main` that launch and open times stay within the gate (record the numbers in the commit)

## 3. Menus and Settings

- [ ] 3.1 Add Check for Updates… after About Peeker in the app menu and after Settings… in the menu bar icon's menu, enabled while no check runs, with the development-build message; update `MainMenuTests` and the menu bar tests for the new items, and update `docs/` or the run-peeker skill where they list the menu
- [ ] 3.2 Add the Updates section to `GeneralPane`: the checkbox through `model.save`, Check Now, and the version line; unit test that toggling it rewrites the config with `updates.check`
- [ ] 3.3 Add a step to `scripts/screen/record-flows.sh`: clear the checkbox and check `config.json`, choose Check for Updates… from the menu bar icon and check the development-build message appears; verify the flow passes on its own (needs the maintainer's go)

## 4. Hardened runtime

- [ ] 4.1 Turn on `ENABLE_HARDENED_RUNTIME` for the app and add `Peeker.entitlements` with `com.apple.security.automation.apple-events`; verify `codesign -d --entitlements - ` shows it, `codesign -dv` shows the runtime flag, and `scripts/screen-test.sh` passes in full on the hardened build (needs the maintainer's go)

## 5. Release build and DMG

- [ ] 5.1 Write `scripts/release.sh <tag>` (design decision 6): versioned Release build, Developer ID signing with `--timestamp`, signature check, DMG with an Applications link, DMG signing, `notarytool` submission and stapling for the app and the DMG, and a clear stop before signing when no Developer ID identity or notarization key is set; verify locally that the dry run produces a DMG that mounts, holds Peeker.app and the link, and whose app reports the tag's version
- [ ] 5.2 Add `packaging/peeker.rb` (design decision 9) and a script that fills in version and checksum; verify the filled cask passes `brew style` and `brew audit --cask` run against a local tap copy, apart from checks that need the release to exist

## 6. Workflow and feed

- [ ] 6.1 Write `.github/workflows/release.yml` (design decision 10) with the secret names from the guide; verify a manual dispatch on `main` runs through tests and the dry-run DMG artifact, and that a tag whose changelog section is missing fails before the build (on a test tag deleted afterwards, with the maintainer's OK)
- [ ] 6.2 Add the feed step: `generate_appcast` from Sparkle's 2.10.1 tools on the new DMG with its Markdown notes, the Release asset address and deltas off, pushed to `gh-pages`; confirm the exact options against the tools; verify locally with a throwaway EdDSA key that the generated `appcast.xml` has the version, build number, signature, length and notes
- [ ] 6.3 Add the tap step: fill in `packaging/peeker.rb` and commit it to `oribarilan/homebrew-tap` with the tap token; verify the step is skipped in a dry run and its commands work against a local clone

## 7. Guide and checks

- [ ] 7.1 Write `docs/releasing.md` (design decision 12) with the one-time setup, the secret names the workflow reads, each release's steps and how to pull a bad release; link it from `AGENTS.md` and the README's install section, and add the install command to the README marked as coming with 0.1.0
- [ ] 7.2 Run `scripts/build.sh test` (no new warnings), `scripts/check-plugin-imports.sh`, `openspec validate --all --strict` and, with the maintainer's go, `scripts/screen-test.sh`; verify all pass

## Workflow follow-up

- The maintainer does the one-time setup from `docs/releasing.md`, runs the workflow by hand once the secrets are in, then tags `v0.1.0`.
- Archive `settings-window` before this change, then archive this one with `/opsx:archive`.
