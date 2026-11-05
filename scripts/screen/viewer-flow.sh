#!/bin/bash
# The viewer flow on screen: find in a PDF (its bar below the toolbar), the print panel for each format, hiding the
# sidebar from the View menu (still hidden after a save) and showing it from the toolbar, Wrap Lines' checkmark,
# unlocking a password-protected PDF, Actual Size and Zoom to Fit on that PDF, Actual Size and zooming out on an image,
# an animated GIF playing, pausing on a click and playing on, and Actual Size on a photo larger than the screen
# showing its own pixels. Writes screenshots and results.txt (one ok/FAIL line per check) to its evidence folder, plus a screen
# recording with SCREEN_RECORD=1.
#
# Takes over the mouse and keyboard for about 50 seconds: the screen must be unlocked and left alone. Clicks and keys
# are sent only while Peeker is in front.
# usage: viewer-flow.sh [path/to/Peeker.app]
FLOW=viewer
source "$(dirname "$0")/common.sh" "$@"

PAGES="$OUT/pages.pdf" LOCKED="$OUT/locked.pdf" NOTES="$OUT/notes.txt" MD="$OUT/notes.md" PHOTO="$OUT/photo.png" GIF="$OUT/blink.gif"
STRIPES="$OUT/stripes.png" TIFF="$OUT/scan.tiff"
"$PDF" pages "$PAGES" 4
"$PDF" locked "$LOCKED" secret 3
printf 'Plain text to print.\n' > "$NOTES"
printf '# Notes\n\nMarkdown to print.\n' > "$MD"
sips -s format png -z 900 1600 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns --out "$PHOTO" >/dev/null
# Two 64-pixel frames, red then blue, 0.4 s each, looping.
base64 -d <<< 'R0lGODdhQABAAKIAAAAAAAAA//8AAP///wAAAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQFKAAEACwAAAAAQABAAAADRyi63P4wykmrvTjrzbv/YCiOZGmeaKqubOu+cCzPdG3feK7vfO//wKBwSCwaj8ikcslsOp/QqHRKrVqv2Kx2y+16v+CwWJAAACH5BAUoAAQALAAAAABAAEAAAANHGLrc/jDKSau9OOvNu/9gKI5kaZ5oqq5s675wLM90bd94ru987//AoHBILBqPyKRyyWw6n9CodEqtWq/YrHbL7Xq/4LA4kAAAOw==' > "$GIF"
# Two pages of different sizes, as a scanner writes them.
sips -s format tiff "$PHOTO" --out "$OUT/page1.tiff" >/dev/null
sips -s format tiff -z 400 300 "$PHOTO" --out "$OUT/page2.tiff" >/dev/null
tiffutil -cat "$OUT/page1.tiff" "$OUT/page2.tiff" -out "$TIFF" >/dev/null 2>&1
# Larger than any screen, in one-pixel black and white columns: enlarged screen-size pixels would read as gray.
"$DRIVE" stripes "$STRIPES" 6000 4000

front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.5; }
# Opens a file in the running app (it joins the window as a tab) and waits for it in front.
show() { open -a "$APP" "$1"; "$DRIVE" wait Peeker window "$(basename "$1")"; front; }
# A short fingerprint of what the named window shows now.
looks() { "$DRIVE" shot Peeker "$OUT/look.png" "$1" && shasum "$OUT/look.png" | cut -c1-12; }
thumbnails() { "$DRIVE" tree Peeker 12 | grep -cE '^ *AXStaticText = [0-9]+$'; }

launch "$PAGES"
front
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
record viewer 90

# Find: the bar counts matches, and Find Next steps through them.
find_status() { "$DRIVE" tree Peeker 14 | grep -oE '[0-9]+ of [0-9]+|[0-9]+ matches|Not found' | head -1; }
"$DRIVE" keys Peeker cmd+f
"$DRIVE" wait Peeker control Done
"$DRIVE" type Peeker "Page"
for _ in $(seq 30); do [ "$(find_status)" = "1 of 4" ] && break; sleep 0.1; done
check "Find shows the first of four matches" "$(find_status)" "1 of 4"
read -r _ ty _ th <<< "$("$DRIVE" frame Peeker AXToolbar || echo "0 0 0 0")"
read -r _ fy _ _ <<< "$("$DRIVE" frame Peeker AXTextField || echo "0 -1 0 0")"
check "The find bar sits below the toolbar" "$([ "$th" -gt 0 ] && [ "$fy" -ge $((ty + th)) ] && echo yes)" yes
"$DRIVE" keys Peeker cmd+g && sleep 0.5
check "Find Next steps to the second" "$(find_status)" "2 of 4"
"$DRIVE" shot Peeker "$OUT/1-find.png" pages.pdf
"$DRIVE" press Peeker Done

