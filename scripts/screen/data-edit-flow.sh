#!/bin/bash
# The JSON editing flow on screen: Space on a JSON file in Finder shows it as a tree in the Peek panel; in the Editor,
# a double-click on a value, typing and Return change it, and Cmd+S writes exactly that change to the file; View >
# Show Text shows the saved text, its checkmark following, and choosing it again goes back to the tree; closing asks
# nothing after the save. Last, a file with a syntax error opens as text with the error's line and message in a bar
# above it, and Show Text can't switch it to the tree. Writes screenshots and results.txt (one ok/FAIL line per check)
# to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Tree cells are found through Accessibility as static text (drive frame AXStaticText), and column titles as the
# header's buttons, so the clicks follow the layout. Takes over the mouse, keyboard and Finder for about 20 seconds:
# the screen must be unlocked and left alone. Clicks and keys are sent only while the app they're meant for is in front.
# usage: data-edit-flow.sh [path/to/Peeker.app]
FLOW=data-edit
source "$(dirname "$0")/common.sh" "$@"

FILE="$OUT/app.json"
printf '{\n  "name": "app",\n  "version": 1,\n  "deps": {\n    "a": 1\n  }\n}\n' > "$FILE"
printf '{\n  "name": "app",\n  "version": 2,\n  "deps": {\n    "a": 1\n  }\n}\n' > "$OUT/expected-edited.json"
BAD="$OUT/bad.json"
printf '{\n  "a": 1\n  "b": 2\n}\n' > "$BAD"
YAML="$OUT/deploy.yaml"
printf 'service: web\nports:\n  - 8080\n  - 8443\n' > "$YAML"
PLIST="$OUT/Info.plist"
printf '{"CFBundleName": "Sample", "CFBundleVersion": "7"}' | plutil -convert binary1 -o "$PLIST" -
front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.5; }
# The screen frame of the first element with that role and label or value: x y width height. A failed lookup gives
# 0 0 0 0, and the click it was for is skipped rather than sent to the screen's corner.
frame() { "$DRIVE" frame Peeker "$1" "$2" || echo "0 0 0 0"; }
# yes when the tree has a static text reading exactly that: a cell, whose value is its text.
has_text() { "$DRIVE" tree Peeker 30 2>/dev/null | grep -q "AXStaticText.* = $1\$" && echo yes; }

launch
# Opened by hand with nothing to open, Peeker shows Settings; close it before pressing Space.
"$DRIVE" wait Peeker window Settings --timeout 5
front
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window Settings --gone
record data-edit 60

# The Peek panel shows the file as a tree.
"$DRIVE" select "$FILE"
sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
"$DRIVE" keys Finder space
check "Space on app.json opens the Peek panel" "$("$DRIVE" wait Peeker window app.json 2>/dev/null && echo Peeker)" Peeker
for _ in $(seq 30); do "$DRIVE" tree Peeker 30 2>/dev/null | grep -q 'AXStaticText.* = version$' && break; sleep 0.1; done
"$DRIVE" tree Peeker 30 > "$OUT/peek-panel-tree.txt" 2>&1
check "The Peek panel shows a tree" "$(grep -q '^ *AXOutline' "$OUT/peek-panel-tree.txt" && echo yes)" yes
check "The Peek panel shows the key version" "$(grep -q 'AXStaticText.* = version$' "$OUT/peek-panel-tree.txt" && echo yes)" yes
check "The Peek panel shows the value app" "$(grep -q 'AXStaticText.* = app$' "$OUT/peek-panel-tree.txt" && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/1-peek-panel.png"
"$DRIVE" keys Finder escape  # the panel never takes focus, so Finder stays in front
"$DRIVE" wait Peeker window app.json --gone

# Edit a value and save: the file changes in that value only.
open -a "$APP" "$FILE"
"$DRIVE" wait Peeker window app.json --timeout 10
front
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
for _ in $(seq 30); do [ -n "$(has_text '1 key')" ] && break; sleep 0.1; done
"$DRIVE" tree Peeker 30 > "$OUT/editor-tree.txt" 2>&1
# The header's titles are buttons named after the columns.
check "The Editor shows Key and Value as column titles" "$(grep -oE 'AXButton “(Key|Value)”' "$OUT/editor-tree.txt" | sort -u | paste -sd ' ' -)" "AXButton “Key” AXButton “Value”"
check "The Editor shows deps as 1 key" "$(grep -q 'AXStaticText.* = 1 key$' "$OUT/editor-tree.txt" && echo yes)" yes
# The sidebar's outline lists the top-level keys too, but not deps' own key a: it shows only when the tree has deps open.
check "The Editor opens the first level: deps' key a shows" "$(grep -q 'AXStaticText.* = a$' "$OUT/editor-tree.txt" && echo yes)" yes
check "The toolbar has Add Item" "$(grep -q '“Add Item”' "$OUT/editor-tree.txt" && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/2-editor.png" app.json
# version's value cell: its column from name's value app, its row halfway between app's row and deps' (1 key), since
# rows are the same height. Not the text "1" itself, which deps' child a also reads, nor the key version, which the
# sidebar's outline also lists.
read -r vx ay vw ah <<< "$(frame AXStaticText app)"
read -r _ ky _ _ <<< "$(frame AXStaticText '1 key')"
[ "$vw" -gt 0 ] && [ "$ky" -gt 0 ] && "$DRIVE" click Peeker $((vx + 10)) $(((ay + ky) / 2 + ah / 2)) 2
sleep 0.3
"$DRIVE" keys Peeker cmd+a  # editing starts with the field's text selected; this makes sure
"$DRIVE" type Peeker 2
"$DRIVE" keys Peeker return  # commits
sleep 0.3
"$DRIVE" shot Peeker "$OUT/3-edited.png" app.json
"$DRIVE" keys Peeker cmd+s
for _ in $(seq 50); do cmp -s "$FILE" "$OUT/expected-edited.json" && break; sleep 0.1; done
check "Cmd+S writes the edited value and nothing else" "$(cmp -s "$FILE" "$OUT/expected-edited.json" && echo same || echo different)" same

