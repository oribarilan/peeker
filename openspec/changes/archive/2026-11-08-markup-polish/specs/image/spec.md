## ADDED Requirements

### Requirement: Marks are sharp on screen

Marks SHALL draw over the image at the screen's resolution, so their lines and text stay smooth at any zoom, also on a small image. Pixelate SHALL show the image's own blocks. Saving and copying SHALL paint the marks into the image at its full resolution.

#### Scenario: Zooming in on an arrow

- **WHEN** the user draws an arrow on a 300 × 200 screenshot and zooms to 400%
- **THEN** the arrow's edges are smooth, not stepped in image pixels

## MODIFIED Requirements

### Requirement: Markup tools

An image window's toolbar SHALL have Markup (M), which shows a strip under the toolbar with Arrow (A), Box (B, an ellipse with Option held), Text (T), Pixelate (X), Steps (N), Pen (P), Marker (K) and Spotlight (S), each also reachable by its key, which the strip shows beside the tool's icon. Markup SHALL be greyed out with the reason wherever editing is, and absent from the Peek panel.

#### Scenario: Pointing at a button

- **WHEN** the user presses M, then A, and drags from an empty spot to a button in a screenshot
- **THEN** an arrow in the current color points at the button

#### Scenario: Keys on the strip

- **WHEN** the strip shows
- **THEN** each tool's key letter shows beside its icon

### Requirement: What each markup tool draws

Text SHALL be plain with a thin outline or a label on a filled rounded box. Steps SHALL number themselves in order and renumber when one is deleted. Pixelate SHALL hide its rectangle in blocks, their size set by a Strength slider from fine to coarse, coarse enough by default not to read back. Spotlight SHALL dim the image outside its rectangles or ovals, of which there can be several.

#### Scenario: Steps renumber

- **WHEN** the user drops steps 1, 2 and 3 and deletes step 2
- **THEN** the remaining badges read 1 and 2

#### Scenario: Hiding a password

- **WHEN** the user pixelates a password and saves
- **THEN** the saved file shows coarse blocks where the password was

#### Scenario: A stronger pixelate

- **WHEN** the user selects a pixelate mark and drags Strength to the right
- **THEN** its blocks grow larger

#### Scenario: An oval spotlight

- **WHEN** the user chooses Oval for Spotlight and drags over a face
- **THEN** everything outside an oval around the face dims

### Requirement: One remembered markup style

Every markup tool SHALL use one color, picked from six swatches or the system color picker, and one size, S, M or L, scaled to the image. Pixelate's strength and Spotlight's shape, shown in place of the size while that tool is armed or its mark selected, SHALL be kept too. All SHALL be remembered across launches. Changing any of them with a mark selected SHALL change that mark.

#### Scenario: Recoloring a mark

- **WHEN** the user selects an arrow and clicks the blue swatch
- **THEN** the arrow turns blue, and the next mark drawn is blue too, also after a relaunch

#### Scenario: Oval stays chosen

- **WHEN** the user picks Oval for Spotlight and relaunches Peeker
- **THEN** the next spotlight is an oval
