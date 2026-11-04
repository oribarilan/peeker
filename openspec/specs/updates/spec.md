# updates Specification

## Purpose
How Peeker finds, offers and installs its own new versions, and how the user turns automatic checks off or checks by hand.

## Requirements

### Requirement: Peeker checks for updates daily by default

Peeker SHALL check the project's update feed about once a day without asking first while `updates.automatic` is `"check"` (the default) or `"download"`, starting after launch so the check never delays opening a file. With `"off"`, Peeker SHALL make no automatic checks.

#### Scenario: A fresh install

- **WHEN** a new user installs Peeker and runs it for a few days
- **THEN** it checks for updates once a day, without a prompt asking whether it may

#### Scenario: Turned off

- **WHEN** the config has `"updates": {"automatic": "off"}`
- **THEN** Peeker contacts the update feed only when the user asks it to check

### Requirement: A new version is offered with its release notes

When a check finds a newer version in `"check"` mode, or the user chose Check for Updates…, Peeker SHALL offer it in a window with that version's release notes and the choices Install, Skip This Version and Remind Me Later. Install SHALL replace the app and relaunch it, asking first about unsaved edits as quitting does. Skip SHALL stop offering that version; Remind Me Later SHALL offer it again on a later check.

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

A build whose version ends in `-dev` SHALL make no update checks, automatic or by hand, and SHALL show no what's-new window. Its Check for Updates… and Check Now SHALL say that updates come only with released builds.

#### Scenario: Running a local build

- **WHEN** a contributor runs a build from `scripts/build.sh` and chooses Check for Updates…
- **THEN** a message says development builds don't update, and no request is made

#### Scenario: A newer local build

- **WHEN** a contributor runs 0.10.0-dev after running 0.9.0-dev
- **THEN** no what's-new window appears

### Requirement: A scheduled check doesn't interrupt

When a scheduled check finds a newer version while Peeker isn't the active app, Peeker SHALL open no window; the menu bar icon SHALL show that an update is available, and choosing it there SHALL open the update window. While Peeker is the active app, the update window SHALL open at once.

#### Scenario: Working in another app

- **WHEN** the daily check finds 0.3.0 while the user works in Safari
- **THEN** no window appears, and the menu bar icon shows the update

#### Scenario: Peeker in front

- **WHEN** the daily check finds 0.3.0 while a Peeker window is the active window
- **THEN** the update window opens

#### Scenario: Asked for

- **WHEN** the user chooses Check for Updates… and 0.3.0 is out
- **THEN** the update window opens at once

### Requirement: Download mode installs updates by itself

With `updates.automatic` set to `"download"`, a scheduled check that finds a newer version SHALL download it without asking. Once it's downloaded and no Editor window, Settings window or Peek panel is open, Peeker SHALL install it and relaunch without showing a window. Until then it SHALL wait, and quitting Peeker SHALL install it.

#### Scenario: Nothing open

- **WHEN** a downloaded update is ready and Peeker has no window or Peek panel open
- **THEN** Peeker relaunches as the new version, and nothing appears on screen

#### Scenario: A window open

- **WHEN** a downloaded update is ready while a PDF window is open
- **THEN** Peeker keeps running the installed version, and installs and relaunches after that window closes

#### Scenario: Quitting

- **WHEN** a downloaded update is ready and the user quits Peeker with a window open
- **THEN** Peeker quits as Quit would and the next launch runs the new version

#### Scenario: Chosen in the update window

- **WHEN** the user ticks "Automatically download and install updates in the future" in the update window
- **THEN** `config.json` has `"updates": {"automatic": "download"}`, and clearing it writes `"check"`

### Requirement: Peeker says what's new after an update

After Peeker starts as a newer version than it last ran, it SHALL show a window titled "Updated to Peeker" with the version, listing the release notes of every version after the last one run up to this one, newest first, with a Done button. It SHALL make no network request for them. A first install, or `updates.showWhatsNew` set to false, SHALL show nothing.

#### Scenario: Skipping a release

- **WHEN** Peeker last ran as 0.2.0 and starts as 0.4.0
- **THEN** the window "Updated to Peeker 0.4.0" lists the notes of 0.4.0 and 0.3.0

#### Scenario: First install

- **WHEN** Peeker starts for the first time
- **THEN** no what's-new window appears

#### Scenario: Turned off

- **WHEN** the config has `"updates": {"showWhatsNew": false}` and Peeker starts as a newer version
- **THEN** no what's-new window appears

### Requirement: The what's-new window comes at a good moment

After an update the user installed from the update window, or a launch by hand, the what's-new window SHALL open at launch. After a quiet install in download mode, or a launch at login, it SHALL wait and open when the first Editor or Settings window does. It SHALL appear once per update.

#### Scenario: Installed from the update window

- **WHEN** the user clicks Install for 0.3.0 and Peeker relaunches
- **THEN** the window "Updated to Peeker 0.3.0" opens

#### Scenario: Installed quietly

- **WHEN** download mode installs 0.3.0 with nothing open, and later the user opens a PDF
- **THEN** nothing appears at the relaunch, and the what's-new window opens with the PDF window

#### Scenario: Seen once

- **WHEN** the user closes the what's-new window for 0.3.0 and opens another file
- **THEN** the window doesn't appear again
