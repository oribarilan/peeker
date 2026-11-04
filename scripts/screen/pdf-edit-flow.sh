#!/bin/bash
# The PDF editing flow on screen: Space on a form in Finder shows it in the Peek panel, which reads Open in Peeker and
# ignores a click into a field; Open in Peeker opens it in the Editor, which fills a text field and a checkbox, adds a
# text box and a drawn signature placed twice, and saves; the saved file is checked; then a digitally signed form opens
# read-only, with greyed tools and the note under the toolbar. Writes screenshots and results.txt (one ok/FAIL line per
# check) to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Takes over the mouse, keyboard and Finder for about a minute: the screen must be unlocked and left alone. Clicks and
# keys are sent only while the app they're meant for is in front.
# usage: pdf-edit-flow.sh [path/to/Peeker.app]
FLOW=pdf-edit
source "$(dirname "$0")/common.sh" "$@"

FORM="$OUT/form.pdf"
"$PDF" form "$FORM"
tools_shown() { "$DRIVE" tree Peeker 12 | grep -c '“Text Box”'; }
saved() { "$PDF" inspect "$FORM" | grep -c "^$1\$"; }
# The screen frame of an element: x y width height.
frame() { "$DRIVE" frame Peeker "$@" || echo "0 0 0 0"; }

SIGNED="$OUT/signed.pdf"
"$PDF" signed "$SIGNED"

launch
# Opened by hand with nothing to open, Peeker shows Settings; close it before pressing Space.
"$DRIVE" wait Peeker window Settings --timeout 5
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window Settings --gone
record pdf-flow 120

# The Peek panel only views. It never takes focus from Finder, so the click goes through Finder.
"$DRIVE" select "$FORM"
sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
"$DRIVE" keys Finder space
"$DRIVE" wait Peeker control "Open in Peeker"
# The button shows before the PDF has loaded; wait for its Name field before reading where it is.
for _ in $(seq 50); do "$DRIVE" frame Peeker AXTextField >/dev/null 2>&1 && break; sleep 0.1; done
check "The Peek panel's button reads Open in Peeker" "$("$DRIVE" tree Peeker 12 | grep -c '“Open in Peeker”')" 1
# The Name field, found through Accessibility; the page's scale comes from its height (22 pt in the file).
read -r fx fy fw fh <<< "$(frame AXTextField)"
scale=$(echo "$fh / 22" | bc -l)
at() { echo "$(echo "$fx + $1 * $scale" | bc) $(echo "$fy + $fh / 2 + $2 * $scale" | bc)"; }  # points right and down of the field
"$DRIVE" click Finder $(at 20 0)
sleep 0.5
"$DRIVE" focus Peeker > "$OUT/focus-peek-panel.txt"
# A field being typed into reports itself as AXTextArea (PDFKit's editor), so look for either.
check "A click into a field in the Peek panel gives it no cursor" "$(grep -cE 'AXText(Area|Field)' "$OUT/focus-peek-panel.txt")" 0
"$DRIVE" shot Peeker "$OUT/1-peek-panel.png"

"$DRIVE" press Peeker "Open in Peeker"
"$DRIVE" wait Peeker window form.pdf --timeout 10
# macOS doesn't always bring an app opened from a terminal to the front, and its View and Tools menus fill in only then.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
"$DRIVE" wait Peeker control "Text Box"
check "The Editor shows the tools at once" "$([ "$(tools_shown)" -gt 0 ] && echo yes)" yes
"$DRIVE" tree Peeker 30 > "$OUT/tree-editor.txt"
read -r fx fy fw fh <<< "$(frame AXTextField)"
scale=$(echo "$fh / 22" | bc -l)
"$DRIVE" shot Peeker "$OUT/2-editor.png"
# Where the keyboard is before and after the click, for when the typing doesn't arrive.
"$DRIVE" focus Peeker > "$OUT/focus-before-name.txt"
"$DRIVE" click Peeker $(at 20 0)
"$DRIVE" focus Peeker > "$OUT/focus-after-name.txt"
"$DRIVE" type Peeker "Jane Doe"
sleep 0.3
"$DRIVE" click Peeker $(at 8 52)  # the checkbox, which also ends typing in the field
sleep 0.5

# The toolbar names Text Box's key in its tooltip, and the first Text Box shows its tip once.
check "Text Box's tooltip names its key" "$(osascript -e 'tell application "System Events" to tell process "Peeker" to get help of (first button of toolbar 1 of window 1 whose description is "Text Box")' 2>/dev/null)" "Text Box (T)"
"$DRIVE" menu Peeker Tools "Text Box (T)"
sleep 0.6
check "The first Text Box shows its tip" "$("$DRIVE" tree Peeker 12 | grep -c 'Click where the text goes.')" 1
"$DRIVE" shot Peeker "$OUT/2b-text-box-tip.png"
"$DRIVE" click Peeker $(at 0 200)  # the Date: line; the click also closes the tip
sleep 0.5
"$DRIVE" type Peeker "31 Oct 2026"
# + stays under the pointer as the box grows, so it can be clicked again and again.
read -r lx ly lw lh <<< "$(frame AXButton "+")"  # its title; drive reads a title before a description
check "The text box shows its size buttons" "$([ "$lw" -gt 0 ] && echo yes)" yes
"$DRIVE" click Peeker $((lx + lw / 2)) $((ly + lh / 2))
sleep 0.3
check "+ makes the text larger" "$(frame AXStaticText "14 pt" | grep -vc '^0 0 0 0$')" 1
check "+ stays put when clicked" "$(frame AXButton "+")" "$lx $ly $lw $lh"
"$DRIVE" keys Peeker escape
sleep 0.5
"$DRIVE" shot Peeker "$OUT/3-filled.png"

"$DRIVE" menu Peeker Tools "Sign (S)"
"$DRIVE" wait Peeker sheet
read -r dx dy dw dh <<< "$(frame AXButton Done)"
"$DRIVE" drag Peeker $((dx - 380)) $((dy - 60)) $((dx - 330)) $((dy - 110)) $((dx - 290)) $((dy - 50)) $((dx - 240)) $((dy - 100)) $((dx - 190)) $((dy - 55))
"$DRIVE" shot Peeker "$OUT/4-signature-pad.png"
"$DRIVE" press Peeker Done
"$DRIVE" wait Peeker sheet --gone
"$DRIVE" click Peeker $(at 120 250)  # the Signature: line
sleep 0.5
"$DRIVE" menu Peeker Tools "Sign (S)"
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

# A digitally signed form opens read-only: the tools greyed out and the reason under the toolbar.
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window form.pdf --gone
launch "$SIGNED"
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
"$DRIVE" wait Peeker control "Text Box"
# AppKit greys toolbar items in a later validation pass, so give it a moment.
for _ in $(seq 30); do [ "$("$DRIVE" enabled Peeker "Text Box")" = false ] && break; sleep 0.1; done
check "A signed PDF greys out Text Box" "$("$DRIVE" enabled Peeker "Text Box")" false
check "A signed PDF says why under the toolbar" "$([ "$("$DRIVE" tree Peeker 20 | grep -c 'digitally signed')" -gt 0 ] && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/6-signed-read-only.png"

finish
