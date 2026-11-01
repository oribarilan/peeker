# releases Specification

## Purpose
How Peeker's versions are numbered, built, signed and published, and how Homebrew and the in-app update feed learn about each one.

## Requirements

### Requirement: Versions follow semantic versioning from git tags

A release SHALL be a git tag `vMAJOR.MINOR.PATCH`, and the app built from it SHALL report that version, with a build number of MAJOR × 10000 + MINOR × 100 + PATCH so each release's number is higher than the last. A build not made from a release tag SHALL report version `0.0.0-dev`.

#### Scenario: Building a release

- **WHEN** CI builds the tag `v0.2.1`
- **THEN** the app's About panel says version 0.2.1, and its build number is 201

#### Scenario: A local build

- **WHEN** a contributor runs `scripts/build.sh`
- **THEN** the app reports version 0.0.0-dev

### Requirement: A release needs passing tests and changelog notes

The release workflow SHALL refuse a tag, publishing nothing, when the unit tests fail, when `CHANGELOG.md` has no section for that version, or when the tag isn't a valid version. That changelog section SHALL become the release notes shown on the GitHub Release and in the app's update window.

#### Scenario: No notes for the version

- **WHEN** the maintainer pushes `v0.3.0` and `CHANGELOG.md` has no `0.3.0` section
- **THEN** the workflow fails, saying the section is missing, and no release, feed entry or cask change appears

### Requirement: A release is a signed, notarized DMG

Each release SHALL publish, on the GitHub Release for its tag, a DMG holding Peeker.app and a shortcut to Applications. The app and the DMG SHALL be signed with the project's Developer ID, notarized by Apple and stapled, so Gatekeeper opens them without warnings, offline too.

#### Scenario: Downloading by hand

- **WHEN** a user downloads the DMG from the release page, drags Peeker to Applications and opens it
- **THEN** macOS opens it after the usual first-launch confirmation for downloaded apps, with no warning about an unidentified developer

### Requirement: Each release reaches the update feed and Homebrew

Publishing a release SHALL add it to the update feed, served over HTTPS at a fixed address, and update the Homebrew cask in the project's tap to the new version and checksum. The cask SHALL declare that the app updates itself, so Homebrew leaves updates to the app.

#### Scenario: Installing with Homebrew

- **WHEN** a user runs `brew install --cask oribarilan/tap/peeker` after `v0.2.0` is published
- **THEN** Peeker 0.2.0 is installed in Applications

#### Scenario: An existing install learns of the release

- **WHEN** `v0.2.0` is published and a Mac runs 0.1.0 with automatic checks on
- **THEN** its next daily check offers 0.2.0
