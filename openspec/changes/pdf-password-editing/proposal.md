# Proposal

## Why

A password-protected PDF opens view-only, so a form that arrives locked (a bank, school or tax form) can't be filled or signed in Peeker. Preview edits these and saves them still locked. This is the first of two changes; the second adds File > Password… to add, change or remove a lock.

## What Changes

- An unlocked PDF can be edited within its own permissions, like any other PDF: fields, Markup, signatures, highlights and page tools, each only where the file allows it.
- Save keeps the lock. Peeker writes the file as PDFKit does by default, which on macOS keeps the file's encryption, both passwords and its permissions for AES-128 and RC4-128 files, and checks the written copy before it replaces the file.
- When that check fails (very old RC4-40 files, and AES-256 files, which Acrobat makes by default), Peeker saves with 128-bit RC4 encryption and both passwords instead:
  - unlocked with the open password and the permissions password unknown: the open password is used for both when the file limits nothing, saying so once; when it limits something, Save asks for the permissions password.
  - unlocked with the permissions password and the open password unknown: Save asks for the open password once and checks it; the permissions password isn't accepted in its place.
  - when the file used AES-256, Peeker says once that the saved file's encryption is older.
- Crash recovery for a PDF that needs a password: the recovery copy is encrypted with a key made from the password typed at the lock screen. After a crash the PDF reopens on its lock screen, marked edited, and the edits come back once it's unlocked with that password.
- The lock screen and the read-only note change to match: a locked PDF is no longer "view-only" by default.

## Capabilities

### Modified Capabilities

- `pdf`: password-protected PDFs become editable within their permissions, save with their lock, and get their recovered edits back once unlocked.
- `documents`: a save the user cancels partway shows no failure.

## Impact

- `Plugins/pdf/LockedPDFDocument.swift`: unlocking hands over an editable document with the password and a recovery key; holds recovered edits until unlocked.
- `Plugins/pdf/PDFPlugin.swift`: `saved(_:from:lock:)` and `write` take the passwords, save without options, verify, and fall back; `Plugins/pdf/PDFLock.swift` reads the permission bits and cipher from the file's encryption dictionary.
- `Plugins/pdf/PDFPluginDocument.swift`: editability from the file's permissions after unlocking; `PDFSnapshot` seals the recovery copy for a password PDF; a sheet asking for the open password at Save.
- A locked document that holds recovered edits reports them as its unsaved edits, so the host keeps the window edited and the recovery copy in place. One small host change: a save the plugin cancels (`PluginError.cancelled`) counts as cancelled, not failed.
- Tests with locked fixtures made by PDFKit and Core Graphics (AES-128, RC4-128, RC4-40) and an AES-256 fixture made with qpdf and checked in. The pdf-edit or viewer screen flow fills a field in a locked PDF and saves; CHANGELOG; minor version bump.
