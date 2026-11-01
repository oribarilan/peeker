#!/bin/bash
# The viewer flow on screen: find in a PDF, the print panel for each format, unlocking a password-protected PDF,
# Actual Size and zooming out on an image, and an animated GIF playing, pausing on a click and playing on. Writes
# screenshots and results.txt (one ok/FAIL line per check) to its evidence folder, plus a screen recording with
# SCREEN_RECORD=1.
#
# Takes over the mouse and keyboard for about 40 seconds: the screen must be unlocked and left alone. Clicks and keys
# are sent only while Peeker is in front.
# usage: viewer-flow.sh [path/to/Peeker.app]
FLOW=viewer
source "$(dirname "$0")/common.sh" "$@"

PAGES="$OUT/pages.pdf" LOCKED="$OUT/locked.pdf" NOTES="$OUT/notes.txt" MD="$OUT/notes.md" PHOTO="$OUT/photo.png" GIF="$OUT/blink.gif"
"$PDF" pages "$PAGES" 4
"$PDF" locked "$LOCKED" secret 3
printf 'Plain text to print.\n' > "$NOTES"
printf '# Notes\n\nMarkdown to print.\n' > "$MD"
sips -s format png -z 900 1600 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns --out "$PHOTO" >/dev/null
# Two 64-pixel frames, red then blue, 0.4 s each, looping.
base64 -d <<< 'R0lGODdhQABAAKIAAAAAAAAA//8AAP///wAAAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQFKAAEACwAAAAAQABAAAADRyi63P4wykmrvTjrzbv/YCiOZGmeaKqubOu+cCzPdG3feK7vfO//wKBwSCwaj8ikcslsOp/QqHRKrVqv2Kx2y+16v+CwWJAAACH5BAUoAAQALAAAAABAAEAAAANHGLrc/jDKSau9OOvNu/9gKI5kaZ5oqq5s675wLM90bd94ru987//AoHBILBqPyKRyyWw6n9CodEqtWq/YrHbL7Xq/4LA4kAAAOw==' > "$GIF"

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

# A password-protected PDF opens on a lock screen and shows its pages once unlocked.
show "$LOCKED"
check "A locked PDF asks for its password" "$("$DRIVE" tree Peeker 12 | grep -c '“Unlock”')" 1
"$DRIVE" shot Peeker "$OUT/6-locked.png" locked.pdf
read -r fx fy fw fh <<< "$("$DRIVE" frame Peeker AXTextField Password || echo "0 0 0 0")"
"$DRIVE" click Peeker $((fx + fw / 2)) $((fy + fh / 2))
"$DRIVE" type Peeker secret
"$DRIVE" press Peeker Unlock
"$DRIVE" wait Peeker control Unlock --gone
sleep 1
check "Unlocking shows the three pages" "$(thumbnails)" 3
"$DRIVE" shot Peeker "$OUT/7-unlocked.png" locked.pdf

# An image: fitted, at Actual Size, then zoomed out below fit; each shows the image differently.
show "$PHOTO"
fit=$(looks photo.png)
"$DRIVE" keys Peeker cmd+0 && sleep 0.5
actual=$(looks photo.png)
"$DRIVE" shot Peeker "$OUT/8-actual-size.png" photo.png
"$DRIVE" keys Peeker cmd+- && sleep 0.3 && "$DRIVE" keys Peeker cmd+- && sleep 0.3 && "$DRIVE" keys Peeker cmd+- && sleep 0.5
smaller=$(looks photo.png)
"$DRIVE" shot Peeker "$OUT/9-zoomed-out.png" photo.png
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
"$DRIVE" shot Peeker "$OUT/10-gif-paused.png" blink.gif
"$DRIVE" click Peeker $((x + w / 2)) $((y + h / 2))
sleep 0.3
check "Another click plays it on" "$([ "$(frames)" -gt 1 ] && echo yes)" yes

finish
