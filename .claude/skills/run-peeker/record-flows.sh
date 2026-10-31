#!/bin/bash
# Records the user-facing flows as evidence: Space in Finder on files Peeker opens and on files it leaves to Quick
# Look, Open With in a document window, a config clash in the menu bar icon, and changes made in Settings (a plugin
# off and on, moving an extension and Reset, the quick-look key recorder and Off, a new PDF shortcut). Writes
# screenshots, a screen recording and results.txt (one ok/FAIL line per check) to build/evidence/<time>/.
#
# Takes over the keyboard and Finder for about four minutes: the screen must be unlocked and left alone.
# usage: record-flows.sh [path/to/Peeker.app]
set -u
cd "$(git rev-parse --show-toplevel)"
APP=${1:-build/dd/Build/Products/Release/Peeker.app}
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"  # open -a needs an absolute path
TOOLS=build/run-tools
DRIVE=$TOOLS/drive
mkdir -p "$TOOLS"
swiftc -O .claude/skills/run-peeker/drive.swift -o "$DRIVE" || exit 2
swiftc -O .claude/skills/run-peeker/pdf-tool.swift -o "$TOOLS/pdf-tool" || exit 2
"$DRIVE" locked >/dev/null && { echo "the screen is locked: unlock it and leave it alone while this runs"; exit 2; }

OUT=build/evidence/$(date +%Y%m%d-%H%M%S)
F="$PWD/$OUT/files"
mkdir -p "$F/folder"
printf '# Release notes\n\nPeeker routes files **by extension**.\n\n| File | Plugin |\n|---|---|\n| notes.md | Markdown |\n| nginx.conf | Plain Text |\n\n```swift\nlet owner = catalog.owner(for: url)\n```\n' > "$F/notes.md"
printf 'export EDITOR=vim\nalias ll="ls -la"\npath+=(~/.local/bin)\n' > "$F/.zshrc"
printf 'not a real movie' > "$F/movie.mp4"
printf 'a\n' > "$F/folder/inside.txt"
base64 -d <<< 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=' > "$F/pixel.png"
"$TOOLS/pdf-tool" form "$F/form.pdf"
CONFIG="$PWD/$OUT/config.json"
echo '{}' > "$CONFIG"
RESULTS="$OUT/results.txt"
: > "$RESULTS"
check() { if [ "$2" = "$3" ]; then echo "ok    $1: $2" | tee -a "$RESULTS"; else echo "FAIL  $1: got $2, wanted $3" | tee -a "$RESULTS"; fi; }

osascript -e 'tell application "Peeker" to quit' >/dev/null 2>&1
sleep 1
open --env PEEKER_CONFIG="$CONFIG" -a "$APP"
sleep 2

# One big Finder window behind everything, so frames show Finder and Peeker rather than whatever else is open.
"$DRIVE" select "$F/notes.md"
osascript -e 'tell application "Finder" to set bounds of front Finder window to (bounds of window of desktop)' >/dev/null 2>&1
osascript -e 'tell application "Finder" to set b to bounds of front Finder window' -e 'tell application "Finder" to set bounds of front Finder window to {item 1 of b, (item 2 of b) + 30, item 3 of b, item 4 of b}' >/dev/null 2>&1
sleep 1
screencapture -v -V 300 -x -k -C "$OUT/flows.mov" &
RECORDER=$!
sleep 1

