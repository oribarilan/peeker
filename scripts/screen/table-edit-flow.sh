#!/bin/bash
# The table editing flow on screen: Space on a CSV file in Finder shows it as a table in the Peek panel; in the Editor,
# a double-click on a cell, typing and Return change it, Return leaves no cell being edited, and Cmd+S writes exactly
# that change to the file; typing over the current cell replaces it, Shift-Up selects two cells and Delete clears them;
# a click on a column title selects it without sorting, and a click on the title's arrow sorts the table without
# counting as an edit (closing asks nothing); View > Header Row turns the header
# off and on again, its checkmark following; and Tools > Add Row Below is an unsaved edit (closing asks to save, and
# Don't Save leaves the file as saved). Writes screenshots and results.txt (one ok/FAIL line per check) to its evidence
# folder, plus a screen recording with SCREEN_RECORD=1.
#
# Cells are found through Accessibility as static text (drive frame AXStaticText), and column titles as the header's
# buttons (drive frame AXButton), so the clicks follow the layout. Takes over the mouse, keyboard and Finder for about
# 25 seconds: the screen must be unlocked and left alone. Clicks and keys are sent only while the app they're meant for
# is in front.
# usage: table-edit-flow.sh [path/to/Peeker.app]
FLOW=table-edit
source "$(dirname "$0")/common.sh" "$@"

FILE="$OUT/prices.csv"
printf 'name,price\nTea,3.50\nCake,4\nBread,2\n' > "$FILE"
printf 'name,price\nTea,3.50\nCake,9\nBread,2\n' > "$OUT/expected-edited.csv"
printf 'name,price\nTea,\nCake,\nBread,7\n' > "$OUT/expected-cleared.csv"
front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.5; }
# The screen frame of the first element with that role and label or value: x y width height. A failed lookup gives
# 0 0 0 0, and the click it was for is skipped rather than sent to the screen's corner.
frame() { "$DRIVE" frame Peeker "$1" "$2" || echo "0 0 0 0"; }
# The name in the table's top row. Rows and columns both list their cells top to bottom, so the first name in the tree
# is the top row's whichever Accessibility lists first.
top_row() { "$DRIVE" tree Peeker 30 | grep -oE 'AXStaticText.* = (Tea|Cake|Bread)$' | head -1 | sed 's/.* = //'; }

launch
# Opened by hand with nothing to open, Peeker shows Settings; close it before pressing Space.
"$DRIVE" wait Peeker window Settings --timeout 5
front
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window Settings --gone
record table-edit 60

# The Peek panel shows the file as a table.
"$DRIVE" select "$FILE"
sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
"$DRIVE" keys Finder space
check "Space on prices.csv opens the Peek panel" "$("$DRIVE" wait Peeker window prices.csv 2>/dev/null && echo Peeker)" Peeker
for _ in $(seq 30); do "$DRIVE" tree Peeker 30 2>/dev/null | grep -q 'AXStaticText.* = Cake$' && break; sleep 0.1; done
"$DRIVE" tree Peeker 30 > "$OUT/peek-panel-tree.txt" 2>&1
check "The Peek panel shows a table" "$(grep -q '^ *AXTable' "$OUT/peek-panel-tree.txt" && echo yes)" yes
check "The Peek panel shows the cell Cake" "$(grep -q 'AXStaticText.* = Cake$' "$OUT/peek-panel-tree.txt" && echo yes)" yes
# Fitted columns and the right-aligned price column show only in the picture; unit tests check both.
"$DRIVE" shot Peeker "$OUT/1-peek-panel.png"
"$DRIVE" keys Finder escape  # the panel never takes focus, so Finder stays in front
"$DRIVE" wait Peeker window prices.csv --gone

