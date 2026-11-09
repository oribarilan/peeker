## MODIFIED Requirements

### Requirement: Password-protected PDFs

A PDF that needs a password SHALL show, in the Editor, a lock with the file's name, a password field and Unlock. Either of its passwords SHALL unlock it, showing the PDF with its tools, editable within the file's permissions; a wrong password SHALL say "Wrong password." and clear the field. The password SHALL be kept only in memory while its window is open. The Peek panel SHALL say the PDF is password protected and that Open in Peeker unlocks it in a window.

#### Scenario: Unlocking
- **WHEN** the user opens a password-protected PDF, types its password and presses Return
- **THEN** the pages, thumbnails and info appear, and the edit tools work

#### Scenario: Permissions still apply
- **WHEN** the user unlocks a PDF whose permissions don't allow filling in forms
- **THEN** the edit tools are greyed out with the reason

#### Scenario: Wrong password
- **WHEN** the user types a wrong password and presses Unlock
- **THEN** the tab says "Wrong password." and the field is empty

#### Scenario: Peek panel
- **WHEN** the user presses Space on a password-protected PDF
- **THEN** the panel says the PDF is password protected and that Open in Peeker unlocks it in a window

## ADDED Requirements

### Requirement: Saving a password-protected PDF keeps its lock

Saving a password-protected PDF SHALL keep it locked with the same passwords and permissions. Before replacing the file, the plugin SHALL check that the written copy opens with the password that unlocked it and keeps the file's permissions. When the file's own encryption can't be kept, the plugin SHALL save with 128-bit RC4 encryption, both passwords and the file's own permission bits, saying once when that's older than the file's own.

#### Scenario: Filling a locked form
- **WHEN** the user unlocks a password-protected form, fills a field and saves
- **THEN** opening the file again asks for the same password, and the field holds the value

#### Scenario: A file Acrobat locked with AES-256
- **WHEN** the user unlocks a PDF encrypted with AES-256, fills a field and saves
- **THEN** the save says once that the file now uses older 128-bit encryption, and the file opens with the same passwords

### Requirement: Saving without one of a PDF's passwords

When the file's own encryption can't be kept and its permissions password isn't known, Save SHALL use the open password for both if the file's own permission bits limit nothing, saying so once, and SHALL otherwise ask for the permissions password. When the open password isn't known, Save SHALL ask for it; the permissions password SHALL NOT be taken in its place. Each password SHALL be checked against the file, and a wrong one or Cancel SHALL write nothing.

#### Scenario: Nothing limited
- **WHEN** the user unlocks an AES-256 PDF that limits nothing with its open password, edits it and saves
- **THEN** the save says once that the open password now also guards its permissions, and the file opens with the open password

#### Scenario: Printing limited
- **WHEN** the user unlocks an AES-256 PDF that allows only low-resolution printing with its open password, edits it and saves
- **THEN** a sheet asks for the permissions password, and once it's typed the file keeps its printing limit

#### Scenario: Unlocked with the permissions password
- **WHEN** the user unlocks an AES-256 PDF with its permissions password, edits it, saves, and types the permissions password again when asked for the open password
- **THEN** nothing is written and the sheet's error says it isn't the open password; typing the open password saves the file with both passwords

### Requirement: Recovered edits to a PDF that needs a password

The crash-recovery copy of a PDF that needs a password SHALL be encrypted with a key made from the password that unlocked it, so it can't be read without that password. After a crash the PDF SHALL reopen on its lock screen, marked edited, and its edits SHALL come back once it's unlocked with that password. Unlocked with its other password, it SHALL say the changes need the password used when they were made.

#### Scenario: A crash with unsaved edits in a locked PDF
- **WHEN** the user fills a field in an unlocked PDF and Peeker is force-quit
- **THEN** the recovery copy doesn't hold the field's value as readable text, and after relaunch the PDF shows its lock screen and, once unlocked, the field's value
