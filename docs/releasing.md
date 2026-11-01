# Releasing Peeker

A release is a version tag. Pushing `v0.2.0` runs `.github/workflows/release.yml`, which checks the tag and its notes, runs the unit tests, builds, signs and notarizes a DMG (`scripts/release.sh`), publishes the GitHub Release, adds it to the update feed on GitHub Pages (`scripts/update-appcast.sh`) and updates the Homebrew cask (`scripts/fill-cask.sh`). Installed copies find it on their next daily check.

## Versions

Versions follow [semantic versioning](https://semver.org): a patch release fixes things, a minor release adds things. Peeker stays at 0.x until it replaces Preview for daily use, then becomes 1.0.0. The tag sets the version and the build number Sparkle compares (major × 10000 + minor × 100 + patch), so minor and patch stay under 100. Builds made any other way say `0.0.0-dev` and never check for updates.

## One-time setup

1. **Join the Apple Developer Program** (99 USD a year) at <https://developer.apple.com/programs/enroll/>. Developer ID signing and notarization need it.
2. **Create a Developer ID Application certificate.** In Xcode, Settings > Accounts > Manage Certificates > + > Developer ID Application. Export it with its private key from Keychain Access as a `.p12` with a password. `base64 -i DeveloperID.p12 | pbcopy` copies it for the `DEVELOPER_ID_P12` secret; the password is `DEVELOPER_ID_PASSWORD`. Delete the exported file afterwards.
3. **Create a notarization key.** In App Store Connect, Users and Access > Integrations > Team Keys, generate a key with Developer access and download the `.p8` (you get one chance). Its contents are `NOTARY_KEY`, its key ID `NOTARY_KEY_ID`, and the issuer ID above the list `NOTARY_ISSUER`.
4. **Create the update signing key.** After any `scripts/build.sh`, run `build/dd/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys`. It keeps the private key in your login Keychain and prints the public key: put that in `project.yml` as `SPARKLE_PUBLIC_KEY` and commit it. Then `generate_keys -x sparkle-key.txt` exports the private key: its contents are `SPARKLE_PRIVATE_KEY`; delete the file. Keep a backup of the private key in a password manager: without it, installed copies can't accept any later update.
5. **Create the tap.** Make a public repository `oribarilan/homebrew-tap`. Create a fine-grained personal access token with access to that repository only and Contents set to read and write; it's `TAP_TOKEN`.
6. **Add the secrets** in this repository's Settings > Secrets and variables > Actions: `DEVELOPER_ID_P12`, `DEVELOPER_ID_PASSWORD`, `NOTARY_KEY`, `NOTARY_KEY_ID`, `NOTARY_ISSUER`, `SPARKLE_PRIVATE_KEY`, `TAP_TOKEN`. A tag pushed while any is missing fails before building, publishing nothing.
7. **Try a dry run.** Actions > Release > Run workflow, with the version you mean to release. It builds an unsigned DMG and keeps it as an artifact; nothing is published. Missing changelog notes only warn here.
8. **After the first release**, which creates the `gh-pages` branch, turn on GitHub Pages in Settings > Pages: deploy from the branch `gh-pages`, folder `/`. The feed is then at <https://oribarilan.github.io/peeker/appcast.xml>.

## Each release

1. Move the Unreleased notes in `CHANGELOG.md` into a section `## [0.2.0] - 2026-12-01`, written for people who use Peeker, and commit. A tag without a section fails.
2. Run `scripts/screen-test.sh` on an unlocked Mac and fix anything it finds.
3. Tag and push: `git tag v0.2.0 && git push origin v0.2.0`. Agents tag only when the maintainer asks.
4. When the workflow finishes, check the release page, the feed (`curl -s https://oribarilan.github.io/peeker/appcast.xml | grep shortVersionString`) and `brew install --cask oribarilan/tap/peeker` (or `brew upgrade --cask --greedy peeker`).

To build a signed release on your own Mac, have the Developer ID certificate in your Keychain, store notarization credentials once with `xcrun notarytool store-credentials peeker`, and run `NOTARY_PROFILE=peeker scripts/release.sh v0.2.0`.

## Pulling a bad release

1. Stop offering it: on `gh-pages`, delete its `<item>` from `appcast.xml` and push. Copies that already updated keep it.
2. Ship a fixed patch release, which every copy is then offered.
3. If the DMG itself is harmful, delete the GitHub Release and point the tap's `Casks/peeker.rb` back at the previous version.
