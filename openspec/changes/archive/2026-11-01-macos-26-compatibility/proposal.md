# Proposal

## Why

Peeker supports macOS 26, but its unit tests had only ever run on macOS 27 until the first release workflow ran them on GitHub's macOS 26 runner (2026-11-01). Fifteen PDF tests failed there. Most show that a highlight, text box or signature Peeker saved comes back without the name Peeker gave it, so on macOS 26 moving or removing it in a later session fails with "Can't save: the highlight to remove on page 1 is no longer in this file". The thumbnail-drag tests fail because a copied page isn't linked to its original there. A release needs passing tests, so nothing can ship until this is settled. Dropping macOS 26 isn't an option now: GitHub has no macOS 27 runner, so CI couldn't test at all. Decided on 2026-11-01.

## What Changes

- **Find where macOS 26 loses the names**, with a limit: about five probe runs on GitHub's macOS 26 runner, from a throwaway branch and workflow deleted afterwards. The probes check whether the name is lost on writing or on reading back, and whether a name kept under a key of Peeker's own survives.
- **Fix it when the fix is small and inside the PDF plugin**, with the failing tests passing on macOS 26. Otherwise, **fall back**: on macOS 26, PDF Edit mode is unavailable with the reason that it needs macOS 27, reading is unchanged, and the tests that need macOS 27 run only there. The chosen outcome is recorded in this change's spec and design before the work goes on.
- **Thumbnail drag-to-reorder needs macOS 27**, whatever the outcome: it can't be verified on macOS 26. Rotate and Delete Page keep working there.
- **CI runs the unit tests** on macOS 26 for every push to `main` and every pull request, so a break like this shows up at once.
- Image editing and the rest of the app are untouched.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: Peeker's saved annotations stay findable as its own on macOS 26 (or, as the fallback, PDF Edit mode needs macOS 27); reordering pages by dragging thumbnails needs macOS 27.

## Impact

- `Plugins/pdf`: how marks are named and found (`PDFMarks`, `PDFEditing`), or the Edit mode availability check (`PDFPlugin`); the thumbnails' drag (`PageThumbnails`).
- `Tests/`: the PDF tests that depend on macOS 27 behavior are marked so; new tests for the macOS 26 behavior.
- New `.github/workflows/tests.yml`. A temporary probe branch and workflow, deleted afterwards.
- `openspec/gaps.md` loses its macOS 26 entry; the releases change resumes (its GitHub dry run then passes the tests).
- The `pdf` deltas add to requirements from `pdf-fill-and-sign` and `pdf-page-operations`, so both are archived before this change.
