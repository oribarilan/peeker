## ADDED Requirements

### Requirement: Markup text style

Markup text SHALL have a font (System, Serif, Rounded or Mono), bold, italic and an effect: Plain, Outline (the default, a thin contrasting outline), Shadow or Label (a filled rounded box, also chosen by holding Option when placing the text). The strip SHALL offer these in one menu beside the size while Text is armed or a text mark is selected. The style SHALL be remembered like the color and size, and changing it with a text mark selected SHALL change that mark.

#### Scenario: Italic serif

- **WHEN** the user arms Text, picks Serif and Italic, and types a caption
- **THEN** the caption is in an italic serif font, and the next text is too, also after a relaunch

#### Scenario: Restyling a label

- **WHEN** the user selects a text mark and picks Shadow
- **THEN** the text loses its outline and casts a shadow

## MODIFIED Requirements

### Requirement: What each markup tool draws

Text SHALL be drawn in its style: plain, with a thin outline, with a shadow, or as a label on a filled rounded box. Steps SHALL number themselves in order and renumber when one is deleted. Pixelate SHALL hide its rectangle in blocks, their size set by a Strength slider from fine to coarse, coarse enough by default not to read back. Spotlight SHALL dim the image outside its rectangles or ovals, of which there can be several.

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
