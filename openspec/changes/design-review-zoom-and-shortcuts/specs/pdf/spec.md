## ADDED Requirements

### Requirement: Actual Size and Zoom to Fit

Actual Size (Cmd+0) SHALL show the pages at 100% scale, and Zoom to Fit (Cmd+9) SHALL go back to fitting the pages to the window, as a PDF opens, following the window as it resizes. Both SHALL be listed in the View menu only, with no toolbar button, in the Editor and wherever the PDF's other zoom tools are offered.

#### Scenario: Actual size, then fit

- **WHEN** the user presses Cmd+0 in a PDF and then Cmd+9
- **THEN** the pages show at 100% after Cmd+0, and after Cmd+9 they fit the window again and keep fitting it when the window is resized

#### Scenario: Fit after zooming in

- **WHEN** the user presses Cmd+= twice in a PDF and then Cmd+9
- **THEN** the pages fit the window as they did when the PDF opened

## MODIFIED Requirements

### Requirement: Signatures are drawn and placed by clicking

Sign SHALL open a pad where the user draws a signature with the trackpad or mouse, with Clear, Cancel and Done. The pad SHALL look like paper in either appearance: a white canvas with a gray edge and a gray signature line. After Done, the signature SHALL follow the pointer over the page until a click places it there. On Cmd+S each signature SHALL be written as a standard ink annotation made of its strokes.

#### Scenario: Signing a contract

- **WHEN** the user chooses Sign, draws their signature, clicks Done and clicks on the signature line
- **THEN** the signature appears on the line, and after saving Preview shows it and can move it

#### Scenario: The pad in dark mode

- **WHEN** the Mac uses the dark appearance and the user chooses Sign
- **THEN** the pad's canvas is white with a visible gray edge, and its signature line shows in gray