# Edit a cell and save: the file changes in that field only.
open -a "$APP" "$FILE"
"$DRIVE" wait Peeker window prices.csv --timeout 10
front
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
# The header's titles are buttons named after the columns.
check "The Editor shows name and price as column titles" "$("$DRIVE" tree Peeker 30 | grep -oE 'AXButton “(name|price)”' | sort -u | paste -sd ' ' -)" "AXButton “name” AXButton “price”"
check "The Editor shows the rows in file order" "$(top_row)" Tea
"$DRIVE" shot Peeker "$OUT/2-editor.png" prices.csv
# Cake's price cell: its row from the cell Cake, its column from Tea's 3.50. Not the text "4" itself, which the info
# panel's Rows count also shows.
read -r _ cy _ ch <<< "$(frame AXStaticText Cake)"
read -r px _ pw _ <<< "$(frame AXStaticText 3.50)"
[ "$ch" -gt 0 ] && [ "$pw" -gt 0 ] && "$DRIVE" click Peeker $((px + pw / 2)) $((cy + ch / 2)) 2
sleep 0.3
"$DRIVE" keys Peeker cmd+a  # editing starts with the field's text selected; this makes sure
"$DRIVE" type Peeker 9
"$DRIVE" keys Peeker return  # commits, and makes the cell below current without editing it
sleep 0.3
check "Return leaves no cell being edited" "$("$DRIVE" focus Peeker | grep -cE 'AXText(Area|Field)')" 0
"$DRIVE" shot Peeker "$OUT/3-edited.png" prices.csv
"$DRIVE" keys Peeker cmd+s
for _ in $(seq 50); do cmp -s "$FILE" "$OUT/expected-edited.csv" && break; sleep 0.1; done
check "Cmd+S writes the edited cell and nothing else" "$(cmp -s "$FILE" "$OUT/expected-edited.csv" && echo same || echo different)" same

# Bread's price is current now: typing replaces it. Then Up, Shift-Up selects Cake's and Tea's prices, and Delete
# clears both.
"$DRIVE" type Peeker 7
"$DRIVE" keys Peeker return
"$DRIVE" keys Peeker up
"$DRIVE" keys Peeker shift+up
sleep 0.3
"$DRIVE" shot Peeker "$OUT/3b-two-selected.png" prices.csv
"$DRIVE" keys Peeker delete
"$DRIVE" keys Peeker cmd+s
for _ in $(seq 50); do cmp -s "$FILE" "$OUT/expected-cleared.csv" && break; sleep 0.1; done
check "Typing replaces a cell and Delete clears the selection" "$(cmp -s "$FILE" "$OUT/expected-cleared.csv" && echo same || echo different)" same

# A click on a title away from its arrow selects the column and doesn't sort.
read -r x y w h <<< "$(frame AXButton price)"
[ "$w" -gt 0 ] && "$DRIVE" click Peeker $((x + 12)) $((y + h / 2))
sleep 0.3
check "Clicking the price title doesn't sort" "$(top_row)" Tea
"$DRIVE" shot Peeker "$OUT/3c-column-selected.png" prices.csv
# The arrow shows on the title under the pointer, at its right end; a click on it sorts, which isn't an edit:
# closing asks nothing.
[ "$w" -gt 0 ] && "$DRIVE" move Peeker $((x + w - 10)) $((y + h / 2))
sleep 0.4
"$DRIVE" shot Peeker "$OUT/3d-sort-arrow.png" prices.csv
[ "$w" -gt 0 ] && "$DRIVE" click Peeker $((x + w - 10)) $((y + h / 2))
sleep 0.3
# Bread's 7 is the only number left, and numbers sort before text.
check "Clicking price's arrow sorts Bread to the top" "$(top_row)" Bread
"$DRIVE" shot Peeker "$OUT/4-sorted.png" prices.csv
"$DRIVE" keys Peeker cmd+w
closed=$("$DRIVE" wait Peeker window prices.csv --gone --timeout 3 2>/dev/null && echo closed)
check "Closing after a sort asks nothing" "$closed" closed
[ -n "$closed" ] || { "$DRIVE" press Peeker "Don't Save"; "$DRIVE" wait Peeker window prices.csv --gone; }
check "The sort leaves the file as saved" "$(cmp -s "$FILE" "$OUT/expected-cleared.csv" && echo same || echo different)" same

