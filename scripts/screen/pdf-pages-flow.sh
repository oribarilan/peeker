#!/bin/bash
# The PDF page flow on screen: in Edit mode, rotate and delete pages chosen in the thumbnails, drag one to the top,
# save, undo past the save and save again, then leave Edit mode with Don't Save. Each save is checked by reading the
# file's pages back (order, text and rotation). Writes screenshots and results.txt (one ok/FAIL line per check)
# to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
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
# Drags page n's thumbnail to just above page m's. PDFKit starts a drag only once the pointer has been held and then
# moved, so the path holds at the start and moves in small steps; a thumbnail is 120 points tall, its number at the
# bottom.
drag_page_above() {
    read -r x from <<< "$(page_label "$1")"
    read -r _ to <<< "$(page_label "$2")"
    from=$((from - 50)) to=$((to - 100))
    local path=()
    for _ in $(seq 30); do path+=("$x" "$from"); done
    for ((y = from; y > to; y -= 4)); do path+=("$x" "$y"); done
    for _ in $(seq 30); do path+=("$x" "$to"); done
    "$DRIVE" drag Peeker "${path[@]}"
    sleep 0.5
}

launch "$FILE"
# macOS doesn't always bring an app opened from a terminal to the front, and its Commands menu fills in only then.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
record pdf-pages 90
"$DRIVE" menu Peeker Commands "Edit Mode"
"$DRIVE" wait Peeker control "Rotate Right"
check "Four thumbnails" "$(thumbnails)" 4

pick_page 2
"$DRIVE" press Peeker "Rotate Right"
pick_page 4
"$DRIVE" press Peeker "Delete Page"
sleep 0.5
check "Deleting a page removes its thumbnail" "$(thumbnails)" 3
drag_page_above 3 1
"$DRIVE" shot Peeker "$OUT/1-edited.png"
"$DRIVE" menu Peeker File Save
check_saved "The saved file has page 3 first, page 2 turned and page 4 gone" "Page 3 / Page 1 / Page 2 (90)"

# Undo reaches back past the save: first the drag, then the delete.
"$DRIVE" keys Peeker cmd+z
"$DRIVE" keys Peeker cmd+z
sleep 0.5
check "Undo after saving brings the deleted page back" "$(thumbnails)" 4
"$DRIVE" shot Peeker "$OUT/2-undone.png"
"$DRIVE" menu Peeker File Save
check_saved "The saved file has the deleted page back" "Page 1 / Page 2 (90) / Page 3 / Page 4"

# Unsaved page edits, then leaving Edit mode with Don't Save: the view goes back to the file.
pick_page 1
"$DRIVE" press Peeker "Rotate Right"
pick_page 4
"$DRIVE" press Peeker "Delete Page"
"$DRIVE" menu Peeker Commands "Edit Mode"
"$DRIVE" wait Peeker sheet
"$DRIVE" shot Peeker "$OUT/3-leave-edit-mode.png"
"$DRIVE" press Peeker "Don't Save"
"$DRIVE" wait Peeker control "Rotate Right" --gone
check "Don't Save shows the file's pages again" "$(thumbnails)" 4
check "Don't Save leaves the file as saved" "$(saved_pages)" "Page 1 / Page 2 (90) / Page 3 / Page 4"
"$DRIVE" shot Peeker "$OUT/4-reverted.png"

finish
