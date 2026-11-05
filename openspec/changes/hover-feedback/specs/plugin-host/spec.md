# Spec Delta

## ADDED Requirements

### Requirement: Clickable things show where the pointer is

Everything clickable in Peeker that has no button frame of its own SHALL show one hover look while the pointer is over it: a rounded fill in the accent color at low strength, fading in quickly, or at once with Reduce Motion. That covers toolbar buttons, PDF and TIFF page thumbnails, the trail's places, outline rows and Settings' theme cards. A selected item SHALL keep its own look. Framed system buttons SHALL keep macOS's.

#### Scenario: A toolbar tool

- **WHEN** the pointer moves over the Highlight button in a PDF window
- **THEN** a soft accent-colored fill appears behind it, and goes when the pointer leaves

#### Scenario: A page thumbnail

- **WHEN** the pointer moves over page 3's thumbnail while page 1 is selected
- **THEN** page 3's thumbnail shows the hover fill and page 1 keeps its selected look

#### Scenario: The outline

- **WHEN** the pointer moves over a heading in the Markdown outline
- **THEN** the row shows the same accent fill as the toolbar, not a gray one

#### Scenario: Reduce Motion

- **WHEN** Reduce Motion is on and the pointer moves over a theme card in Settings
- **THEN** the fill appears without fading in

#### Scenario: A framed button

- **WHEN** the pointer moves over Open in Peeker in the Peek panel
- **THEN** it looks as macOS draws it, with no extra fill
