#!/bin/bash
# The PDF page flow on screen: in the Editor, rotate and delete pages chosen in the thumbnails, drag one to the top
# (checking the insertion bar shows mid-drag), save, undo past the save and save again, then make more page edits and
# close the window with Don't Save; last, insert a PDF's pages with File > Insert Pages from File… and split every page
# with Split…. Each save is checked by reading the file's pages back (order, text and rotation). Writes screenshots and
# results.txt (one ok/FAIL line per check) to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Takes over the mouse and keyboard for about half a minute: the screen must be unlocked and left alone. Clicks and
# keys are sent only while Peeker is in front.
# usage: pdf-pages-flow.sh [path/to/Peeker.app]
FLOW=pdf-pages
source "$(dirname "$0")/common.sh" "$@"

FILE="$OUT/pages.pdf"
"$PDF" pages "$FILE" 4
# The file's pages as one line: "Page 1 / Page 2 (90) / Page 3", with a page's rotation when it has one.
saved_pages() {
    "$PDF" inspect "$FILE" | sed -n 's/^page [0-9]*: //p' | sed 's/, rotation 0$//; s/, rotation \(.*\)$/ (\1)/' | paste -sd '/' - | sed 's|/| / |g'
}
# Waits up to 5 s for the file to hold the wanted pages, then checks it.
check_saved() {
    for _ in $(seq 50); do [ "$(saved_pages)" = "$2" ] && break; sleep 0.1; done
    check "$1" "$(saved_pages)" "$2"
}
# The page count in the info panel.
pages_shown() { "$DRIVE" tree Peeker 12 | grep -o $'Pages\t[0-9]*' | cut -f2; }
# The number of thumbnails: each has a text with its page number.
thumbnails() { "$DRIVE" tree Peeker 12 | grep -cE '^ *AXStaticText = [0-9]+$'; }
# The middle of the number under page n's thumbnail: x y.
page_label() {
    read -r x y w h <<< "$("$DRIVE" frame Peeker AXStaticText "$1" || echo "0 0 0 0")"
    echo $((x + w / 2)) $((y + h / 2))
}
# Clicks the thumbnail of page n.
pick_page() {
    "$DRIVE" click Peeker $(page_label "$1")
    sleep 0.3
}
# Drags page n's thumbnail to just above page m's, holding there for [hold] steps of about 16 ms (30 by default). PDFKit
# starts a drag only once the pointer has been held and then moved, so the path holds at the start and moves in small
# steps; a thumbnail is 120 points tall, its number at the bottom. With a fourth argument it also captures the screen
# into that file halfway through the final hold, while the page is over its new place.
drag_page_above() {
    local hold=${3:-30} steps=0
    read -r x from <<< "$(page_label "$1")"
    read -r _ to <<< "$(page_label "$2")"
    from=$((from - 50)) to=$((to - 100))
    local path=()
    for _ in $(seq 30); do path+=("$x" "$from"); done
    for ((y = from; y > to; y -= 4)); do path+=("$x" "$y"); steps=$((steps + 1)); done
    for _ in $(seq "$hold"); do path+=("$x" "$to"); done
    [ -n "${4:-}" ] && ( sleep "$(echo "(30 + $steps + $hold / 2) * 0.017" | bc)"; screencapture -x "$4" ) &
    "$DRIVE" drag Peeker "${path[@]}"
    wait
    sleep 0.5
}
# Whether the screen capture has a strongly colored pixel (the accent-colored insertion bar, not a gray thumbnail or
# sidebar) between screen points y0 and y1, near the middle or the ends of a thumbnail centered on x. The dragged
# page's see-through image covers the bar's middle and washes it out, so its ends count too.
colored_between() {
    local png=$1 x=$2 y0=$3 y1=$4 y dx color max min c i
    read -r width height <<< "$(osascript -e 'tell application "Finder" to get bounds of window of desktop' | awk -F', ' '{print $3, $4}')"
    for dx in 0 -40 40 -35 35; do
        for ((y = y0; y <= y1; y += 1)); do
            color=$("$DRIVE" pixel "$png" "$(echo "scale=5; ($x + $dx) / $width" | bc)" "$(echo "scale=5; $y / $height" | bc)") || continue
            max=0 min=255
            for i in 0 2 4; do c=$((16#${color:i:2})); ((c > max)) && max=$c; ((c < min)) && min=$c; done
            ((max - min > 60)) && return 0
        done
    done
    return 1
}

launch "$FILE"
# macOS doesn't always bring an app opened from a terminal to the front, and its View and Tools menus fill in only then.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
record pdf-pages 90
"$DRIVE" wait Peeker control "Rotate Right"
# Zoom is in the View menu only, which leaves room for every edit tool at this window size.
check "The toolbar has no zoom buttons" "$("$DRIVE" tree Peeker 12 | grep -c 'AXButton “Zoom In”')" 0
check "Four thumbnails" "$(thumbnails)" 4

pick_page 2
"$DRIVE" press Peeker "Rotate Right"
pick_page 4
"$DRIVE" press Peeker "Delete Page"
sleep 0.5
check "Deleting a page removes its thumbnail" "$(thumbnails)" 3
read -r label_x label_y <<< "$(page_label 1)"
drag_page_above 3 1 60 "$OUT/0-mid-drag.png"
check "Mid-drag, a bar shows above page 1" \
    "$(colored_between "$OUT/0-mid-drag.png" "$label_x" $((label_y - 130)) $((label_y - 95)) && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/1-edited.png"
"$DRIVE" menu Peeker File Save
check_saved "The saved file has page 3 first, page 2 turned and page 4 gone" "Page 3 / Page 1 / Page 2 (90)"
check "Preview opens the saved file" "$(preview_shot "$FILE" "$OUT/1b-in-preview.png" && echo yes)" yes
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
for _ in $(seq 30); do [ "$(pages_shown)" = 3 ] && break; sleep 0.1; done
check "The info panel counts the saved pages" "$(pages_shown)" 3

# Undo reaches back past the save: first the drag, then the delete.
"$DRIVE" keys Peeker cmd+z
"$DRIVE" keys Peeker cmd+z
sleep 0.5
check "Undo after saving brings the deleted page back" "$(thumbnails)" 4
"$DRIVE" shot Peeker "$OUT/2-undone.png"
"$DRIVE" menu Peeker File Save
check_saved "The saved file has the deleted page back" "Page 1 / Page 2 (90) / Page 3 / Page 4"

# Unsaved page edits, then closing the window with Don't Save: the file stays as saved.
pick_page 1
"$DRIVE" press Peeker "Rotate Right"
pick_page 4
"$DRIVE" press Peeker "Delete Page"
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker sheet
"$DRIVE" shot Peeker "$OUT/3-close-unsaved.png"
"$DRIVE" press Peeker "Don't Save"
"$DRIVE" wait Peeker window "$(basename "$FILE")" --gone
check "Don't Save leaves the file as saved" "$(saved_pages)" "Page 1 / Page 2 (90) / Page 3 / Page 4"

# The file tools: Insert Pages from File… puts a 2-page PDF's pages after page 2, chosen in the open sheet by path;
# Split… writes every page, unsaved inserts included, next to the file. Closing then discards the insert.
EXTRA="$OUT/extra.pdf"
"$PDF" pages "$EXTRA" 2
open -a "$APP" "$FILE"
"$DRIVE" wait Peeker window "$(basename "$FILE")"
front
pick_page 2
"$DRIVE" menu Peeker File "Insert Pages from File…"
"$DRIVE" wait Peeker sheet
"$DRIVE" keys Peeker shift+cmd+g && sleep 0.5
"$DRIVE" type Peeker "$EXTRA"
"$DRIVE" keys Peeker return && sleep 0.5
"$DRIVE" keys Peeker return
"$DRIVE" wait Peeker sheet --gone
for _ in $(seq 30); do [ "$(thumbnails)" = 6 ] && break; sleep 0.1; done
check "Insert Pages from File… adds the other PDF's pages" "$(thumbnails)" 6
"$DRIVE" shot Peeker "$OUT/4-inserted.png"
"$DRIVE" menu Peeker File "Split…"
"$DRIVE" wait Peeker sheet
"$DRIVE" press Peeker "Every Page"
for _ in $(seq 30); do [ -f "$OUT/pages 6.pdf" ] && break; sleep 0.1; done
check "Split… writes one file per page" "$(ls "$OUT" | grep -cE '^pages [0-9]+\.pdf$')" 6
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker sheet
"$DRIVE" press Peeker "Don't Save"
check "Closing without saving leaves the file without the inserted pages" "$(saved_pages)" "Page 1 / Page 2 (90) / Page 3 / Page 4"

finish
