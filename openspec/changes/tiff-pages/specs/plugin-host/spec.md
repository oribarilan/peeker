# Spec Delta

## ADDED Requirements

### Requirement: Page Up and Page Down as shortcuts

A tool's shortcut MAY be Page Up or Page Down, written `pageup` and `pagedown` in the config, with or without modifiers. Since they type nothing, a view tool MAY use them without Command, Option or Control. Menus SHALL show them with the system's symbols, and the Settings recorder SHALL accept them.

#### Scenario: Rebinding to Page Up
- **WHEN** the config sets `plugins.image.tools.previous-page.shortcut` to `opt+pageup`
- **THEN** Option-Page Up shows the previous page and plain Page Up no longer does

#### Scenario: Recording Page Down
- **WHEN** the user records Page Down for a view tool in Settings
- **THEN** it's accepted

## MODIFIED Requirements

### Requirement: Single-key edit tool shortcuts

An edit tool's shortcut MAY be a single key with no Command, Option or Control. Such a shortcut SHALL run its tool in the Editor while no text field, text view or text box has keyboard focus; otherwise, and in the Peek panel, the key SHALL go where it would have gone. The Settings window's recorder SHALL accept single keys for edit tools and keep requiring a modifier for view tools, except Page Up and Page Down.

#### Scenario: A letter in the Editor
- **WHEN** an image is open in the Editor and the user presses C
- **THEN** cropping starts

#### Scenario: Typing
- **WHEN** a text field has focus and the user types "c"
- **THEN** the "c" goes into the field

#### Scenario: Recording a single key
- **WHEN** the user records C for an edit tool in Settings
- **THEN** it's accepted; for a view tool it's refused as before
