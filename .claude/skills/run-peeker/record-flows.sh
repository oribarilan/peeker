#!/bin/bash
# Records the user-facing routing flows as evidence: Space in Finder on files Peeker opens and on files it leaves to
# Quick Look, Open With in a document window, and a config clash in the menu bar icon. Writes screenshots, a screen
# recording and results.txt (one ok/FAIL line per check) to build/evidence/<time>/.
#
# Takes over the keyboard and Finder for about a minute: the screen must be unlocked and left alone.
# usage: record-flows.sh [path/to/Peeker.app]
set -u
cd "$(git rev-parse --show-toplevel)"
APP=${1:-build/dd/Build/Products/Release/Peeker.app}
TOOLS=build/run-tools
DRIVE=$TOOLS/drive
mkdir -p "$TOOLS"
swiftc -O .claude/skills/run-peeker/drive.swift -o "$DRIVE" || exit 2
"$DRIVE" locked >/dev/null && { echo "the screen is locked: unlock it and leave it alone while this runs"; exit 2; }

OUT=build/evidence/$(date +%Y%m%d-%H%M%S)
F="$PWD/$OUT/files"
mkdir -p "$F/folder"
printf '# Release notes\n\nPeeker routes files **by extension**.\n\n| File | Plugin |\n|---|---|\n| notes.md | Markdown |\n| nginx.conf | Plain Text |\n\n```swift\nlet owner = catalog.owner(for: url)\n```\n' > "$F/notes.md"
printf 'export EDITOR=vim\nalias ll="ls -la"\npath+=(~/.local/bin)\n' > "$F/.zshrc"
printf 'not a real movie' > "$F/movie.mp4"
printf 'a\n' > "$F/folder/inside.txt"
CONFIG="$PWD/$OUT/config.json"
echo '{}' > "$CONFIG"
RESULTS="$OUT/results.txt"
: > "$RESULTS"
check() { if [ "$2" = "$3" ]; then echo "ok    $1: $2" | tee -a "$RESULTS"; else echo "FAIL  $1: got $2, wanted $3" | tee -a "$RESULTS"; fi; }

osascript -e 'tell application "Peeker" to quit' >/dev/null 2>&1
sleep 1
open --env PEEKER_CONFIG="$CONFIG" -a "$APP"
sleep 2

screencapture -v -V 120 -x -k -C "$OUT/flows.mov" &
RECORDER=$!
sleep 1

# Presses Space on a file in Finder and reports which app's window appeared: Peeker's panel or Finder's Quick Look.
space() {
    local name=$1 file=$2 want=$3
    "$DRIVE" select "$file"
    sleep 1.2
    local before; before=$("$DRIVE" windows | awk '{print $1}')
    "$DRIVE" key space
    sleep 1.5
    local owner; owner=$("$DRIVE" windows | awk -v before="$before" 'BEGIN { split(before, b, "\n"); for (i in b) seen[b[i]] = 1 }
        !($1 in seen) && $2 != "Window" { print $2; exit }')
    screencapture -x "$OUT/$name.png"
    check "Space on $(basename "$file")" "${owner:-nothing}" "$want"
    "$DRIVE" key escape
    sleep 1
}

space 1-space-markdown "$F/notes.md" Peeker
space 2-space-dotfile "$F/.zshrc" Peeker
space 3-space-mp4 "$F/movie.mp4" QuickLookUIService
space 4-space-folder "$F/folder" QuickLookUIService

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

echo '{}' > "$CONFIG"
osascript -e 'tell application "Peeker" to quit' >/dev/null 2>&1
sleep 1
kill -INT "$RECORDER" 2>/dev/null
wait "$RECORDER" 2>/dev/null
avconvert --preset Preset1920x1080 --source "$OUT/flows.mov" --output "$OUT/flows.mp4" >/dev/null 2>&1 && rm "$OUT/flows.mov"
echo "evidence in $OUT"
! grep -q FAIL "$RESULTS"
