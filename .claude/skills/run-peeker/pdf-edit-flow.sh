#!/bin/bash
# The PDF editing flow on screen: a form in its read view, Edit mode, filling a text field and a checkbox, a text box,
# a drawn signature placed twice, saving, and what the saved file holds. Writes screenshots, a screen recording and
# results.txt (one ok/FAIL line per check) to build/evidence/pdf-<time>/.
#
# Takes over the mouse and keyboard for about a minute: the screen must be unlocked and left alone. Clicks and keys
# are sent only while Peeker is in front.
# usage: pdf-edit-flow.sh [path/to/Peeker.app]
set -u
cd "$(git rev-parse --show-toplevel)"
APP=${1:-build/dd/Build/Products/Release/Peeker.app}
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"
TOOLS=build/run-tools
DRIVE=$TOOLS/drive
PDF=$TOOLS/pdf-tool
mkdir -p "$TOOLS"
swiftc -O .claude/skills/run-peeker/drive.swift -o "$DRIVE" || exit 2
swiftc -O .claude/skills/run-peeker/pdf-tool.swift -o "$PDF" || exit 2
"$DRIVE" locked >/dev/null && { echo "the screen is locked: unlock it and leave it alone while this runs"; exit 2; }

OUT=build/evidence/pdf-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
FORM="$PWD/$OUT/form.pdf"
"$PDF" form "$FORM"
CONFIG="$PWD/$OUT/config.json"
echo '{}' > "$CONFIG"
RESULTS="$OUT/results.txt"
: > "$RESULTS"
check() { if [ "$2" = "$3" ]; then echo "ok    $1: $2" | tee -a "$RESULTS"; else echo "FAIL  $1: got $2, wanted $3" | tee -a "$RESULTS"; fi; }
tools_shown() { "$DRIVE" tree Peeker 12 | grep -c '“Text Box”'; }
saved() { "$PDF" inspect "$FORM" | grep -c "^$1\$"; }
# The screen frame of an element: x y width height.
frame() { "$DRIVE" frame Peeker "$@" || echo "0 0 0 0"; }

# Quits Peeker and stops the recorder however the run ends, so an aborted run leaves neither running. screencapture
# can't stop early and keep its movie (it ignores SIGINT here, and other signals drop the file), so an aborted run
# loses the recording, while a finished one waits for the recording's time limit.
RECORDER=
stop() {
    # Not waiting for the reply: with a Save prompt up, the quit would block until AppleScript's 2-minute timeout.
    osascript -e 'ignoring application responses' -e 'tell application "Peeker" to quit' -e 'end ignoring' >/dev/null 2>&1
    [ -n "$RECORDER" ] && kill -TERM "$RECORDER" 2>/dev/null
    RECORDER=
    # Unsaved edits leave Quit waiting on a Save prompt. This run's files are throwaway, so answer Don't Save, which
    # also drops their crash-recovery copies; kill the app under test only if it still won't quit.
    for _ in 1 2 3; do
        pgrep -f "$APP/Contents/MacOS/Peeker" >/dev/null || return 0
        sleep 1
        "$DRIVE" press Peeker "Don't Save" >/dev/null 2>&1
    done
    pkill -f "$APP/Contents/MacOS/Peeker" 2>/dev/null
}
trap stop EXIT
trap 'exit 130' INT TERM
osascript -e 'tell application "Peeker" to quit' >/dev/null 2>&1
sleep 1
open --env PEEKER_CONFIG="$CONFIG" -a "$APP" "$FORM"
sleep 2.5
# macOS doesn't always bring an app opened from a terminal to the front, and its Commands menu fills in only then.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 1
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
screencapture -v -V 90 -x -k -C "$OUT/pdf-flow.mov" &
RECORDER=$!
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
sleep 1
check "Edit Mode shows the tools" "$([ "$(tools_shown)" -gt 0 ] && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/2-edit-mode.png"
"$DRIVE" click Peeker $(at 20 0) && "$DRIVE" type Peeker "Jane Doe"
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
sleep 1
read -r dx dy dw dh <<< "$(frame AXButton Done)"
"$DRIVE" drag Peeker $((dx - 380)) $((dy - 60)) $((dx - 330)) $((dy - 110)) $((dx - 290)) $((dy - 50)) $((dx - 240)) $((dy - 100)) $((dx - 190)) $((dy - 55))
"$DRIVE" shot Peeker "$OUT/4-signature-pad.png"
"$DRIVE" press Peeker Done
sleep 0.5
"$DRIVE" click Peeker $(at 120 250)  # the Signature: line
sleep 0.5
"$DRIVE" menu Peeker Commands "Sign"
sleep 1
check "Sign offers the last signature" "$("$DRIVE" tree Peeker 12 | grep -c '“Use Last Signature”')" 1
"$DRIVE" press Peeker "Use Last Signature"
sleep 0.5
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
sleep 1
check "Leaving a saved Edit mode asks nothing and hides the tools" "$(tools_shown)" 0
"$DRIVE" shot Peeker "$OUT/6-saved-read-view.png"

osascript -e 'tell application "Peeker" to quit' >/dev/null 2>&1
wait "$RECORDER"
RECORDER=
avconvert --preset Preset1920x1080 --source "$OUT/pdf-flow.mov" --output "$OUT/pdf-flow.mp4" >/dev/null 2>&1 && rm "$OUT/pdf-flow.mov"
echo "evidence in $OUT"
! grep -q FAIL "$RESULTS"
