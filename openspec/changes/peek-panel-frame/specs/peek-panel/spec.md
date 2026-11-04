# Spec Delta

## ADDED Requirements

### Requirement: The Peek panel opens at a remembered size

Once the user has moved or resized the Peek panel, it SHALL open with that size and position, also after Peeker quits and starts again. Until then it SHALL open at 55% of the screen's visible width and 75% of its height, at most 900 × 700 points, centered. The user SHALL NOT be able to make it smaller than 400 × 300 points. Every file SHALL open in the same frame.

#### Scenario: A first Space on a portrait display

- **WHEN** the user presses Space on a file for the first time on a 1440 × 2560 point display
- **THEN** the panel is 792 × 700 points, centered on the display

#### Scenario: After a resize and a relaunch

- **WHEN** the user drags the panel to the top left, makes it 600 × 500 points, quits Peeker, starts it and presses Space on another file
- **THEN** the panel opens 600 × 500 points at the top left

#### Scenario: Too small

- **WHEN** the user drags the panel's corner inward as far as it goes
- **THEN** the panel stops at 400 × 300 points

### Requirement: The Peek panel opens on the display with the pointer

The Peek panel SHALL open on the display that has the pointer. When its saved frame lies on that display, it SHALL open there as saved. Otherwise it SHALL keep its saved size centered on that display, or open at the default size centered there when the saved size doesn't fit that display.

#### Scenario: Working on the second display

- **WHEN** the panel was last left on the main display and the user presses Space in a Finder window on the second display, with the pointer there
- **THEN** the panel opens on the second display at its saved size, centered

#### Scenario: A display that's gone

- **WHEN** the panel was last left on a large external display that's no longer connected, and it's bigger than the laptop's screen
- **THEN** it opens on the laptop's screen at the default size, centered
