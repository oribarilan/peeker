#!/bin/bash
# The Markdown editing flow on screen: Space on a Markdown file in Finder shows it rendered in the Peek panel (no #
# or ** in its text, and the picture beside it shown as a picture, not its alt text); in the Editor, typing at the end of a line and Cmd+S write exactly that to the file; a click on
# a task box ticks it as an unsaved edit (closing asks to save; the file keeps [ ] until Cmd+S); and a click on a
# heading in the sidebar outline puts the cursor at the start of its line and marks the heading, the mark follows the
# cursor into another section, and the sidebar button sits over the sidebar. Writes screenshots and results.txt (one
# ok/FAIL line per check) to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Text is found on screen through Accessibility (drive textframe), so the clicks follow the text wherever it's laid out.
# Takes over the mouse, keyboard and Finder for about 20 seconds: the screen must be unlocked and left alone. Clicks
# and keys are sent only while the app they're meant for is in front.
# usage: markdown-edit-flow.sh [path/to/Peeker.app]
FLOW=markdown-edit
source "$(dirname "$0")/common.sh" "$@"

FILE="$OUT/notes.md"
# Short lines, so each source line is one laid-out line and drive selection's line number is the source line's.
printf '# Notes\n\nSome **bold** words.\n\n![logo](logo.png)\n\n- [ ] buy milk\n\n## Later\n\nmore text\n' > "$FILE"
# A picture beside the file, which the Peek panel shows in place of its alt text.
sips -s format png -z 64 64 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns --out "$OUT/logo.png" >/dev/null
front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.5; }
# The screen frame of some text in the window: x y width height.
# A failed lookup gives 0 0 0 0, and the click it was for is skipped rather than sent to the screen's corner.
textframe() { "$DRIVE" textframe Peeker "$1" || echo "0 0 0 0"; }

launch
# Opened by hand with nothing to open, Peeker shows Settings; close it before pressing Space.
"$DRIVE" wait Peeker window Settings --timeout 5
front
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window Settings --gone
record markdown-edit 60

# The Peek panel still shows Markdown rendered: the words without their markers.
"$DRIVE" select "$FILE"
sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
"$DRIVE" keys Finder space
check "Space on notes.md opens the Peek panel" "$("$DRIVE" wait Peeker window notes.md 2>/dev/null && echo Peeker)" Peeker
for _ in $(seq 30); do "$DRIVE" value Peeker 2>/dev/null | grep -q bold && break; sleep 0.1; done
rendered=$("$DRIVE" value Peeker 2>/dev/null)
echo "$rendered" > "$OUT/peek-panel-text.txt"
check "The Peek panel shows the bold word" "$(grep -c bold <<< "$rendered")" 1
check "The Peek panel shows no ** markers" "$(grep -cF '**' <<< "$rendered")" 0
check "The Peek panel shows no # markers" "$(grep -cF '# ' <<< "$rendered")" 0
check "The Peek panel shows the picture, not [logo]" "$(grep -cF '[logo]' <<< "$rendered")" 0
sleep 0.5  # the picture decodes after the text shows
"$DRIVE" shot Peeker "$OUT/1-peek-panel.png"
"$DRIVE" keys Finder escape  # the panel never takes focus, so Finder stays in front
"$DRIVE" wait Peeker window notes.md --gone

# Type at the end of a line and save: the file holds exactly the typed text.
open -a "$APP" "$FILE"
"$DRIVE" wait Peeker window notes.md --timeout 10
front
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
check "The Editor shows the source" "$("$DRIVE" value Peeker | grep -cx 'Some \*\*bold\*\* words.')" 1
"$DRIVE" shot Peeker "$OUT/2-editor.png" notes.md
read -r x y w h <<< "$(textframe "more text")"
[ "$w" -gt 0 ] && "$DRIVE" click Peeker $((x + w + 15)) $((y + h / 2))  # right of the line's end, which puts the cursor there
"$DRIVE" type Peeker " added"
"$DRIVE" keys Peeker cmd+s
printf '# Notes\n\nSome **bold** words.\n\n![logo](logo.png)\n\n- [ ] buy milk\n\n## Later\n\nmore text added\n' > "$OUT/expected-typed.md"
for _ in $(seq 50); do cmp -s "$FILE" "$OUT/expected-typed.md" && break; sleep 0.1; done
check "Cmd+S writes the typed text" "$(cmp -s "$FILE" "$OUT/expected-typed.md" && echo same || echo different)" same

