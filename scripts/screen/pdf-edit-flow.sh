#!/bin/bash
# The PDF editing flow on screen: a form in its read view, Edit mode, filling a text field and a checkbox, a text box,
# a drawn signature placed twice, saving, and what the saved file holds. Writes screenshots and results.txt (one
# ok/FAIL line per check) to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Takes over the mouse and keyboard for about a minute: the screen must be unlocked and left alone. Clicks and keys
# are sent only while Peeker is in front.
# usage: pdf-edit-flow.sh [path/to/Peeker.app]
FLOW=pdf-edit
source "$(dirname "$0")/common.sh" "$@"

FORM="$OUT/form.pdf"
"$PDF" form "$FORM"
tools_shown() { "$DRIVE" tree Peeker 12 | grep -c '“Text Box”'; }
saved() { "$PDF" inspect "$FORM" | grep -c "^$1\$"; }
# The screen frame of an element: x y width height.
frame() { "$DRIVE" frame Peeker "$@" || echo "0 0 0 0"; }

launch "$FORM"
# macOS doesn't always bring an app opened from a terminal to the front, and its Commands menu fills in only then.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
record pdf-flow 90
sleep 1
"$DRIVE" tree Peeker 30 > "$OUT/tree-read-view.txt"

# The Name field, found through Accessibility; the page's scale comes from its height (22 pt in the file).
read -r fx fy fw fh <<< "$(frame AXTextField)"
scale=$(echo "$fh / 22" | bc -l)
at() { echo "$(echo "$fx + $1 * $scale" | bc) $(echo "$fy + $fh / 2 + $2 * $scale" | bc)"; }  # points right and down of the field

"$DRIVE" shot Peeker "$OUT/1-read-view.png"
check "The read view hides the tools" "$(tools_shown)" 0
"$DRIVE" click Peeker $(at 20 0) && "$DRIVE" type Peeker "nope"
sleep 0.5

"$DRIVE" menu Peeker Commands "Edit Mode"
"$DRIVE" wait Peeker control "Text Box"
check "Edit Mode shows the tools" "$([ "$(tools_shown)" -gt 0 ] && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/2-edit-mode.png"
# Where the keyboard is before and after the click, for when the typing doesn't arrive.
"$DRIVE" focus Peeker > "$OUT/focus-before-name.txt"
"$DRIVE" click Peeker $(at 20 0)
"$DRIVE" focus Peeker > "$OUT/focus-after-name.txt"
"$DRIVE" type Peeker "Jane Doe"
sleep 0.3
"$DRIVE" click Peeker $(at 8 52)  # the checkbox, which also ends typing in the field
sleep 0.5

"$DRIVE" menu Peeker Commands "Text Box"
"$DRIVE" click Peeker $(at 0 200)  # the Date: line
sleep 0.5
"$DRIVE" type Peeker "31 Oct 2026"
"$DRIVE" keys Peeker escape
sleep 0.5
"$DRIVE" shot Peeker "$OUT/3-filled.png"

"$DRIVE" menu Peeker Commands "Sign"
"$DRIVE" wait Peeker sheet
read -r dx dy dw dh <<< "$(frame AXButton Done)"
"$DRIVE" drag Peeker $((dx - 380)) $((dy - 60)) $((dx - 330)) $((dy - 110)) $((dx - 290)) $((dy - 50)) $((dx - 240)) $((dy - 100)) $((dx - 190)) $((dy - 55))
"$DRIVE" shot Peeker "$OUT/4-signature-pad.png"
"$DRIVE" press Peeker Done
"$DRIVE" wait Peeker sheet --gone
"$DRIVE" click Peeker $(at 120 250)  # the Signature: line
sleep 0.5
"$DRIVE" menu Peeker Commands "Sign"
"$DRIVE" wait Peeker sheet
check "Sign offers the last signature" "$("$DRIVE" tree Peeker 12 | grep -c '“Use Last Signature”')" 1
"$DRIVE" press Peeker "Use Last Signature"
"$DRIVE" wait Peeker sheet --gone
"$DRIVE" click Peeker $(at 320 250)
sleep 0.5
"$DRIVE" shot Peeker "$OUT/5-signed.png"

"$DRIVE" menu Peeker File Save
sleep 2
"$PDF" inspect "$FORM" > "$OUT/saved.txt"
check "The Name field is saved" "$(saved 'field Name = Jane Doe')" 1
check "The checkbox is saved" "$(saved 'field Agree = Yes')" 1
check "The text box is a free-text annotation" "$(saved 'annotation FreeText peeker = 31 Oct 2026')" 1
check "Both signatures are ink annotations" "$(saved 'annotation Ink peeker')" 2

"$DRIVE" menu Peeker Commands "Edit Mode"
"$DRIVE" wait Peeker control "Text Box" --gone
check "Leaving a saved Edit mode asks nothing and hides the tools" "$(tools_shown)" 0
"$DRIVE" shot Peeker "$OUT/6-saved-read-view.png"

finish
