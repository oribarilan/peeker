## ADDED Requirements

### Requirement: The Peek panel views; Open in Peeker moves the file to the Editor

The Peek panel SHALL only view, never edit. Its button SHALL read Open in Peeker, so the panel can be told apart from Quick Look, and SHALL close the panel and open the file in the Editor, ready to edit.

#### Scenario: Editing from the Peek panel

- **WHEN** the user clicks Open in Peeker in the Peek panel on a PDF
- **THEN** the panel closes and the PDF opens in the Editor with its edit tools in the toolbar

## REMOVED Requirements

### Requirement: The Peek panel views; Open moves the file to a window
**Reason**: The button is now Open in Peeker, and the window is the always-editable Editor.
**Migration**: See "The Peek panel views; Open in Peeker moves the file to the Editor".

## MODIFIED Requirements

### Requirement: The app can open at login

Open at Login, in the menu bar icon's menu and in Settings' General pane, SHALL register or unregister the app as a login item, because the Peek panel only works while the app runs. The app menu SHALL NOT have it. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the Peek panel works without launching it by hand

#### Scenario: The app menu

- **WHEN** an Editor window is open and the user opens the Peeker menu
- **THEN** it has Settings… but no Open at Login