# Print: each format opens the print panel as a sheet, with its preview.
step=2
for file in "$PAGES" "$NOTES" "$MD" "$PHOTO"; do
    name=$(basename "$file")
    show "$file"
    "$DRIVE" keys Peeker cmd+p
    check "Print opens the panel for $name" "$("$DRIVE" wait Peeker sheet --timeout 5 2>/dev/null && echo yes)" yes
    sleep 1
    "$DRIVE" shot Peeker "$OUT/$step-print-$name.png" "$name"
    "$DRIVE" press Peeker Cancel
    "$DRIVE" wait Peeker sheet --gone
    step=$((step + 1))
done

# The sidebar on a text file: View > Hide Sidebar hides it, an edit and Cmd+S keep it hidden, and the toolbar's
# sidebar button shows it again. Then Wrap Lines shows in View whether it's on.
sidebar() { "$DRIVE" tree Peeker 14 | grep -c 'Line endings'; }
show "$NOTES"
check "A text file shows its sidebar" "$([ "$(sidebar)" -gt 0 ] && echo yes)" yes
"$DRIVE" menu Peeker View "Hide Sidebar" && sleep 0.5
check "View > Hide Sidebar hides it" "$(sidebar)" 0
"$DRIVE" type Peeker "More. "
"$DRIVE" keys Peeker cmd+s && sleep 1
check "It stays hidden after a save" "$(sidebar)" 0
button=$("$DRIVE" tree Peeker 12 | grep -o 'AXButton “[^”]*[Ss]idebar[^”]*”' | head -1 | sed 's/AXButton “\(.*\)”/\1/')
"$DRIVE" press Peeker "$button" && sleep 0.5
check "The toolbar's sidebar button shows it again" "$([ "$(sidebar)" -gt 0 ] && echo yes)" yes
check "View checks Wrap Lines while lines wrap" "$("$DRIVE" menuitems Peeker View | grep -cx '✓ Wrap Lines')" 1
"$DRIVE" menu Peeker View "Wrap Lines" && sleep 0.3
check "and unchecks it once turned off" "$("$DRIVE" menuitems Peeker View | grep -cx 'Wrap Lines')" 1
"$DRIVE" shot Peeker "$OUT/6-sidebar-and-wrap.png" notes.txt
# A window stops shrinking at its minimum size (480 × 320 of content).
osascript -e 'tell application "System Events" to tell process "Peeker" to set size of front window to {200, 150}' >/dev/null 2>&1
sleep 0.5
read -r _ _ ww wh <<< "$("$DRIVE" frame Peeker AXWindow || echo "0 0 0 0")"
check "A window stops at its minimum size" "$([ "$ww" -ge 480 ] && [ "$ww" -le 490 ] && [ "$wh" -ge 320 ] && echo yes)" yes
osascript -e 'tell application "System Events" to tell process "Peeker" to set size of front window to {960, 720}' >/dev/null 2>&1

# A password-protected PDF opens on a lock screen and shows its pages once unlocked.
show "$LOCKED"
check "A locked PDF asks for its password" "$("$DRIVE" tree Peeker 12 | grep -c '“Unlock”')" 1
"$DRIVE" shot Peeker "$OUT/7-locked.png" locked.pdf
read -r fx fy fw fh <<< "$("$DRIVE" frame Peeker AXTextField Password || echo "0 0 0 0")"
"$DRIVE" click Peeker $((fx + fw / 2)) $((fy + fh / 2))
"$DRIVE" type Peeker secret
"$DRIVE" press Peeker Unlock
"$DRIVE" wait Peeker control Unlock --gone
sleep 1
check "Unlocking shows the three pages" "$(thumbnails)" 3
"$DRIVE" shot Peeker "$OUT/8-unlocked.png" locked.pdf