# Presses Space on a file in Finder and reports which app's window appeared: Peeker's panel or Finder's Quick Look.
space() {
    local name=$1 file=$2 want=$3
    "$DRIVE" select "$file"
    sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
    # What had the keyboard when Space was pressed, kept for a failed check.
    local state; state="front $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null), focus $(osascript -e 'tell application "System Events" to tell process "Finder" to get role of (value of attribute "AXFocusedUIElement")' 2>/dev/null)"
    "$DRIVE" windows | awk '{print $1}' > "$OUT/.before"
    "$DRIVE" key space
    sleep 3
    # Peeker's panel belongs to Peeker; Finder's Quick Look is a Finder window above the normal layer (macOS 27 gives
    # it no title; older versions titled it with the file's name).
    local owner; owner=$("$DRIVE" windows | awk -v name="$(basename "$file")" 'NR == FNR { seen[$1] = 1; next }
        !($1 in seen) && $2 == "Peeker" { print "Peeker"; exit }
        !($1 in seen) && $2 == "Finder" && ($4 != 0 || substr($0, length($0) - length(name) + 1) == name) { print "Quick Look"; exit }' "$OUT/.before" -)
    screencapture -x "$OUT/$name.png"
    check "Space on $(basename "$file")" "${owner:-nothing}" "$want"
    [ "${owner:-nothing}" = "$want" ] || echo "      ($state)" | tee -a "$RESULTS"
    "$DRIVE" key escape
    sleep 1
}

space 1-space-markdown "$F/notes.md" Peeker
space 2-space-dotfile "$F/.zshrc" Peeker
space 3-space-mp4 "$F/movie.mp4" "Quick Look"
space 4-space-folder "$F/folder" "Quick Look"

# Open With in a document window: Markdown, then Plain Text, then Image (which can't read it and says so).
open -a "$APP" "$F/notes.md"
sleep 2
"$DRIVE" shot Peeker "$OUT/5-window-markdown.png" notes.md
openwith() { "$DRIVE" tree Peeker 20 | grep -m1 AXPopUpButton | sed 's/.*= //'; }
check "A .md opens in Markdown" "$(openwith)" "Markdown"
"$DRIVE" choose Peeker "Plain Text" && sleep 1.5
"$DRIVE" shot Peeker "$OUT/6-openwith-plaintext.png" notes.md
check "Open With shows Plain Text" "$(openwith)" "Plain Text"
"$DRIVE" choose Peeker "Image" && sleep 1.5
"$DRIVE" shot Peeker "$OUT/7-openwith-image.png" notes.md
check "Open With shows Image" "$(openwith)" "Image"
"$DRIVE" menu Peeker File Close
sleep 1

# A clash: Plain Text also lists png, which stays with Image, and the menu bar icon reports the problem.
echo '{"plugins": {"text": {"extensions": ["txt", "png"]}}}' > "$CONFIG"
sleep 2
( sleep 1; screencapture -x "$OUT/8-config-clash-menu.png" ) &
menu=$(DRIVE_HOLD=2.5 "$DRIVE" menuextra Peeker)
wait $!
check "Clash shows in the menu bar icon" "$(echo "$menu" | grep -o 'Config has 1 problem' | head -1)" "Config has 1 problem"

# Settings: open it from the menu bar icon, change things, and check config.json after each change.
echo '{}' > "$CONFIG"
sleep 1.5
cfg() { python3 -c 'import json, sys; c = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$CONFIG" "$1" 2>/dev/null || echo "unreadable"; }
"$DRIVE" menuextra Peeker "Settings…"
sleep 1.5
"$DRIVE" shot Peeker "$OUT/9-settings-general.png"
"$DRIVE" row Peeker Image && sleep 0.8
"$DRIVE" press Peeker "Open files with Image" && sleep 1
check "Turning Image off writes enabled false" "$(cfg "c['plugins']['image']['enabled']")" False
"$DRIVE" shot Peeker "$OUT/10-settings-image-off.png"
"$DRIVE" press Peeker "Open files with Image" && sleep 1
check "Turning it back on" "$(cfg "c['plugins']['image']['enabled']")" True
# Image off sends Space on an image to Finder's Quick Look; on again, Peeker takes it back.
"$DRIVE" press Peeker "Open files with Image" && sleep 1
space 10b-space-image-off "$F/pixel.png" "Quick Look"
"$DRIVE" press Peeker "Open files with Image" && sleep 1
space 10c-space-image-on "$F/pixel.png" Peeker
front() { osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1; sleep 0.8; }

# Adding md with Return offers to move it; Reset on either pane gives it back to Markdown.
front
"$DRIVE" row Peeker "Plain Text" && sleep 0.8
# Setting the field's text through Accessibility doesn't reach SwiftUI's binding, so focus it and type.
"$DRIVE" fill Peeker "Add an extension" "" && sleep 0.3 && "$DRIVE" type Peeker md && "$DRIVE" keys Peeker return && sleep 1
"$DRIVE" shot Peeker "$OUT/11-settings-move-md.png"
"$DRIVE" press Peeker "Move to Plain Text"; sleep 1
check "Move takes md from Markdown to Plain Text" "$(cfg "'md' in c['plugins']['text']['extensions'] and 'md' not in c['plugins']['markdown']['extensions']")" True
"$DRIVE" row Peeker Markdown && sleep 0.8
"$DRIVE" press Peeker "Reset to Defaults" && sleep 1
check "Reset on Markdown takes md back" "$(cfg "'md' in c['plugins']['markdown']['extensions'] and 'md' not in c['plugins']['text']['extensions']")" True
"$DRIVE" row Peeker "Plain Text" && sleep 0.8
"$DRIVE" fill Peeker "Add an extension" "" && sleep 0.3 && "$DRIVE" type Peeker md && "$DRIVE" keys Peeker return && sleep 1
"$DRIVE" press Peeker "Move to Plain Text"; sleep 1
"$DRIVE" press Peeker "Reset to Defaults" && sleep 1
check "Reset on Plain Text gives md back to Markdown" "$(cfg "'md' in c['plugins']['markdown']['extensions'] and 'md' not in c['plugins']['text']['extensions']")" True

# The quick-look key: record Option-Space, use it, record it again while it's the key, then Off.
"$DRIVE" row Peeker General && sleep 0.8
"$DRIVE" press Peeker "Shortcut Space, click to record" && sleep 0.5 && "$DRIVE" keys Peeker opt+space && sleep 1
check "Recording Option-Space writes it" "$(cfg "c['quickLook']['key']")" opt+space
"$DRIVE" select "$F/notes.md"
sleep 1.2
"$DRIVE" windows | awk '{print $1}' > "$OUT/.before"
"$DRIVE" keys Finder opt+space && sleep 1.5
check "Option-Space opens Peeker's panel" "$("$DRIVE" windows | awk 'NR == FNR { seen[$1] = 1; next } !($1 in seen) && $2 == "Peeker" { print "Peeker"; exit }' "$OUT/.before" -)" Peeker
screencapture -x "$OUT/12a-option-space.png"
"$DRIVE" key escape && sleep 1
front
"$DRIVE" windows | awk '{print $1}' > "$OUT/.before"
"$DRIVE" press Peeker "Shortcut ⌥Space, click to record" && sleep 0.5 && "$DRIVE" keys Peeker opt+space && sleep 1.5
check "Recording the current key records it, not the panel" "$("$DRIVE" windows | awk 'NR == FNR { seen[$1] = 1; next } !($1 in seen) && $2 == "Peeker" { print "panel"; exit }' "$OUT/.before" -)$(cfg "c['quickLook']['key']")" opt+space
"$DRIVE" press Peeker "Quick look panel" && sleep 1
check "Off writes off" "$(cfg "c['quickLook']['key']")" off
space 12b-space-key-off "$F/notes.md" "Quick Look"
front
"$DRIVE" press Peeker "Quick look panel" && sleep 1
check "On again is Space" "$(cfg "c['quickLook']['key']")" space

# A new Highlight Selection shortcut works in an open PDF: from the read view it turns on Edit mode. (Synthetic
# drags and Select All don't select PDF text, so the highlight itself is left to the integration test.)
"$DRIVE" row Peeker PDF && sleep 0.8
"$DRIVE" press Peeker "Shortcut ⌃⌘H, click to record" && sleep 0.5 && "$DRIVE" keys Peeker ctrl+opt+h && sleep 1
check "Recording ⌃⌥H writes it" "$(cfg "c['plugins']['pdf']['commands']['highlight']['shortcut']")" ctrl+opt+h
open -a "$APP" "$F/form.pdf" && sleep 2.5 && front
check "The new shortcut isn't in the read view's toolbar" "$("$DRIVE" tree Peeker 12 | grep -c '“Highlight Selection”')" 0
"$DRIVE" keys Peeker ctrl+opt+h && sleep 1
check "The new shortcut turns on Edit mode" "$("$DRIVE" tree Peeker 12 | grep -c '“Highlight Selection”' | awk '{print ($1 > 0) ? "yes" : "no"}')" yes
"$DRIVE" shot Peeker "$OUT/12c-pdf-shortcut.png" form.pdf
"$DRIVE" menu Peeker File Close && sleep 1

"$DRIVE" row Peeker Permissions && sleep 2
"$DRIVE" shot Peeker "$OUT/12-settings-permissions.png"
"$DRIVE" row Peeker General && sleep 0.8
printf '{"plugins": ' > "$CONFIG"
sleep 1.5
check "Broken JSON locks the switches" "$("$DRIVE" enabled Peeker "Quick look panel")" false
"$DRIVE" shot Peeker "$OUT/13-settings-locked.png"
echo '{}' > "$CONFIG"
sleep 1.5
check "Fixing the file unlocks them" "$("$DRIVE" enabled Peeker "Quick look panel")" true

echo '{}' > "$CONFIG"
osascript -e 'tell application "Peeker" to quit' >/dev/null 2>&1
sleep 1
kill -INT "$RECORDER" 2>/dev/null
wait "$RECORDER" 2>/dev/null
avconvert --preset Preset1920x1080 --source "$OUT/flows.mov" --output "$OUT/flows.mp4" >/dev/null 2>&1 && rm "$OUT/flows.mov"
echo "evidence in $OUT"
! grep -q FAIL "$RESULTS"
