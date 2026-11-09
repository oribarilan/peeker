# Design

## Context

`PDFPlugin.open` returns `LockedPDFDocument` when CoreGraphics can't open the file without a password. Its `unlock(with:)` hands the host a `PDFPluginDocument` made with `uneditableReason: viewOnlyReason`, and forgets the password. `PDFPlugin.edited(_:from:)`, which every save goes through, loads the file again with `PDFDocument(url:)` and refuses a locked one. PDFs that open without a password but carry permission limits (owner-only encryption) are already editable when they allow commenting and form filling, and already save through a plain `dataRepresentation()`.

Probes on macOS 27 (2026-11-09, scratch programs, not in the repo):

- A plain `dataRepresentation()` of an unlocked AES-128 or RC4-128 PDF keeps the cipher, both passwords and the permission flags, whether it was unlocked with the open or the permissions password.
- The same write of an RC4-40 PDF gives a file neither password opens. With the qpdf-made AES-256 fixtures, unlocked with the open password it drops the encryption; unlocked with the permissions password it writes a file that still opens with that password but no longer with the open one.
- Writing with `userPasswordOption` and `ownerPasswordOption` from a loaded document gives RC4-128 (`/V 2 /R 3`); from a fresh `PDFDocument` it gives AES-128, but moving pages into a fresh document risks losing forms, outline and metadata, so it's not used (the maintainer chose RC4-128 for simplicity).
- `PDFDocument.permissionsStatus` says whether the typed password was the open (`.user`) or the permissions (`.owner`) password; the same password for both reads `.owner`.

## Goals / Non-Goals

**Goals:** edit and save locked PDFs without weakening or dropping the lock when macOS can keep it; never write an unlocked copy; never leave a recovery copy readable without the password.

**Non-Goals:** adding, changing or removing a lock (change 2); writing AES; reading the encryption dictionary ourselves (no `/U` and `/O` checks: `permissionsStatus` and the verify step cover what Save needs); PDFs locked by certificates; Save Selected Pages As… and Split… of a password-protected PDF, which keep refusing it as before.

## Decisions

### The document keeps the password while its window is open

`LockedPDFDocument.unlock(with:)` passes the password and its `permissionsStatus` to the new `PDFPluginDocument`, which is now editable within the file's permissions (the existing commenting and form-filling check, and `allowsDocumentAssembly` for page tools). The password lives only in that object's memory. A save copies it into the off-main-thread write. *Alternative:* re-ask at each save; rejected as tedious, and Preview keeps it too.

### Save writes plainly, verifies, then falls back

`PDFPlugin.saved(_:from:lock:)` unlocks its fresh copy with the password, applies the edits and writes with no options. `LockState.isKept(by:password:encryption:)` reopens the written data and requires: it's locked when the source was, the same password unlocks it with the same `permissionsStatus`, and its encryption dictionary has the same `/P` bits and the same AES-128 or AES-256 cipher as the source's. Only then does `FileReplacement` replace the file.

The permission bits come from the file's bytes (`PDFEncryption`), not from PDFKit: PDFKit reports them only as seen through the password used (everything allowed through the permissions password), and reads some limits as none, such as low-resolution-only printing and no page assembly (found in review with qpdf-made files). The encryption dictionary is found as the object holding `/Filter /Standard`; its `/P`, `/AESV2` and `/AESV3` are read there.

AES-256 files always take the fallback, recognized by `/AESV3` in the file: their plain write can pass the check through the permissions password while no longer opening with the open one. A PDF that opens without a password but carries limits goes through the same check; for one that limits nothing the fallback uses a random permissions password nobody needs.

When verification fails, the fallback writes with explicit `userPasswordOption`, `ownerPasswordOption` and `accessPermissionsOption` (the file's `/P` bits mapped to PDFKit's), then checks the written `/P` and that each password opens it in its role:

- the open password: the typed one, empty for a PDF that opens without one, or asked for.
- the permissions password: the typed or asked-for one. Unknown and the file's bits limit nothing: the open password, with a one-time note, or for a PDF that opens without a password a random one nobody needs, with a note. Unknown and something is limited: asked for.
- The saving layer marks "needs this password" with an internal offer id; the document catches it, asks with one sheet (`askForPassword`), checks the answer on a fresh `PDFDocument` (the open password must open it as `.user`, so the permissions password can't stand in for it; the permissions password must open it as `.owner`), keeps it for later saves and tries again. The host never sees these errors. A wrong password writes nothing and says so. Cancel throws `PluginError.cancelled`, which the host now treats as a cancelled save rather than a failure (a generic change, with a host test and a documents spec delta).

### Saying once that encryption got older

Whether a file used AES-256 is read from its bytes: the standard handler names its crypt filter `/AESV3`, and the encryption dictionary is never compressed or encrypted. When the source had `/AESV3`, the document shows a one-time note in its window after the save (once per window), and the save waits for it to be dismissed so a save that closes the window doesn't take it away unseen. The same mechanism carries the notes about a replaced permissions password. *Alternative:* parse the whole encryption dictionary; not needed for one yes/no.

### Recovery copies are sealed with a key from the password

The plugin derives a 256-bit key with PBKDF2-HMAC-SHA256 (CommonCrypto `CCKeyDerivationPBKDF`, a random 16-byte salt, 600,000 rounds) once, the first time a recovery copy is written, on the recovery store's queue. `scripts/check-plugin-imports.sh` now also accepts the SDK's C modules, such as CommonCrypto. `PDFSnapshot` for a PDF that needs a password encodes as `{"sealed": <AES-GCM box, base64>, "salt": <base64>}` using CryptoKit, so each journal write costs only the AES-GCM pass. A PDF that opens without a password keeps today's plain record.

On relaunch the host opens the file, gets `LockedPDFDocument`, and calls `restore(encoded:)`. It accepts a sealed record and holds it: `unsavedEdits()` returns the same JSON, so the host marks the window edited and the journal keeps the copy as it is; `save` throws "Unlock this PDF to save its changes." `unlock(with:)` derives the key from the typed password and the record's salt; if the box opens, the new document restores the edits before the host is handed it. If it doesn't, the lock screen stays and says the recovered changes need the password used when they were made, or that closing the window with Don't Save drops them. If the box opens but the edits no longer fit the file (it changed since), the lock screen stays too and says so, rather than dropping them unseen. Opening a held copy derives its key at unlocking, on the main thread, about half a second once. *Alternative:* keep the password in the Keychain; rejected, the spec says it's never stored.

### Fixtures

Tests make AES-128 (Core Graphics, 128-bit key), RC4-128 (PDFKit writing a loaded document) and RC4-40 (Core Graphics, 40-bit key) locked PDFs at run time, with and without permission limits. AES-256 can't be made with Apple APIs: a small AES-256 form and a restricted variant are generated once with qpdf (`brew install qpdf`, used only to make the fixture) and checked in under `Tests/Fixtures/`, with the commands in a README next to them.

## Risks / Trade-offs

- The plain write's behavior is observed, not documented; a macOS update could change it. The verify step turns any such change into a failed save or the fallback, never a weakened file without notice.
- AES-256 files are saved with RC4-128, which is far quicker to guess against. The note tells the user once; the maintainer accepted this (2026-11-09).
- A recovery copy from a session unlocked with one password can't be opened after unlocking with the other; the lock screen says so and the user can retype.
- PBKDF2 at 600,000 rounds takes about half a second: once on the recovery queue per window, and once on the main thread when unlocking a PDF that has recovered edits.
- The verify step reads the written copy back into memory, doubling peak memory during a save of a large locked PDF.
