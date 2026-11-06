# Spec Delta

## ADDED Requirements

### Requirement: Plugin tools in the File menu

A plugin SHALL be able to list a tool in the File menu instead of View or Tools, for tools that bring in or write other files. The host SHALL list such tools after Save As…, greyed out like other edit tools when the document can't take them.

#### Scenario: A PDF in front

- **WHEN** a PDF window is in front
- **THEN** the File menu lists Insert Pages from File…, Save Selected Pages As… and Split… after Save As…