# View > Show Text shows the text, with the saved edit, and choosing it again goes back to the tree. The choice is kept
# in the preferences, so it's put back before the window closes.
"$DRIVE" menu Peeker View "Show Text"
sleep 0.3
check "Show Text is checked after choosing it" "$("$DRIVE" menuitems Peeker View | grep -cx '✓ Show Text')" 1
check "The text shows the saved version" "$("$DRIVE" value Peeker | grep -c '"version": 2,')" 1
"$DRIVE" shot Peeker "$OUT/4-text.png" app.json
"$DRIVE" menu Peeker View "Show Text"
sleep 0.3
view_items=$("$DRIVE" menuitems Peeker View)
check "Choosing Show Text again unchecks it" "$(grep -cx '✓ Show Text' <<< "$view_items"):$(grep -cx 'Show Text' <<< "$view_items")" 0:1
check "The tree is back with the edit" "$(has_text 2)" yes
"$DRIVE" keys Peeker cmd+w
closed=$("$DRIVE" wait Peeker window app.json --gone --timeout 3 2>/dev/null && echo closed)
check "Closing after the save asks nothing" "$closed" closed
[ -n "$closed" ] || { "$DRIVE" press Peeker "Don't Save"; "$DRIVE" wait Peeker window app.json --gone; }

# A syntax error: the file opens as text, a bar above it names the line and the problem, and Show Text can't switch
# to the tree. The menu's items don't say whether they're enabled through drive, so this chooses it and checks nothing
# changed; drive may report a failed press of a disabled item, which is ignored.
open -a "$APP" "$BAD"
"$DRIVE" wait Peeker window bad.json --timeout 10
front
for _ in $(seq 30); do "$DRIVE" tree Peeker 30 2>/dev/null | grep -q 'Line 3' && break; sleep 0.1; done
check "The error bar names the line and the problem" "$("$DRIVE" tree Peeker 30 | grep -oE 'Line 3: .*$' | head -1)" "Line 3: Expected a comma or }"
check "The broken file shows as text" "$("$DRIVE" value Peeker | grep -c '"b": 2')" 1
"$DRIVE" shot Peeker "$OUT/5-syntax-error.png" bad.json
"$DRIVE" menu Peeker View "Show Text" 2>/dev/null
sleep 0.3
# The text is what shows, so Show Text reads checked, and choosing it can't switch to a tree there isn't.
check "Show Text stays checked on a broken file" "$("$DRIVE" menuitems Peeker View | grep -cx '✓ Show Text')" 1
check "The error bar stays after choosing Show Text" "$("$DRIVE" tree Peeker 30 | grep -c 'Line 3: ')" 1
"$DRIVE" keys Peeker cmd+w
check "Closing the broken file asks nothing" "$("$DRIVE" wait Peeker window bad.json --gone --timeout 3 2>/dev/null && echo closed)" closed
check "The broken file is left as it was" "$(printf '{\n  "a": 1\n  "b": 2\n}\n' | cmp -s - "$BAD" && echo same || echo different)" same

# YAML in the Peek panel: a tree with its keys and the list's items.
"$DRIVE" select "$YAML"
sleep 2.5
"$DRIVE" keys Finder space
check "Space on deploy.yaml opens the Peek panel" "$("$DRIVE" wait Peeker window deploy.yaml 2>/dev/null && echo Peeker)" Peeker
for _ in $(seq 30); do [ -n "$(has_text 8443)" ] && break; sleep 0.1; done
"$DRIVE" tree Peeker 30 > "$OUT/yaml-tree.txt" 2>&1
check "The YAML tree shows service with web" "$(grep -q 'AXStaticText.* = service$' "$OUT/yaml-tree.txt" && grep -q 'AXStaticText.* = web$' "$OUT/yaml-tree.txt" && echo yes)" yes
check "The YAML tree shows ports' items" "$(grep -q 'AXStaticText.* = 8443$' "$OUT/yaml-tree.txt" && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/6-yaml-panel.png"
"$DRIVE" keys Finder escape
"$DRIVE" wait Peeker window deploy.yaml --gone

# A binary property list: its keys in the tree, and its XML form, read-only, in Show Text.
open -a "$APP" "$PLIST"
"$DRIVE" wait Peeker window Info.plist --timeout 10
front
for _ in $(seq 30); do [ -n "$(has_text CFBundleName)" ] && break; sleep 0.1; done
check "The property list's tree shows CFBundleName with Sample" "$(has_text CFBundleName)$(has_text Sample)" yesyes
"$DRIVE" shot Peeker "$OUT/7-plist-tree.png" Info.plist
"$DRIVE" menu Peeker View "Show Text"
sleep 0.3
check "Show Text shows the XML form" "$("$DRIVE" value Peeker | grep -c '<key>CFBundleName</key>')" 1
"$DRIVE" keys Peeker cmd+down  # the end of the text
"$DRIVE" type Peeker x
sleep 0.3
check "The XML form can't be edited" "$("$DRIVE" value Peeker | grep -c '</plist>x')" 0
"$DRIVE" shot Peeker "$OUT/8-plist-text.png" Info.plist
"$DRIVE" menu Peeker View "Show Text"
"$DRIVE" keys Peeker cmd+w
check "Closing the property list asks nothing" "$("$DRIVE" wait Peeker window Info.plist --gone --timeout 3 2>/dev/null && echo closed)" closed

finish
