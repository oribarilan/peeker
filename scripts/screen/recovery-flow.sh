#!/bin/bash
# The crash recovery flow on screen: type into a text file, fill a PDF form field and turn a page of a locked PDF,
# kill Peeker the way a crash or force quit would, and launch it again with the same recovery folder. Checks that the
# documents come back with their edits (the locked PDF on its lock screen, its record sealed, until it's unlocked),
# that closing each asks to save, and that Don't Save clears their records.
# Writes screenshots and results.txt (one ok/FAIL line per check) to its evidence folder, plus a screen recording
# with SCREEN_RECORD=1.
#
# The clipboard path (a recovered file that's gone) stays a unit test, so a run never touches the clipboard.
# Takes over the mouse and keyboard for about 30 seconds: the screen must be unlocked and left alone. Clicks and keys
# are sent only while Peeker is in front.
# usage: recovery-flow.sh [path/to/Peeker.app]
FLOW=recovery
source "$(dirname "$0")/common.sh" "$@"

NOTES="$OUT/notes.txt"
FORM="$OUT/form.pdf"
LOCKED="$OUT/locked.pdf"
printf 'First line\n' > "$NOTES"
"$PDF" form "$FORM"
"$PDF" locked "$LOCKED" secret 2
records() { find "$OUT/recovery" -name '*.json' 2>/dev/null | wc -l | tr -d ' '; }
tools_shown() { "$DRIVE" tree Peeker 12 | grep -c '“Markup”'; }
shown() { "$DRIVE" tree Peeker 30 | grep -c "$1"; }
front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.5; }

launch "$NOTES"
front
"$DRIVE" type Peeker "" || { echo "Peeker didn't come to the front; nothing was sent"; exit 2; }
record recovery 60
"$DRIVE" type Peeker "Typed before the crash"

open -a "$APP" "$FORM"
"$DRIVE" wait Peeker window form.pdf
front
"$DRIVE" wait Peeker control "Markup"
read -r fx fy fw fh <<< "$("$DRIVE" frame Peeker AXTextField || echo "0 0 0 0")"
"$DRIVE" click Peeker $((fx + 20)) $((fy + fh / 2))
"$DRIVE" type Peeker "Jane Doe"
"$DRIVE" keys Peeker tab  # ends typing in the field, which makes it an edit
"$DRIVE" shot Peeker "$OUT/1-edited.png" form.pdf

unlock() {
    read -r px py pw ph <<< "$("$DRIVE" frame Peeker AXTextField Password || echo "0 0 0 0")"
    "$DRIVE" click Peeker $((px + pw / 2)) $((py + ph / 2))
    "$DRIVE" type Peeker secret
    "$DRIVE" press Peeker Unlock
    "$DRIVE" wait Peeker control Unlock --gone
}
open -a "$APP" "$LOCKED"
"$DRIVE" wait Peeker window locked.pdf
front
"$DRIVE" wait Peeker control Unlock
unlock
"$DRIVE" wait Peeker control "Rotate Right"
"$DRIVE" press Peeker "Rotate Right"

# Recovery records are written about 2 s after the last edit; kill only once all are there and settled.
for _ in $(seq 100); do [ "$(records)" -ge 3 ] && break; sleep 0.1; done
check "All three edited documents have a recovery record" "$(records)" 3
check "The locked PDF's record is sealed" "$(cat "$OUT"/recovery/*.json | grep -cF '"sealed"')" 1
sleep 1
pkill -KILL -f "$BIN"
for _ in $(seq 50); do pgrep -f "$BIN" >/dev/null || break; sleep 0.1; done

# Editor windows join as tabs, so the two come back as tabs of one window.
launch
"$DRIVE" wait Peeker control notes.txt --timeout 10 && "$DRIVE" wait Peeker control form.pdf --timeout 10
"$DRIVE" wait Peeker control locked.pdf --timeout 10
check "All three documents come back" "$("$DRIVE" tree Peeker 3 | grep -cE 'AXRadioButton “(notes\.txt|form\.pdf|locked\.pdf)”')" 3
front
"$DRIVE" press Peeker notes.txt
"$DRIVE" wait Peeker window notes.txt
check "The typed text comes back" "$([ "$(shown 'Typed before the crash')" -gt 0 ] && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/2-restored-notes.png" notes.txt
"$DRIVE" press Peeker form.pdf
"$DRIVE" wait Peeker window form.pdf
check "The filled field comes back" "$([ "$(shown 'Jane Doe')" -gt 0 ] && echo yes)" yes
"$DRIVE" shot Peeker "$OUT/3-restored-form.png" form.pdf
"$DRIVE" press Peeker locked.pdf
"$DRIVE" wait Peeker window locked.pdf
check "The locked PDF comes back on its lock screen" "$("$DRIVE" wait Peeker control Unlock --timeout 3 >/dev/null 2>&1 && echo yes)" yes
unlock
"$DRIVE" shot Peeker "$OUT/4-restored-locked.png" locked.pdf
# Saving proves the turned page came back, and that it saves still locked.
"$DRIVE" menu Peeker File Save && sleep 1.5
check "The recovered locked PDF saves still locked" "$("$PDF" inspect "$LOCKED" | head -1)" locked
check "with its page turned" "$("$PDF" inspect "$LOCKED" secret | grep -c '^page 1: .*rotation 90')" 1
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window locked.pdf --gone

# A restored document is marked edited: closing its tab asks to save. Don't Save drops its record.
for name in first second; do
    "$DRIVE" keys Peeker cmd+w
    check "Closing the $name restored tab asks to save" "$("$DRIVE" wait Peeker sheet --timeout 3 2>/dev/null && echo asked)" asked
    "$DRIVE" press Peeker "Don't Save"
    "$DRIVE" wait Peeker sheet --gone
    sleep 0.5
done
for _ in $(seq 30); do [ "$(records)" = 0 ] && break; sleep 0.1; done
check "Don't Save clears the recovery records" "$(records)" 0

finish
