## ADDED Requirements

### Requirement: Zooming with the trackpad and mouse

In every format that zooms, Cmd+scroll and pinch SHALL zoom the document under the pointer, in Editor windows and in the Peek panel, within the same limits as the zoom keys and around the point under the pointer where the format allows. A plain scroll SHALL keep scrolling.

#### Scenario: Cmd+scroll on a PDF
- **WHEN** the user holds Cmd and scrolls up over a PDF's pages
- **THEN** the pages get larger, and scrolling without Cmd scrolls them again

#### Scenario: Pinch in the Peek panel
- **WHEN** the user pinches outward over a text file in the Peek panel
- **THEN** the text gets larger, and Finder keeps the keyboard

### Requirement: The zoom control

In Editor windows, a document that zooms SHALL show a small control at the bottom right of its content while the pointer is over it: Zoom Out, the zoom as a percentage, and Zoom In. Clicking the percentage SHALL offer Actual Size, Zoom to Fit where the format has it, and fixed sizes within its limits. The control SHALL follow every way of zooming, SHALL be reachable by VoiceOver, and while hidden SHALL take no clicks. The Peek panel SHALL show none.

#### Scenario: Zooming a text file from the control
- **WHEN** the user hovers over a text file at its default size and clicks the control's Zoom In
- **THEN** the text gets larger and the control reads more than 100%

#### Scenario: The control follows the keys
- **WHEN** the user presses Cmd+0 in a PDF
- **THEN** the control reads 100%
