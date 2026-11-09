# Tasks

## 1. Contract and host

- [x] 1.1 Failing tests, then the `Zooming` contract in PeekerKit (percent, range, setZoom around a point, change callback, `pinchesNatively`).
- [x] 1.2 Failing tests, then the host's Cmd+scroll and pinch handling for Editor windows and the Peek panel (synthetic events), skipping native pinch.
- [x] 1.3 Failing tests, then the zoom pill in Editor windows: hover, −/+ through the zoom tools, the percentage menu, updates on every zoom, accessibility, Reduce Motion.

## 2. Formats

- [x] 2.1 PDF and image adopt the contract (PDF's pinch goes through the host; image keeps its native pinch); the conformance declared on each class so the static plugin library keeps it.
- [x] 2.2 Text and Markdown adopt the contract, their remembered sizes unchanged.
- [x] 2.3 Failing tests, then table zoom: tools, font size applied to cells and rows, remembered.
- [x] 2.4 Failing tests, then data zoom: tools, tree and Show Text together, remembered.

## 3. Checks

- [x] 3.1 Screen steps in the viewer flow: Cmd+scroll on a PDF changes it, hovering a text file shows the pill and its Zoom In makes the text larger; run-peeker skill; specs; CHANGELOG; all unit tests, warning-free build, `openspec validate --all --strict`.

## Workflow follow-up

- Review by oracle, commit, minor version bump in its own commit, screen flows with the maintainer's go, archive, push, install.