# View > Header Row turns the header off and on, its checkmark following. The choice is kept per file in the
# preferences, so it's put back on before the next step.
open -a "$APP" "$FILE"
"$DRIVE" wait Peeker window prices.csv --timeout 10
front
view_items=$("$DRIVE" menuitems Peeker View)
check "View has Header Row checked for a guessed header" "$(grep -cx '✓ Header Row' <<< "$view_items")" 1
check "View has Commas checked for a comma file" "$(grep -cx '✓ Commas' <<< "$view_items")" 1
"$DRIVE" menu Peeker View "Header Row"
sleep 0.3
view_items=$("$DRIVE" menuitems Peeker View)
check "Header Row is unchecked after choosing it" "$(grep -cx '✓ Header Row' <<< "$view_items"):$(grep -cx 'Header Row' <<< "$view_items")" 0:1
check "Without the header, name shows as a cell" "$("$DRIVE" tree Peeker 30 | grep -q 'AXStaticText.* = name$' && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/5-header-off.png" prices.csv
"$DRIVE" menu Peeker View "Header Row"
sleep 0.3
check "Choosing Header Row again checks it" "$("$DRIVE" menuitems Peeker View | grep -cx '✓ Header Row')" 1

# Find: Cmd+F shows the bar with the cursor in it, "ea" matches Tea and Bread, and Escape closes it.
"$DRIVE" keys Peeker cmd+f
sleep 0.3
"$DRIVE" type Peeker ea
sleep 0.8
check "Cmd+F and typing find two cells" "$("$DRIVE" tree Peeker 12 | grep -oE 'AXStaticText = [0-9]+ of [0-9]+' | head -1)" "AXStaticText = 1 of 2"
"$DRIVE" shot Peeker "$OUT/5b-find.png" prices.csv
"$DRIVE" keys Peeker escape
sleep 0.3
check "Escape closes the find bar" "$("$DRIVE" tree Peeker 12 | grep -c 'Find in table')" 0

# Print: the print panel has a Table section with Row Numbers and a checkbox per column.
"$DRIVE" keys Peeker cmd+p
"$DRIVE" wait Peeker sheet --timeout 8
sleep 1
print_tree=$("$DRIVE" tree Peeker 14)
check "The print panel has a Table section" "$(grep -cE 'AXCheckBox “(Row Numbers|name|price)”' <<< "$print_tree")" 3
"$DRIVE" shot Peeker "$OUT/5c-print.png" prices.csv
"$DRIVE" press Peeker Cancel
"$DRIVE" wait Peeker sheet --gone

# Show in Finder in the toolbar brings Finder forward with the file selected.
"$DRIVE" press Peeker "Show in Finder"
sleep 1.5
check "Show in Finder selects the file in Finder" "$(osascript -e 'tell application "Finder" to get name of item 1 of (get selection)' 2>/dev/null)" prices.csv
front

# Tools > Add Row Below is an edit: closing asks to save, and Don't Save leaves the file as it was.
"$DRIVE" menu Peeker Tools "Add Row Below"
sleep 0.3
"$DRIVE" shot Peeker "$OUT/6-row-added.png" prices.csv
"$DRIVE" keys Peeker cmd+w
check "An added row is an unsaved edit: closing asks to save" "$("$DRIVE" wait Peeker sheet --timeout 3 2>/dev/null && echo asked)" asked
"$DRIVE" press Peeker "Don't Save"
"$DRIVE" wait Peeker window prices.csv --gone
check "Don't Save leaves the file as saved" "$(cmp -s "$FILE" "$OUT/expected-cleared.csv" && echo same || echo different)" same

finish
