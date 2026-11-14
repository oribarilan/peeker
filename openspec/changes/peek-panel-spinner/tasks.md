# Tasks

## 1. The spinner

- [x] 1.1 Change the Peek panel's spinner test in `Tests/DocumentLifecycleTests.swift` to expect a spinner after 700 ms of a 900 ms open, gone once the file shows; see it fail.
- [x] 1.2 Drop the editing-only condition on the spinner in `DocumentViewController.load()`. Verify the tests pass.

## 2. Checks

- [x] 2.1 Run `scripts/bench-ab.sh` against `main` once, with the maintainer's go; no panel regression. (2026-11-14: two runs each flagged different panel cases, and none repeated; `large.log` went from +20% to -3%.)
- [ ] 2.2 By hand, with the maintainer's go: Space on `3 Spinner - slow to open.png` shows the spinner, then the image.

## 3. Wrap-up

- [x] 3.1 CHANGELOG line under Unreleased; `scripts/build.sh test` passes with no warnings; `openspec validate --all` passes.
