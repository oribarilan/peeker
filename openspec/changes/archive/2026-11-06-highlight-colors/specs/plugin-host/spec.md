## ADDED Requirements

### Requirement: A tool can offer choices

A plugin MAY give a tool a short list of choices, each with a title and optionally a color. The host SHALL show them twice: as a menu opened by an arrow on the tool's toolbar button, and as a submenu named by the plugin, right after the tool's menu item. Each choice SHALL show its color as a dot before its title, and a choice the document reports as on SHALL be checked in both.

#### Scenario: The highlight colors

- **WHEN** a PDF is open in the Editor and the user clicks the arrow on the Highlight button
- **THEN** a menu lists Yellow, Green, Blue, Pink and Purple, each with its colored dot, and the current color is checked

#### Scenario: The submenu

- **WHEN** a PDF is open in the Editor and the user opens Tools
- **THEN** Highlight Color follows Highlight, and its submenu lists the same colors with the current one checked

#### Scenario: A tool without choices

- **WHEN** a tool has no choices, such as Rotate Left
- **THEN** its toolbar button has no arrow and its menu item no submenu

### Requirement: Picking a tool's choice

Picking a choice SHALL run it as a tool of the document. The choices SHALL be available, or greyed out with the reason, exactly when their tool is. Clicking the tool's button itself, away from the arrow, SHALL run the tool as before, and the button SHALL keep showing the tool as active while it is.

#### Scenario: Picking from the toolbar

- **WHEN** the user picks Green from the Highlight button's menu
- **THEN** the PDF runs Green, Highlight is shown active, and the next look at the menu has Green checked

#### Scenario: The button itself

- **WHEN** the user clicks the Highlight button away from its arrow
- **THEN** Highlight runs as it did before, with no menu

#### Scenario: Greyed out

- **WHEN** Highlight is greyed out because the PDF is read-only
- **THEN** the arrow's menu items and the submenu's items are greyed out too, with the same reason
