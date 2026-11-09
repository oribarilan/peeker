# image Specification

## Purpose

The Image plugin: show photos and other images faster than Preview, fitted to the window, with zoom and the image's details in the sidebar. Viewing only for now.

## Requirements

### Requirement: Decodes images at screen size

By default the plugin SHALL open the common image formats macOS can decode (PNG, JPEG, HEIC, HEIF, AVIF, GIF, TIFF, WebP, BMP, ICO, JPEG XL, JPEG 2000, PSD, OpenEXR) and camera RAW formats (such as DNG, CR2, CR3, NEF, ARW, RAF, ORF and RW2), decoding off the main thread. To open, it SHALL decode the first image in the file at no more pixels than the largest connected screen needs, applying the file's orientation. A file that can't be read or decoded SHALL show an error in its tab.

#### Scenario: Photo taken in portrait

- **WHEN** the user opens a JPEG whose orientation tag says it was taken in portrait
- **THEN** it shows upright

#### Scenario: Corrupt image

- **WHEN** the user opens a file named `.png` that isn't a readable image
- **THEN** the tab says the file isn't a readable image

#### Scenario: Opening a large photo

- **WHEN** the user opens a 4000 × 3000 photo on a screen 2560 pixels wide
- **THEN** the image first shown is no larger than the screen needs, whatever its full size

### Requirement: Shows the image fitted, with zoom

The image SHALL appear fitted to the window, keeping its aspect ratio and resizing with the window. Zoom In and Zoom Out (Cmd+= and Cmd+-) SHALL scale it by 25% per step and pinch SHALL zoom too, between fit and 16 times fit. Zoom to Fit (Cmd+9) SHALL return to fit.

#### Scenario: Zooming into a corner

- **WHEN** the user presses Cmd+= twice on a photo
- **THEN** the image is about 1.56 times its fitted size and can be scrolled

### Requirement: Image details in the sidebar

The sidebar SHALL show the details the file has: dimensions, kind, color model, color profile, resolution, camera, lens, the date it was taken, and file size. For a multi-page TIFF the details SHALL be the page shown, with which page of how many, and SHALL follow the page as it changes.

#### Scenario: iPhone photo

- **WHEN** the user opens a HEIC photo from an iPhone
- **THEN** the sidebar shows its dimensions, the camera model, the lens and when it was taken

#### Scenario: A page of a TIFF

- **WHEN** the third page of a five-page TIFF shows
- **THEN** the sidebar says page 3 of 5 and gives that page's dimensions

### Requirement: Opening images beats Preview

Opening an image with the app not running SHALL draw it no later than Preview shows its window for the same file: faster, or within 10%. The benchmark measures this on a 512×512 PNG, 12 MP JPEG and HEIC photos, and a 48 MP PNG.

#### Scenario: 48 MP PNG

- **WHEN** the benchmark opens the 48 MP PNG fixture in Peeker and in Preview
- **THEN** Peeker's content time is lower than Preview's window time, or at most 10% higher

### Requirement: Cropping an image

In the Editor, Crop (C) SHALL let the user drag a rectangle on the image, adjust it with corner and edge handles, see its size in the image's pixels, and see the area outside it dimmed. Once a rectangle exists, Crop and Cancel buttons SHALL follow it, at the same size whatever the zoom. Crop or Return SHALL crop to it, as one edit; Cancel or Escape SHALL change nothing. A rectangle SHALL stay within the image.

#### Scenario: Cropping
- **WHEN** the user presses C, drags a rectangle over the image's left half and presses Return
- **THEN** the image shows only that half and the document is marked as edited

#### Scenario: Cropping with the mouse
- **WHEN** the user chooses Crop from the toolbar, drags a rectangle and clicks the Crop button beside it
- **THEN** the image is cropped to the rectangle, as one edit

#### Scenario: Cancelling
- **WHEN** the user presses Escape while choosing a rectangle
- **THEN** the rectangle goes away and nothing changes

#### Scenario: Cancelling with the mouse
- **WHEN** the user drags a rectangle and clicks the Cancel button beside it
- **THEN** the rectangle and the buttons go away and nothing changes

#### Scenario: No buttons before a rectangle
- **WHEN** the user chooses Crop and hasn't dragged yet
- **THEN** the image is dimmed and no Crop or Cancel button shows

#### Scenario: Buttons below the rectangle
- **WHEN** the user drags a rectangle with room below it, then scrolls or zooms
- **THEN** the buttons stay just below its bottom-right corner, their right edge on the rectangle's

#### Scenario: Rectangle at the bottom of the window
- **WHEN** the rectangle reaches the bottom edge of the visible image area
- **THEN** the buttons sit inside the rectangle's bottom-right corner, fully visible

