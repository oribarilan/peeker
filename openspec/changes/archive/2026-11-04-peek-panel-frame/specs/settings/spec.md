# Spec Delta

## ADDED Requirements

### Requirement: General resets the Peek panel's size

The General pane's Peek panel section SHALL have a Reset Panel Size button, greyed out until the user has moved or resized the panel. It SHALL forget the panel's saved size and position, so the panel opens at its default size and place, including a panel showing at the time.

#### Scenario: Resetting

- **WHEN** the user has made the panel 600 × 500 points and clicks Reset Panel Size
- **THEN** the button greys out, and the next Space opens the panel at its default size, centered

#### Scenario: Nothing to reset

- **WHEN** the panel has never been moved or resized
- **THEN** Reset Panel Size is greyed out