# A click on the task box ticks it as an edit: the window asks before closing, and only Cmd+S writes it.
read -r x y w h <<< "$(textframe "[ ]")"
[ "$w" -gt 0 ] && "$DRIVE" click Peeker $((x + w / 2)) $((y + h / 2))
sleep 0.3
check "Clicking the box ticks the task" "$("$DRIVE" value Peeker | grep -cx -- '- \[x\] buy milk')" 1
check "The file keeps the unticked task" "$(grep -cx -- '- \[ \] buy milk' "$FILE")" 1
"$DRIVE" shot Peeker "$OUT/3-task-ticked.png" notes.md
"$DRIVE" keys Peeker cmd+w
check "The ticked task is an unsaved edit: closing asks to save" "$("$DRIVE" wait Peeker sheet --timeout 3 2>/dev/null && echo asked)" asked
"$DRIVE" press Peeker Cancel
"$DRIVE" wait Peeker sheet --gone
"$DRIVE" keys Peeker cmd+s
sed 's/- \[ \] buy milk/- [x] buy milk/' "$OUT/expected-typed.md" > "$OUT/expected-ticked.md"
for _ in $(seq 50); do cmp -s "$FILE" "$OUT/expected-ticked.md" && break; sleep 0.1; done
check "Cmd+S writes the ticked task" "$(cmp -s "$FILE" "$OUT/expected-ticked.md" && echo same || echo different)" same

# A click on a heading in the outline puts the cursor at the start of its line. The outline indents a level-2
# title with spaces, which drive frame drops.
read -r x y w h <<< "$("$DRIVE" frame Peeker AXStaticText Later || echo "0 0 0 0")"
[ "$w" -gt 0 ] && "$DRIVE" click Peeker $((x + w / 2)) $((y + h / 2))
sleep 0.5
content=$(cat "$OUT/expected-ticked.md")
before=${content%%"## Later"*}  # the text before the heading; all ASCII, so its length is the UTF-16 offset
line=$(grep -n -m1 '^## Later$' "$OUT/expected-ticked.md" | cut -d: -f1)
check "The outline puts the cursor at the start of ## Later" "$("$DRIVE" selection Peeker)" "${#before} 0 line $((line - 1))"
"$DRIVE" shot Peeker "$OUT/4-outline-jump.png" notes.md
check "The outline marks Later, the cursor's section" "$("$DRIVE" marked Peeker)" Later
# A click in the text under # Notes moves the mark there.
read -r x y w h <<< "$(textframe "buy milk")"
[ "$w" -gt 0 ] && "$DRIVE" click Peeker $((x + w / 2)) $((y + h / 2))
sleep 0.3
check "Moving the cursor into the Notes section marks Notes" "$("$DRIVE" marked Peeker)" Notes
# The sidebar button rides over the sidebar, as in Finder, rather than beside Open With.
read -r bx by bw bh <<< "$("$DRIVE" frame Peeker AXButton Sidebar || echo "0 0 0 0")"
read -r ox oy ow oh <<< "$("$DRIVE" frame Peeker AXTable || echo "0 0 0 0")"
check "The sidebar button sits over the sidebar" \
    "$([ "$bw" -gt 0 ] && [ "$ow" -gt 0 ] && [ $((bx + bw)) -le $((ox + ow)) ] && echo yes || echo "button ends at $((bx + bw)), outline at $((ox + ow))")" yes

"$DRIVE" keys Peeker cmd+w
closed=$("$DRIVE" wait Peeker window notes.md --gone --timeout 3 2>/dev/null && echo closed)
check "Closing after the save asks nothing" "$closed" closed
[ -n "$closed" ] || "$DRIVE" press Peeker "Don't Save"

finish
