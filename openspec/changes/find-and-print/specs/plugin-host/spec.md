## ADDED Requirements

### Requirement: Print from document windows

The File menu SHALL have Print (Cmd+P). In a document window it SHALL show the system print panel for the current document, as a sheet on the window, with the file's name as the job title. What prints SHALL be decided by the document's plugin and SHALL include unsaved edits, and typing in progress (such as in a PDF text box) SHALL count. Print SHALL be unavailable when no document window is in front, while the document is still opening or failed to open, and for a plugin that offers no printing.

#### Scenario: Printing a document
- **WHEN** the user presses Cmd+P in a document window showing an opened file
- **THEN** the system print panel opens as a sheet on that window, titled with the file's name

#### Scenario: Unsaved edits print
- **WHEN** a document has unsaved edits and the user prints it
- **THEN** the printout shows the document with those edits

#### Scenario: Nothing to print
- **WHEN** the front window is the Space panel or the Settings window, or the document is still opening
- **THEN** Print is greyed out

### Requirement: Find menu items

The Edit menu SHALL offer Find… (Cmd+F), Find Next (Cmd+G) and Find Previous (Shift+Cmd+G). Each SHALL reach the focused view's find, and SHALL be greyed out where the view offers no find. Because they are menu shortcuts, Settings SHALL refuse Cmd+P, Cmd+F, Cmd+G and Shift+Cmd+G for plugin commands, as it does other menu keys.

#### Scenario: Find Previous in a text file
- **WHEN** the user searched a text file and presses Shift+Cmd+G
- **THEN** the selection moves to the previous match

#### Scenario: No find in an image
- **WHEN** an image document is in front
- **THEN** Find…, Find Next and Find Previous are greyed out

#### Scenario: A menu key refused for a command
- **WHEN** the user records Cmd+P for a plugin command in Settings
- **THEN** the recorder refuses it and names Print
