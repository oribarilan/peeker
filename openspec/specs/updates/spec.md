# updates Specification

## Purpose
How Peeker finds, offers and installs its own new versions, and how the user turns automatic checks off or checks by hand.

## Requirements

### Requirement: Peeker checks for updates daily by default

While `updates.check` is true (the default), Peeker SHALL check the project's update feed about once a day without asking first, starting after launch so the check never delays opening a file. With it false, Peeker SHALL make no automatic checks.

#### Scenario: A fresh install

- **WHEN** a new user installs Peeker and runs it for a few days
- **THEN** it checks for updates once a day, without a prompt asking whether it may

#### Scenario: Turned off

- **WHEN** the config has `"updates": {"check": false}`
- **THEN** Peeker contacts the update feed only when the user asks it to check

### Requirement: A new version is offered with its release notes

When a check finds a newer version, Peeker SHALL show a window with that version's release notes and the choices Install, Skip This Version and Remind Me Later. Install SHALL replace the app and relaunch it, asking first about unsaved edits as quitting does. Skip SHALL stop offering that version; Remind Me Later SHALL offer it again on a later check.

#### Scenario: Installing an update

- **WHEN** a check finds version 0.2.0 and the user clicks Install
- **THEN** Peeker downloads it, quits as Quit would (asking about unsaved edits), and relaunches as 0.2.0

#### Scenario: Skipping a version

- **WHEN** the user clicks Skip This Version for 0.2.0
- **THEN** automatic checks don't offer 0.2.0 again, and they do offer 0.2.1 once it's out

### Requirement: The user can check for updates now

Check for Updates… in the app menu and in the menu bar icon's menu, and Check Now in Settings, SHALL check right away whether automatic checks are on or off. When no newer version exists, Peeker SHALL say it's up to date; when the feed can't be reached, it SHALL say so.

#### Scenario: Already current

- **WHEN** the user chooses Check for Updates… while running the newest version
- **THEN** a message says Peeker is up to date

#### Scenario: Offline

- **WHEN** the user chooses Check for Updates… without a network connection
- **THEN** a message says the update check couldn't reach the server

### Requirement: Only signed updates install

Peeker SHALL install an update only when its archive carries a valid signature from the project's update key and the app inside is signed by the same developer. Any other download SHALL be refused with a message, leaving the installed app as it was.

#### Scenario: A tampered download

- **WHEN** the update archive's contents don't match its signature
- **THEN** Peeker refuses it, says the update couldn't be verified, and keeps running the installed version

### Requirement: Update checks send nothing about the Mac

An update check SHALL request the feed without sending system details (hardware, macOS version, language or usage).

#### Scenario: Looking at a check

- **WHEN** an automatic check runs
- **THEN** the request carries no system profile parameters

### Requirement: Development builds don't check for updates

A build reporting version `0.0.0-dev` SHALL make no update checks, automatic or by hand. Its Check for Updates… and Check Now SHALL say that updates come only with released builds.

#### Scenario: Running a local build

- **WHEN** a contributor runs a build from `scripts/build.sh` and chooses Check for Updates…
- **THEN** a message says development builds don't update, and no request is made
