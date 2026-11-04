# Proposal

## Why

The Peek panel is always 55% × 75% of the main screen, centered, and a resize lasts only until Peeker quits (design review finding P1). On a portrait display that's a 792 × 1898 point column, nearly the screen's full height, for every file. Editor and Settings windows already reopen where they were left; the panel should too.

## What Changes

- The panel remembers its size and position across launches, once the user has moved or resized it.
- Before that, its default size is 55% × 75% of the screen's visible area, capped at 900 × 700 points.
- It opens on the display with the pointer: at its saved spot when that's on this display, otherwise with its saved size centered there, and at the default size when the saved size doesn't fit that display.
- It can't be made smaller than 400 × 300 points.
- Settings > General gets a Reset Panel Size button under the Peek panel key, greyed out until the panel has been moved or resized, that forgets the saved frame.
- One frame for every file: the panel still doesn't reshape to the file. Nothing goes in the config.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `peek-panel`: where the panel opens and how big, and that it remembers both.
- `settings`: General's Peek panel section gains Reset Panel Size.

## Impact

- `Sources/Host/PeekPanel/PeekPanel.swift`: default size, minimum size, placement on show, saving the frame when the user moves or resizes it; a new small placement type for the frame rules.
- `Sources/Host/Settings/GeneralPane.swift`, `SettingsWindowController.swift`: the Reset Panel Size button.
- `Sources/Host/App/AppDelegate.swift`: handing the Settings model a way to reset the live panel.
- Tests: new placement tests, `PeekPanelTests`, Settings logic tests.
- `scripts/screen/common.sh` saves and restores the panel's frame around a run; `scripts/screen/record-flows.sh` gains a step.
- CHANGELOG, backlog (drop P1), the design review report (mark P1 fixed). Version bump to 0.11.0-dev.
