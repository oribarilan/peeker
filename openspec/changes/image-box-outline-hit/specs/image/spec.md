## MODIFIED Requirements

### Requirement: Marks stay editable until the window closes

Marks SHALL be selectable, movable, resizable and deletable until the window closes, saved or not, with one Undo step per gesture. A box or ellipse SHALL be selected or dragged only from near its outline, so a click inside it reaches the armed tool; Pixelate and Spotlight SHALL be selected anywhere in their area. Crop and Rotate & Resize after marking SHALL move the marks with the image.

#### Scenario: Moving a saved mark

- **WHEN** the user draws a box, saves, drags the box elsewhere and saves again
- **THEN** the file shows the box only in its new place

#### Scenario: Drawing inside a box

- **WHEN** the user draws a box, presses A and drags from inside the box
- **THEN** an arrow is drawn and the box stays where it was

#### Scenario: Cropping a marked image

- **WHEN** the user draws an arrow on the right half of an image and crops to the right half
- **THEN** the arrow stays on the same part of the picture
