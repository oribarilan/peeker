## ADDED Requirements

### Requirement: Unavailable commands

A document SHALL be able to report that one of its commands can't run right now, with a reason. The host SHALL then grey out that command's menu item and toolbar button, show the reason as the button's tooltip, and ignore its shortcut. When the document no longer reports a reason, the command SHALL work again without reopening the file.

#### Scenario: A command greyed out with its reason
- **WHEN** a document reports "This PDF's permissions don't allow page changes." for Rotate Left
- **THEN** Rotate Left is greyed out in the Commands menu and the toolbar, the toolbar button's tooltip shows that sentence, and Cmd+L does nothing

#### Scenario: Available again
- **WHEN** a command's reason goes away, such as Delete Page once not every page is selected
- **THEN** its menu item and button work again