# The same PDF at Actual Size, then fitted to the window again as it opened.
fit=$(looks locked.pdf)
"$DRIVE" keys Peeker cmd+0 && sleep 0.5
actual=$(looks locked.pdf)
"$DRIVE" shot Peeker "$OUT/9-pdf-actual-size.png" locked.pdf
"$DRIVE" keys Peeker cmd+9 && sleep 0.5
check "Actual Size changes a PDF's view" "$([ "$fit" != "$actual" ] && echo yes)" yes
# Not compared with the first look: Zoom to Fit keeps the reading position, which may differ from how it opened.
check "Zoom to Fit changes it back from Actual Size" "$([ "$(looks locked.pdf)" != "$actual" ] && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/9-pdf-zoom-to-fit.png" locked.pdf

# An image: fitted, at Actual Size, then zoomed out below fit; each shows the image differently.
show "$PHOTO"
fit=$(looks photo.png)
"$DRIVE" keys Peeker cmd+0 && sleep 0.5
actual=$(looks photo.png)
"$DRIVE" shot Peeker "$OUT/10-actual-size.png" photo.png
"$DRIVE" keys Peeker cmd+- && sleep 0.3 && "$DRIVE" keys Peeker cmd+- && sleep 0.3 && "$DRIVE" keys Peeker cmd+- && sleep 0.5
smaller=$(looks photo.png)
"$DRIVE" shot Peeker "$OUT/11-zoomed-out.png" photo.png
check "Actual Size changes the view" "$([ "$fit" != "$actual" ] && echo yes)" yes
check "Zooming out changes it again" "$([ "$smaller" != "$actual" ] && [ "$smaller" != "$fit" ] && echo yes)" yes

# An animated GIF plays, a click pauses it, another plays it on.
show "$GIF"
frames() { for _ in 1 2 3 4; do looks blink.gif; sleep 0.25; done | sort -u | wc -l | tr -d ' '; }
check "The GIF plays" "$([ "$(frames)" -gt 1 ] && echo yes)" yes
read -r x y w h <<< "$("$DRIVE" frame Peeker AXScrollArea || echo "0 0 0 0")"
"$DRIVE" click Peeker $((x + w / 2)) $((y + h / 2))
sleep 0.3
check "A click pauses it" "$(frames)" 1
"$DRIVE" shot Peeker "$OUT/12-gif-paused.png" blink.gif
"$DRIVE" click Peeker $((x + w / 2)) $((y + h / 2))
sleep 0.3
check "Another click plays it on" "$([ "$(frames)" -gt 1 ] && echo yes)" yes
# View > Play Animation does the same from the menu, checked while the animation plays.
check "Play Animation is checked while it plays" "$("$DRIVE" menuitems Peeker View | grep -c '^✓ Play Animation$')" 1
"$DRIVE" menu Peeker View "Play Animation"
sleep 0.3
check "Play Animation from the View menu pauses it" "$(frames)" 1
check "and its checkmark goes" "$("$DRIVE" menuitems Peeker View | grep -c '^✓ Play Animation$')" 0
"$DRIVE" menu Peeker View "Play Animation"
sleep 0.3
check "Choosing it again plays it on" "$([ "$(frames)" -gt 1 ] && echo yes)" yes

# A multi-page TIFF: Page Down and Page Up move between its pages, and the thumbnail of the page shown is selected.
show "$TIFF"
check "A multi-page TIFF opens on page 1" "$("$DRIVE" marked Peeker | tail -1)" 1
"$DRIVE" keys Peeker pagedown && sleep 1
check "Page Down shows page 2" "$("$DRIVE" marked Peeker | tail -1)" 2
"$DRIVE" shot Peeker "$OUT/13-tiff-page-2.png" scan.tiff
"$DRIVE" keys Peeker pageup && sleep 1
check "Page Up shows page 1 again" "$("$DRIVE" marked Peeker | tail -1)" 1

# Actual Size on a photo larger than the screen: once the full decode lands, neighbouring screen pixels differ by
# most of the black-to-white range.
show "$STRIPES"
"$DRIVE" keys Peeker cmd+0 && sleep 1
"$DRIVE" shot Peeker "$OUT/14-sharp-actual-size.png" stripes.png
contrast=$("$DRIVE" contrast "$OUT/14-sharp-actual-size.png" || echo 0)
check "Actual Size on a large photo shows its own pixels" "$([ "$contrast" -gt 160 ] && echo yes)" yes

finish
