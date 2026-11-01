#!/bin/bash
# The image editing flow on screen: in Edit mode, crop a 400 × 200 PNG, turn it with R and flip it with H in Rotate &
# Resize, resize it to 100 pixels wide with the proportions kept, and save. Checks the size fields after the turn,
# the saved file's pixel size, resolution and color profile, the info panel's Dimensions, that Preview opens the
# saved file, and that closing after the save asks nothing. Writes screenshots and
# results.txt (one ok/FAIL line per check) to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Every expected size comes from the fields after the crop, so where the crop drag lands doesn't matter.
# Takes over the mouse and keyboard for about 20 seconds: the screen must be unlocked and left alone. Clicks and keys
# are sent only while Peeker is in front.
# usage: image-edit-flow.sh [path/to/Peeker.app]
FLOW=image-edit
source "$(dirname "$0")/common.sh" "$@"

FILE="$OUT/wide.png"
sips -s format png -z 200 400 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns --out "$FILE" >/dev/null
# The resolution and color profile the save must keep.
metadata() { sips -g dpiWidth -g dpiHeight -g profile "$FILE" | tail -n +2 | tr -s ' ' | paste -sd ';' -; }
before=$(metadata)
# A Rotate & Resize field's value.
field() { "$DRIVE" tree Peeker 30 | sed -n "s/^ *AXTextField “$1” = \([0-9]*\)$/\1/p" | head -1; }
saved_size() { sips -g pixelWidth -g pixelHeight "$FILE" | awk '/pixelWidth/ { w = $2 } /pixelHeight/ { h = $2 } END { print w " × " h }'; }
shown_dimensions() { "$DRIVE" tree Peeker 12 | grep -o 'Dimensions	[0-9]* × [0-9]*' | cut -f2; }

launch "$FILE"
# macOS doesn't always bring an app opened from a terminal to the front, and its Commands menu fills in only then.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
record image-edit 60
"$DRIVE" menu Peeker Commands "Edit Mode"
"$DRIVE" wait Peeker control "Crop"

# Crop: a drag across roughly the left half of the image area; the overlay keeps the rectangle inside the image.
read -r x y w h <<< "$("$DRIVE" frame Peeker AXScrollArea || echo "0 0 0 0")"
"$DRIVE" keys Peeker c
sleep 0.3
"$DRIVE" drag Peeker $((x + w / 10)) $((y + h / 10)) $((x + w / 4)) $((y + h / 2)) $((x + w / 2)) $((y + h * 9 / 10))
"$DRIVE" shot Peeker "$OUT/1-crop.png"
"$DRIVE" keys Peeker return
sleep 0.5

# Rotate & Resize: the fields show the cropped size, then the turned size after R.
"$DRIVE" keys Peeker cmd+r
"$DRIVE" wait Peeker control "Apply"
width=$(field Width) height=$(field Height)
check "The crop made the image smaller" "$([ "${width:-0}" -gt 0 ] && [ "$width" -lt 400 ] && echo yes)" yes
"$DRIVE" type Peeker r  # the letter, so the input source doesn't matter
sleep 0.3
check "R turns the size in the fields" "$(field Width) × $(field Height)" "$height × $width"
"$DRIVE" type Peeker h  # flips it; the size stays
sleep 0.3
check "H flips without changing the size" "$(field Width) × $(field Height)" "$height × $width"
"$DRIVE" shot Peeker "$OUT/2-turned-and-flipped.png"

# Width 100 with Keep proportions on: the height follows the turned image's shape.
read -r fx fy fw fh <<< "$("$DRIVE" frame Peeker AXTextField Width || echo "0 0 0 0")"
"$DRIVE" click Peeker $((fx + fw / 2)) $((fy + fh / 2))
"$DRIVE" keys Peeker cmd+a
"$DRIVE" type Peeker 100
sleep 0.3
expected="100 × $(( (200 * width / height + 1) / 2 ))"  # 100 · width / height, rounded
check "Keep proportions fills in the height" "$(field Width) × $(field Height)" "$expected"
"$DRIVE" press Peeker Apply
sleep 0.3
"$DRIVE" keys Peeker escape
"$DRIVE" wait Peeker control "Apply" --gone
"$DRIVE" keys Peeker cmd+s
for _ in $(seq 50); do [ "$(saved_size)" = "$expected" ] && break; sleep 0.1; done
check "The saved file has the new size" "$(saved_size)" "$expected"
for _ in $(seq 30); do [ "$(shown_dimensions)" = "$expected" ] && break; sleep 0.1; done
check "The info panel shows the saved size" "$(shown_dimensions)" "$expected"
"$DRIVE" shot Peeker "$OUT/3-saved.png"
check "The save keeps the resolution and color profile" "$(metadata)" "$before"
check "Preview opens the saved image" "$(preview_shot "$FILE" "$OUT/4-in-preview.png" && echo yes)" yes
front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.5; }
front

"$DRIVE" keys Peeker cmd+w
check "Closing after the save asks nothing" "$("$DRIVE" wait Peeker window wide.png --gone --timeout 3 2>/dev/null && echo closed)" closed

finish
