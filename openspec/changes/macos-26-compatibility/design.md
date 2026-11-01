# Design

## Context

Peeker names each annotation it makes with `peeker-<UUID>` in the annotation's `/NM` entry (`PDFMarks`: set with `setValue(_:forAnnotationKey: .name)`, read back by `PDFMarks.id(of:)` and `find(_:on:)`). Every later edit of a saved mark (move, resize, new text, removal) finds it by that name when saving (`PDFEditing`), and fails with "is no longer in" when it can't. Text boxes also carry a custom style key. The thumbnail drag relies on PDFKit's copy of a dragged page sharing its `pageRef` with the original (`PeekerPDFDocument.order`). On GitHub's `macos-26` runner, 13 of the 15 failing tests can't find a saved mark by its name and 2 are drag tests; everything passes on macOS 27, where development happens. No Mac on macOS 26 is available, and GitHub has no macOS 27 runner. `bench.yml` already runs the unit tests on every pull request.

## Goals / Non-Goals

**Goals:**
- Every unit test passes on GitHub's `macos-26` runner, so releases can ship.
- No behavior on macOS 26 that hasn't been verified there.

**Non-Goals:**
- Screen tests on macOS 26 (they need a real screen on that OS).
- Working around other apps' annotations or PDFs saved by other tools.

## Decisions

**1. Probe on CI, at most about five runs.** A throwaway branch `probe/macos-26` carries a probe test suite and a workflow that runs only it on `macos-26` and prints its findings. In one PDF, the probe:
- sets `/NM` on an annotation, saves with `write(to:)`, then reads the file back two ways: through PDFKit (`value(forAnnotationKey: .name)`) and through CoreGraphics (the raw annotation dictionary), which tells whether the name is lost on write or only hidden on read;
- does the same for a key of Peeker's own (`/PeekerID`) and for the style key text boxes already use;
- compares `pageRef` of `PDFPage.copy()` with the original's.
The branch and workflow are deleted once the decision below is made. Considered: a local macOS 26 virtual machine (about 25 GB, kept as the next step only if the probes are inconclusive).

**2. The decision rule.** Fix it when the probes show a way to keep or recover the name that stays inside `PDFMarks` and `PDFEditing` (reading `/NM` through CoreGraphics when PDFKit hides it, or writing the id under a key that survives), with every PDF test passing on both macOS 26 and 27. Files saved by earlier builds keep working: their `/NM` is still read. Otherwise, fall back (decision 3). Either way the outcome, with what the probes showed, goes into this design and the spec before the work goes on.

**3. The fallback.** `PDFPlugin.open` gives the reason "PDF Edit mode needs macOS 27." on macOS 26, through the existing unavailable-Edit-mode path (the toolbar's Edit button is disabled with that reason). The spec's first requirement is then replaced by one saying so. Tests that edit marks get a Swift Testing trait that enables them only on macOS 27 or later, and a new test checks the reason on macOS 26.

**4. Drag off on macOS 26.** `PageThumbnails.allowsDragging` also requires macOS 27 (`ProcessInfo.isOperatingSystemAtLeast`). The drag tests run only on macOS 27; a new test checks thumbnails aren't draggable on macOS 26. The page commands don't depend on drags and stay.

**5. A tests workflow.** `.github/workflows/tests.yml` runs `scripts/build.sh test` on `macos-26` for every push to `main`. Pull requests are already covered by the unit-test step in `bench.yml`, so running the tests there twice would only cost runner time. It's the check for this change: green on `main` after the fix or fallback lands.

## Risks / Trade-offs

- [The probes don't explain it within five runs] → Fall back; a macOS 26 virtual machine stays available for a later attempt.
- [Other macOS 26 differences that unit tests don't reach] → Screen tests run only on macOS 27; this is noted in `openspec/gaps.md` once the change lands.
- [A key of Peeker's own isn't recognized by other apps] → Only Peeker reads it; `/NM` keeps being written too, so other apps see the same file as before.
- [Turning Edit mode off on 26 removes a feature some users have] → Peeker has no releases yet, so nobody loses it; it returns once fixed.

## Migration Plan

Lands on `main` once every test passes on both systems; then the releases change resumes and its GitHub dry run passes its tests.
