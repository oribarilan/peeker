# Tasks

## 1. Fixtures and the save path

- [x] 1.1 Test helpers that make locked PDFs at run time (AES-128 and RC4-40 with Core Graphics, RC4-128 with PDFKit; with and without permission limits); an AES-256 form and a restricted variant made once with qpdf, checked in under `Tests/Fixtures/` with a README of the commands. A test confirming whether a plain write of the AES-256 fixture keeps its lock.
- [x] 1.2 Failing tests, then `edited(_:from:password:)` unlocking its copy, a plain write and `verify` (locked, same password and status, same `/P` bits and cipher read from the file) before `FileReplacement`.
- [x] 1.3 Failing tests, then the RC4-128 fallback with both passwords and the source's permission bits: open password for both when nothing is limited (with its note), refusal when something is, and the `/AESV3` check for the "older encryption" note.

## 2. Unlocking and editing

- [x] 2.1 Failing tests, then `LockedPDFDocument.unlock(with:)` handing over an editable document with the password and its `permissionsStatus`; editability and page tools from the file's permissions; the read-only note and lock screen wording updated.
- [x] 2.2 Failing tests, then Save asking for the open or permissions password itself (one sheet), checking it, keeping it for later saves, and writing nothing on Cancel or a wrong password.
- [x] 2.3 The one-time notes after a save (older encryption; open password guarding permissions), once per window.

## 3. Crash recovery

- [x] 3.1 Failing tests, then the key derived once when first needed (PBKDF2-SHA256, random salt) and `PDFSnapshot` sealing the record with AES-GCM for a PDF that needs a password; plain records stay for the rest.
- [x] 3.2 Failing tests, then `LockedPDFDocument` holding a sealed record (reported as its unsaved edits, Save refused until unlocked) and restoring it on unlock; the other password, or edits that no longer fit, keep the lock screen with a message.

## 4. Checks

- [x] 4.1 Screen flow: unlock a locked form (`pdf-tool locked`), fill a field, save, and check with `pdf-tool inspect` (given the password) that the file is still locked and holds the value; extend `pdf-tool` as needed. Recovery flow: a locked PDF reopens on its lock screen and its edit comes back after the password.
- [x] 4.2 Specs and gaps.md ("A password-protected PDF opens view-only" removed), backlog line removed, CHANGELOG, the run-peeker skill; all unit tests, warning-free build, `openspec validate --all --strict`.

## Workflow follow-up

- Review by oracle, commit, minor version bump in its own commit, screen flows with the maintainer's go, archive, push, install.
- Change 2 (add, change or remove a lock with File > Password…) is planned after this one.
