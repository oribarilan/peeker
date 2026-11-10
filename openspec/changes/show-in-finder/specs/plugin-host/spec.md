## ADDED Requirements

### Requirement: Show in Finder

File SHALL offer Show in Finder, right after Open With, with no default key; only an Editor window answers it, so it's greyed out elsewhere. The Editor toolbar SHALL have a Show in Finder button after Back, Forward and Open With and before the plugin's tools, in every window. Both SHALL open a Finder window with the tab's file selected and bring Finder forward, without changing the document.

#### Scenario: From the File menu

- **WHEN** notes.md is open in a tab and the user chooses File > Show in Finder
- **THEN** Finder comes forward with notes.md selected in its folder

#### Scenario: From the toolbar

- **WHEN** a PDF is open and the user clicks the folder button in the toolbar
- **THEN** Finder comes forward with the PDF selected

#### Scenario: No Editor window

- **WHEN** only Settings is open
- **THEN** File > Show in Finder is greyed out