### Requirement: Rotate & Resize panel

Rotate & Resize SHALL open a panel just below the toolbar, with buttons to rotate left, rotate right, flip horizontally and flip vertically (also L, R, H and V while it's open), width and height fields in pixels or percent, and an aspect lock, on by default. Applying a new size SHALL resize the image as one edit; enlarging SHALL be allowed. Escape SHALL close the panel.

#### Scenario: Turning twice
- **WHEN** the user clicks Rotate & Resize, then presses R twice
- **THEN** the image is upside down, as two edits

#### Scenario: Resizing to half
- **WHEN** the user sets the width to 50 percent with the lock on and applies it
- **THEN** both sides are half their size

#### Scenario: Toolbar stays clear
- **WHEN** the user opens Rotate & Resize from the toolbar button or the Tools menu
- **THEN** the panel's top edge is below the toolbar, and every toolbar item stays visible and clickable

### Requirement: Rotate & Resize has no default key

Rotate & Resize SHALL have no default key, since rotating is rare; it opens from its toolbar button or the Tools menu, and a key can be set in Settings or the config.

#### Scenario: No default key
- **WHEN** the user presses Cmd+R in an image window with the default config
- **THEN** Rotate & Resize doesn't open

### Requirement: Saving image edits

Image edits and marks SHALL be pending until Cmd+S, undoable one by one, also past saves, while the window is open, kept in the recovery copy, and asked about on close. Saving SHALL apply them to the full-resolution image as the file was when it opened and replace the file in its own format, keeping its metadata with size and orientation updated; JPEG and HEIC at high quality, encoded once from the opened file at each save.

#### Scenario: Crop saved at full size
- **WHEN** the user crops a 4000 × 3000 photo to its left half and saves
- **THEN** the file is 2000 × 3000 pixels, still a JPEG, with its camera and date

#### Scenario: Undo past a save
- **WHEN** the user crops an image, saves, and chooses Undo
- **THEN** the whole image shows again, and saving writes it uncropped

#### Scenario: Recovery
- **WHEN** the user crops and rotates an image and Peeker is force-quit before saving
- **THEN** the next launch reopens it with those edits

### Requirement: Lossless turns

When every edit is a rotation or flip and there are no marks, a JPEG, HEIC or TIFF SHALL keep its image data and only change its recorded orientation.

#### Scenario: Lossless rotation
- **WHEN** the user rotates a JPEG and saves
- **THEN** the image data in the file is unchanged and its orientation says it's turned

### Requirement: Print an image

Printing an image SHALL print it on one page, centered, at its own size as given by its pixel dimensions and resolution (72 pixels per inch when the file states none), shrunk to fit the printable area when larger and never enlarged. The print panel SHALL start in landscape for an image wider than it is tall and in portrait otherwise, and the image SHALL print upright as it is shown.

#### Scenario: A large photo
- **WHEN** the user prints a 4000 × 3000 pixel photo
- **THEN** the print panel starts in landscape and the photo fills the printable area's width or height, centered

#### Scenario: A small icon
- **WHEN** the user prints a 64 × 64 pixel icon with no resolution set
- **THEN** it prints centered at 64 × 64 points, not enlarged

#### Scenario: A rotated photo
- **WHEN** the photo's file says it was taken rotated
- **THEN** it prints upright, as the window shows it

### Requirement: Print every page of a multi-page TIFF

A multi-page TIFF SHALL print every page, each on a sheet of its own by the rules for printing an image, the orientation following the first page.

#### Scenario: A multi-page TIFF
- **WHEN** the user prints a three-page TIFF while its second page shows
- **THEN** the print panel offers three sheets, one per page

### Requirement: Actual size and zooming out

Actual Size (Cmd+0) SHALL show the image at one image pixel per screen pixel, centered. Zoom Out SHALL go below fit, down to an eighth of fit or to actual size when that's smaller. An image smaller than the window SHALL stay centered.

#### Scenario: Actual size of a small icon
- **WHEN** the user opens a 64 × 64 icon and presses Cmd+0
- **THEN** the icon shows at 64 × 64 screen pixels in the middle of the window

#### Scenario: Zooming out
- **WHEN** the user presses Zoom Out four times from fit
- **THEN** the image gets smaller than the window and stays centered

### Requirement: Animated images

An image with several frames that its format animates (GIF, animated PNG, WebP, HEIC sequence) SHALL play in a loop with the frame timing its file gives, in the Editor and the Peek panel, unless Reduce Motion is on, when it SHALL open paused on its first frame. A click on the image, or View > Play Animation in a window, SHALL pause it and resume it; the menu item SHALL be checked while it plays. A multi-page TIFF SHALL never play; its pages show as "Multi-page TIFFs show every page" says.

#### Scenario: Playing
- **WHEN** the user opens an animated GIF
- **THEN** its frames play in a loop

#### Scenario: Pausing
- **WHEN** the user clicks a playing animation
- **THEN** it stops on the current frame, and a second click plays it on from there

#### Scenario: Reduce Motion
- **WHEN** Reduce Motion is on and the user opens an animated GIF
- **THEN** it shows its first frame without playing, until the user clicks it or chooses View > Play Animation

#### Scenario: From the View menu
- **WHEN** an animated GIF plays in a window and the user chooses View > Play Animation
- **THEN** it pauses and the menu item is no longer checked; choosing it again plays it on

### Requirement: Image edit tools

In the Editor, an image Peeker can edit SHALL show Crop and Rotate & Resize in the toolbar and the Tools menu from the start. The Peek panel SHALL have no edit tools.

#### Scenario: Opening a PNG

- **WHEN** the user opens a PNG in the Editor
- **THEN** Crop and Rotate & Resize are in the toolbar, and pressing C starts cropping

### Requirement: Images Peeker can't edit are read-only

An image SHALL be read-only, with the reason, when its format is one Peeker can't write without loss (anything but JPEG, PNG, GIF, TIFF, HEIC, AVIF, BMP and JPEG 2000: camera RAW, WebP, JPEG XL, PSD and EXR among them), when it has more than one frame (an animated GIF, a multi-page TIFF), and when it's over 100 megapixels.

#### Scenario: An animated GIF

- **WHEN** the user opens an animated GIF in the Editor
- **THEN** Crop and Rotate & Resize are greyed out, and the note says the image has several frames

#### Scenario: Camera RAW

- **WHEN** the user opens a DNG
- **THEN** the edit tools are greyed out, and the note says Peeker can't save this format

### Requirement: Sharp when zoomed in

The first time a still image is zoomed past its fitted size, or shown at Actual Size, and the file has more pixels than the screen-size decode, the plugin SHALL decode it at full resolution off the main thread and show that in place of the screen-size picture once ready, at the same place and size. The full decode SHALL be at most 16,384 pixels on the longer side and 100 megapixels, and SHALL be kept until the document closes, or decoded again from the file after a save.

#### Scenario: Actual Size on a large photo

- **WHEN** the user opens a 4000 × 3000 photo and presses Cmd+0
- **THEN** after a moment the window shows the photo's own pixels, one per screen pixel, instead of enlarged screen-size ones

#### Scenario: Zooming in

- **WHEN** the user presses Zoom In on a photo larger than the screen
- **THEN** the full-resolution picture replaces the screen-size one without the view moving or going blank

#### Scenario: A small image

- **WHEN** the user zooms in on a 64 × 64 icon
- **THEN** it isn't decoded again, since the first decode already holds every pixel

#### Scenario: A very large image

- **WHEN** the user zooms in on a 20,000 × 15,000 image
- **THEN** it is decoded again at most 16,384 pixels wide and within 100 megapixels

#### Scenario: Zooming back to fit

- **WHEN** the user zooms in, waits for the sharp picture, then presses Zoom to Fit and zooms in again
- **THEN** the full-resolution picture is still shown and the file isn't decoded a third time

#### Scenario: An animated image

- **WHEN** the user zooms in on an animated GIF
- **THEN** it plays as before and isn't decoded again

### Requirement: Sharp edit previews when zoomed in

Once an image has its full-resolution decode, the Editor SHALL show crop, rotate, flip and resize from it, so edits stay sharp when zoomed. Each edit SHALL show at once from the screen-size decode when the sharp one isn't ready, and the sharp one SHALL replace it only if it still matches the current edits and the file as last loaded or saved.

#### Scenario: Cropping a zoomed photo

- **WHEN** the user presses Cmd+0 on a large photo, waits, then crops it
- **THEN** the cropped image shows at full resolution, not enlarged screen pixels

#### Scenario: Saving while the sharp picture is on its way

- **WHEN** the user crops, saves, and a full decode started before the save finishes after it
- **THEN** the window shows the saved image, never the pixels from before the save

#### Scenario: Undo while the sharp picture is on its way

- **WHEN** the user rotates a zoomed photo and presses Cmd+Z before its sharp preview is ready
- **THEN** the window shows the unrotated photo, and the rotated preview never appears

### Requirement: Multi-page TIFFs show every page

In the Editor, a TIFF with more than one page SHALL show one page at a time, with a thumbnail of every page in the sidebar, the page shown selected. A click on a thumbnail SHALL show that page. The Peek panel SHALL show the first page.

#### Scenario: Thumbnails
- **WHEN** the user opens a five-page TIFF in the Editor
- **THEN** the first page shows, and the sidebar has five thumbnails with the first selected

#### Scenario: A click on a thumbnail
- **WHEN** the user clicks the fourth thumbnail
- **THEN** the fourth page shows

#### Scenario: In the Peek panel
- **WHEN** the user presses Space on a multi-page TIFF in Finder
- **THEN** the Peek panel shows its first page, with no page thumbnails

### Requirement: Moving between TIFF pages

Next Page and Previous Page (Page Down and Page Up), view tools listed only for a multi-page TIFF, SHALL move one page and do nothing past the first or last. Moving to a page SHALL keep the zoom mode: fit stays fit, and another zoom keeps its magnification, scrolled to the top left.

#### Scenario: Next page
- **WHEN** the first page of a multi-page TIFF shows and the user presses Page Down
- **THEN** the second page shows and its thumbnail is selected

#### Scenario: Zoom carries over
- **WHEN** the user zooms a page to about 156% of fit and presses Page Down
- **THEN** the next page shows at the same magnification, scrolled to its top left

#### Scenario: A single image has no page tools
- **WHEN** the user opens a one-page TIFF or a JPEG
- **THEN** the View menu has no Next Page or Previous Page and the sidebar has no thumbnails

### Requirement: Markup tools

An image window's toolbar SHALL have Markup (M), which shows a strip under the toolbar with Arrow (A), Line (L), Box (B, an ellipse with Option held), Text (T), Pixelate (X), Steps (N), Pen (P), Marker (H) and Spotlight (S), each also reachable by its key, which the strip shows beside the tool's icon. Markup SHALL be greyed out with the reason wherever editing is, and absent from the Peek panel.

#### Scenario: Pointing at a button

- **WHEN** the user presses M, then A, and drags from an empty spot to a button in a screenshot
- **THEN** an arrow in the current color points at the button

#### Scenario: Keys on the strip

- **WHEN** the strip shows
- **THEN** each tool's key letter shows beside its icon

#### Scenario: A straight line

- **WHEN** the user presses L and drags across a table row
- **THEN** a straight line without a head runs along the row

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

### Requirement: One remembered markup style

Every markup tool SHALL use one color, picked from six swatches or the system color picker, and one size, S, M or L, scaled to the image. Pixelate's strength and Spotlight's shape, shown in place of the size while that tool is armed or its mark selected, SHALL be kept too. All SHALL be remembered across launches. Changing any of them with a mark selected SHALL change that mark.

#### Scenario: Recoloring a mark

- **WHEN** the user selects an arrow and clicks the blue swatch
- **THEN** the arrow turns blue, and the next mark drawn is blue too, also after a relaunch

#### Scenario: Oval stays chosen

- **WHEN** the user picks Oval for Spotlight and relaunches Peeker
- **THEN** the next spotlight is an oval

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

### Requirement: Copying the marked image

With no mark selected, Cmd+C SHALL copy the whole image with its edits and marks at full resolution. With a mark selected, Cmd+C SHALL copy the mark, and Cmd+V SHALL add a copy of it, offset a little.

#### Scenario: Pasting into a chat

- **WHEN** the user marks up a screenshot, presses Cmd+C and pastes into another app
- **THEN** the pasted image shows the marks

### Requirement: Marks are sharp on screen

Marks SHALL draw over the image at the screen's resolution, so their lines and text stay smooth at any zoom, also on a small image. Pixelate SHALL show the image's own blocks. Saving and copying SHALL paint the marks into the image at its full resolution.

#### Scenario: Zooming in on an arrow

- **WHEN** the user draws an arrow on a 300 × 200 screenshot and zooms to 400%
- **THEN** the arrow's edges are smooth, not stepped in image pixels

### Requirement: Markup text style

Markup text SHALL have a font (System, Serif, Rounded or Mono), bold, italic and an effect: Plain, Outline (the default, a thin contrasting outline), Shadow or Label (a filled rounded box, also chosen by holding Option when placing the text). The strip SHALL offer these in one menu beside the size while Text is armed or a text mark is selected. The style SHALL be remembered like the color and size, and changing it with a text mark selected SHALL change that mark.

#### Scenario: Italic serif

- **WHEN** the user arms Text, picks Serif and Italic, and types a caption
- **THEN** the caption is in an italic serif font, and the next text is too, also after a relaunch

#### Scenario: Restyling a label

- **WHEN** the user selects a text mark and picks Shadow
- **THEN** the text loses its outline and casts a shadow
