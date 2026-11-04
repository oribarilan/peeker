# Spec Delta

## ADDED Requirements

### Requirement: Toolbar buttons show their key

Each tool's toolbar button in an Editor window SHALL sit on a capsule of its own and show its key beside its icon, after a thin separator ("icon | key"), or its icon alone without a key. Sidebar, Back and Forward SHALL show no key there. With `showShortcuts` false the keys SHALL go away in every open window at once. Buttons SHALL keep their names for VoiceOver and the overflow menu; the active tool's capsule SHALL fill with the accent color.

#### Scenario: A PDF's toolbar

- **WHEN** a PDF is open in the Editor with the default keys
- **THEN** each tool is on its own capsule, Text Box shows T, Sign S and Highlight H beside their icons, and Rotate Left, Rotate Right and Delete Page show their icons alone

#### Scenario: The active tool

- **WHEN** the user presses H in a PDF
- **THEN** Highlight's capsule fills with the accent color, and the others stay plain

#### Scenario: Captions off

- **WHEN** the user clears "Show shortcuts in the toolbar"
- **THEN** the keys go away from the toolbar, and stay in the tooltips, the menus and Settings

### Requirement: Every icon-only button has a tooltip

Every toolbar button, and every button anywhere in Peeker that shows only an icon, SHALL have a tooltip with its name, followed by its key in parentheses when it has one. A tool that's greyed out SHALL show why it's off instead.

#### Scenario: Hovering Highlight

- **WHEN** the pointer rests on the Highlight button in a PDF window
- **THEN** a tooltip reads "Highlight (H)"

#### Scenario: A greyed tool

- **WHEN** the pointer rests on Text Box in a digitally signed PDF
- **THEN** the tooltip says why the PDF can't be edited

### Requirement: A tool can show a tip on first use

A plugin SHALL be able to give a tool a short tip. The first time the user runs that tool, from the toolbar, the menu or its key, Peeker SHALL show the tip in a bubble from the tool's toolbar button, closing it on the next click anywhere, and SHALL not show that tool's tip again. With the toolbar hidden or the tool in the overflow menu, the tip SHALL wait for a run where its button shows.

#### Scenario: The first highlight

- **WHEN** the user presses H for the first time in a PDF window
- **THEN** a bubble from the Highlight button reads "Select text and press H, or drag across text while Highlight is on."

#### Scenario: The second time

- **WHEN** the user has seen Highlight's tip and runs Highlight again
- **THEN** no bubble appears
