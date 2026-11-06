#!/bin/bash
# Records the user-facing flows as evidence: no window on a launch at login, Settings on a launch by hand, the Peek
# panel on Space in Finder for files Peeker opens, Finder's Quick Look for files it leaves alone, the panel's capped
# first size, a move that sticks and Settings' Reset Panel Size, Open With in an Editor window (the toolbar and File
# menu) and Revert to Saved…, a config clash in the menu bar icon, its Open… with no window open, and changes made in
# Settings (a plugin off and on, moving an extension and Reset, the Peek panel key recorder and Off, the update controls
# and a development build's Check for Updates…, a new PDF shortcut, clearing a shortcut and Reset, one recorder
# listening at a time, reopening on the last pane, General holding Open at Login and Default app, the add-extension
# field's placeholder), and the no-plugin alert's Open Settings. Writes screenshots and results.txt (one ok/FAIL line
# per check) to its evidence folder, plus a screen recording with SCREEN_RECORD=1; scripts/screen-test.sh runs it with
# the other flows.
#
# Takes over the keyboard and Finder for about two minutes: the screen must be unlocked and left alone.
# usage: record-flows.sh [path/to/Peeker.app]
FLOW=flows
source "$(dirname "$0")/common.sh" "$@"

F="$OUT/files"
mkdir -p "$F/folder"
printf '# Release notes\n\nPeeker routes files **by extension**.\n\n| File | Plugin |\n|---|---|\n| notes.md | Markdown |\n| nginx.conf | Plain Text |\n\n```swift\nlet owner = catalog.owner(for: url)\n```\n' > "$F/notes.md"
printf 'export EDITOR=vim\nalias ll="ls -la"\npath+=(~/.local/bin)\n' > "$F/.zshrc"
printf 'not a real movie' > "$F/movie.mp4"
printf 'a\n' > "$F/folder/inside.txt"
base64 -d <<< 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=' > "$F/pixel.png"
"$PDF" form "$F/form.pdf"
# A launch at login stays quiet: no Settings and no other window.
"$DRIVE" loginlaunch "$APP" PEEKER_CONFIG="$CONFIG" PEEKER_RECOVERY="$OUT/recovery"
for _ in $(seq 100); do pgrep -f "$BIN" >/dev/null && break; sleep 0.1; done
sleep 2
check "A launch at login opens no window" "$("$DRIVE" windows Peeker | awk '$4 < 25' | wc -l | tr -d ' ')" 0
quit_app || { echo "Peeker launched at login won't quit"; exit 2; }
launch
# Opened by hand with nothing to open, Peeker shows Settings; close it before the Space checks.
check "Opening Peeker by hand shows Settings" "$("$DRIVE" wait Peeker window Settings --timeout 5 2>/dev/null && echo yes)" yes
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window Settings --gone

# One big Finder window behind everything, so frames show Finder and Peeker rather than whatever else is open.
"$DRIVE" select "$F/notes.md"
osascript -e 'tell application "Finder" to set bounds of front Finder window to (bounds of window of desktop)' >/dev/null 2>&1
osascript -e 'tell application "Finder" to set b to bounds of front Finder window' -e 'tell application "Finder" to set bounds of front Finder window to {item 1 of b, (item 2 of b) + 30, item 3 of b, item 4 of b}' >/dev/null 2>&1
sleep 1
record flows 300
sleep 1

# Presses Space on a file in Finder and reports which app's window appeared: the Peek panel or Finder's Quick Look.
space() {
    local name=$1 file=$2 want=$3
    # Space on whatever else Finder has selected would test the wrong file.
    "$DRIVE" select "$file" || { check "Space on $(basename "$file")" "no Finder selection" "$want"; return; }
    sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
    # What had the keyboard when Space was pressed, kept for a failed check.
    local state; state="front $(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null), focus $(osascript -e 'tell application "System Events" to tell process "Finder" to get role of (value of attribute "AXFocusedUIElement")' 2>/dev/null)"
    "$DRIVE" windows | awk '{print $1}' > "$OUT/.before"
    "$DRIVE" keys Finder space
    sleep 3
    # The Peek panel belongs to Peeker; Finder's Quick Look is a Finder window above the normal layer (macOS 27 gives
    # it no title; older versions titled it with the file's name).
    local owner; owner=$("$DRIVE" windows | awk -v name="$(basename "$file")" 'NR == FNR { seen[$1] = 1; next }
        !($1 in seen) && $2 == "Peeker" { print "Peeker"; exit }
        !($1 in seen) && $2 == "Finder" && ($4 != 0 || substr($0, length($0) - length(name) + 1) == name) { print "Quick Look"; exit }' "$OUT/.before" -)
    screencapture -x "$OUT/$name.png"
    check "Space on $(basename "$file")" "${owner:-nothing}" "$want"
    [ "${owner:-nothing}" = "$want" ] || echo "      ($state)" | tee -a "$RESULTS"
    "$DRIVE" keys Finder escape  # the panel never takes focus, so Finder stays in front
    sleep 1
}

space 1-space-markdown "$F/notes.md" Peeker
space 2-space-dotfile "$F/.zshrc" Peeker
space 3-space-mp4 "$F/movie.mp4" "Quick Look"
space 4-space-folder "$F/folder" "Quick Look"

# The Peek panel's frame: the first Space opens it at most 900 × 700 points, a move sticks for the next Space, and
# Settings' Reset Panel Size forgets it.
panel() { osascript -e "tell application \"System Events\" to tell process \"Peeker\" to get $1 of window \"notes.md\"" 2>/dev/null | tr -d ' '; }
peek() { "$DRIVE" select "$F/notes.md" && sleep 2.5 && "$DRIVE" keys Finder space && "$DRIVE" wait Peeker window notes.md --timeout 5 >/dev/null; sleep 0.5; }
peek
first=$(panel size)
check "The first Space opens the panel at most 900 × 700 points" "$(echo "$first" | awk -F, '$1 > 0 && $1 <= 900 && $2 <= 700 { print "yes" }')" yes
osascript -e 'tell application "System Events" to tell process "Peeker" to set position of window "notes.md" to {80, 120}' >/dev/null 2>&1
sleep 0.5
"$DRIVE" keys Finder escape && sleep 1
peek
check "The next Space opens it where it was moved" "$(panel position)" "80,120"
"$DRIVE" shot Peeker "$OUT/4b-panel-moved.png" notes.md
"$DRIVE" keys Finder escape && sleep 1
"$DRIVE" menuextra Peeker "Settings…"
"$DRIVE" wait Peeker window Settings
check "Reset Panel Size is on once the panel has moved" "$("$DRIVE" enabled Peeker "Reset Panel Size")" true
"$DRIVE" press Peeker "Reset Panel Size" && sleep 0.5
check "Reset Panel Size greys out after a click" "$("$DRIVE" enabled Peeker "Reset Panel Size")" false
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1
sleep 0.5
"$DRIVE" keys Peeker cmd+w
"$DRIVE" wait Peeker window Settings --gone
peek
check "After Reset the panel opens at its first size again" "$(panel size)" "$first"
"$DRIVE" keys Finder escape && sleep 1

# Open With in an Editor window: Markdown, then Plain Text from the File menu, then back to Markdown from the toolbar,
# which lists only the plugins that read the file. In Plain Text, an edit and Revert to Saved… bring the file's text
# back. A photo's window has no Open With, since only Image reads it.
open -a "$APP" "$F/notes.md"
"$DRIVE" wait Peeker window notes.md
"$DRIVE" shot Peeker "$OUT/5-window-markdown.png" notes.md
openwith() { "$DRIVE" tree Peeker 20 | grep -m1 AXPopUpButton | sed 's/.*= //'; }
check "A .md opens in Markdown" "$(openwith)" "Markdown"
# In front, so its window is the key one and File > Open With lists its plugins.
osascript -e "tell application \"$APP\" to activate" >/dev/null 2>&1 && sleep 0.5
"$DRIVE" menu Peeker File "Plain Text" && sleep 1.5
"$DRIVE" shot Peeker "$OUT/6-openwith-plaintext.png" notes.md
check "File > Open With switches to Plain Text" "$(openwith)" "Plain Text"
# At the start, where the window's text shows in the Accessibility tree (it's cut off after 120 characters).
"$DRIVE" keys Peeker cmd+up
"$DRIVE" type Peeker "Typed then reverted. "
typed() { "$DRIVE" tree Peeker 20 | grep -c 'Typed then reverted'; }
check "The edit shows" "$(typed)" 1
"$DRIVE" menu Peeker File "Revert to Saved…"
check "Revert to Saved… asks first" "$("$DRIVE" wait Peeker sheet --timeout 5 2>/dev/null && echo yes)" yes
"$DRIVE" press Peeker Revert
"$DRIVE" wait Peeker sheet --gone
check "Reverting brings the saved text back" "$(typed)" 0
openwithitems() { "$DRIVE" choose Peeker | grep AXMenuItem | sed -E 's/.*“(.*)”.*/\1/' | paste -sd , -; }
check "Open With lists only plugins that read a .md" "$(openwithitems)" "Markdown,Plain Text"
sleep 1  # let the listed menu finish closing, or the next press finds it still open
"$DRIVE" choose Peeker "Markdown" && sleep 1.5
"$DRIVE" shot Peeker "$OUT/7-openwith-markdown.png" notes.md
check "Open With switches back to Markdown" "$(openwith)" "Markdown"
"$DRIVE" menu Peeker File Close
"$DRIVE" wait Peeker window notes.md --gone
# Only Image reads a photo, so its window has no Open With control.
open -a "$APP" "$F/pixel.png"
"$DRIVE" wait Peeker window pixel.png
"$DRIVE" shot Peeker "$OUT/7b-window-photo.png" pixel.png
check "A photo's window has no Open With" "$("$DRIVE" tree Peeker 20 | grep -c AXPopUpButton)" 0
"$DRIVE" menu Peeker File Close
"$DRIVE" wait Peeker window pixel.png --gone

# A clash: Plain Text also lists png, which stays with Image, and the menu bar icon reports the problem.
echo '{"plugins": {"text": {"extensions": ["txt", "png"]}}}' > "$CONFIG"
sleep 2
( sleep 1; screencapture -x "$OUT/8-config-clash-menu.png" ) &
menu=$(DRIVE_HOLD=2.5 "$DRIVE" menuextra Peeker)
wait $!
check "Clash shows in the menu bar icon" "$(echo "$menu" | grep -o 'Config has 1 problem' | head -1)" "Config has 1 problem"

# Open… in the menu bar icon's menu, with no window open: the Open panel comes up in front, and after Cancel Peeker
# has no Dock icon again.
sleep 1  # the clash step's menu must be closed before this click opens it again
"$DRIVE" menuextraclick Peeker "Open…"
"$DRIVE" wait Peeker window Open --timeout 5
front_app() { osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'; }
for _ in 1 2 3 4; do [ "$(front_app)" = Peeker ] && break; sleep 0.5; done
check "Open… from the menu bar icon brings the Open panel to the front" "$(front_app)" Peeker
"$DRIVE" press Peeker Cancel
"$DRIVE" wait Peeker window Open --gone
sleep 0.5
check "After Cancel Peeker has no Dock icon" "$(lsappinfo info -only ApplicationType "$(lsappinfo find bundleid=dev.peeker.Peeker)" | grep -o UIElement)" UIElement

# Settings: open it from the menu bar icon, change things, and check config.json after each change.
echo '{}' > "$CONFIG"
sleep 1.5
cfg() { python3 -c 'import json, sys; c = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$CONFIG" "$1" 2>/dev/null || echo "unreadable"; }
"$DRIVE" menuextra Peeker "Settings…"
"$DRIVE" wait Peeker window Settings
"$DRIVE" shot Peeker "$OUT/9-settings-general.png"
# General names the Peek panel and holds Open at Login and the Default app list.
check "General's toggle reads Peek panel" "$("$DRIVE" enabled Peeker "Peek panel" 2>/dev/null)" true
general=$("$DRIVE" tree Peeker 16)
check "General has Open at Login and Default app" "$(grep -c 'Open at Login' <<< "$general" | awk '{print ($1 > 0) ? "yes" : "no"}')$(grep -c 'Default app' <<< "$general" | awk '{print ($1 > 0) ? "yes" : "no"}')" yesyes
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
check "The add-extension field shows its placeholder" "$("$DRIVE" placeholders Peeker | grep -cx 'Add an extension')" 1
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

# The Peek panel key: record Option-Shift-Space, use it, record it again while it's the key, then Off. Not
# Option-Space, which other apps often take for themselves.
"$DRIVE" row Peeker General && sleep 0.8
"$DRIVE" press Peeker "Shortcut Space, click to record" && sleep 0.5 && "$DRIVE" keys Peeker opt+shift+space && sleep 1
check "Recording Option-Shift-Space writes it" "$(cfg "c['peekPanel']['key']")" opt+shift+space
"$DRIVE" select "$F/notes.md"
sleep 1.2
"$DRIVE" windows | awk '{print $1}' > "$OUT/.before"
"$DRIVE" keys Finder opt+shift+space && sleep 1.5
check "Option-Shift-Space opens Peeker's panel" "$("$DRIVE" windows | awk 'NR == FNR { seen[$1] = 1; next } !($1 in seen) && $2 == "Peeker" { print "Peeker"; exit }' "$OUT/.before" -)" Peeker
screencapture -x "$OUT/12a-option-shift-space.png"
"$DRIVE" keys Finder escape && sleep 1
front
"$DRIVE" windows | awk '{print $1}' > "$OUT/.before"
"$DRIVE" press Peeker "Shortcut ⌥⇧Space, click to record" && sleep 0.5 && "$DRIVE" keys Peeker opt+shift+space && sleep 1.5
check "Recording the current key records it, not the panel" "$("$DRIVE" windows | awk 'NR == FNR { seen[$1] = 1; next } !($1 in seen) && $2 == "Peeker" { print "panel"; exit }' "$OUT/.before" -)$(cfg "c['peekPanel']['key']")" opt+shift+space
"$DRIVE" press Peeker "Peek panel" && sleep 1
check "Off writes off" "$(cfg "c['peekPanel']['key']")" off
space 12b-space-key-off "$F/notes.md" "Quick Look"
front
"$DRIVE" press Peeker "Peek panel" && sleep 1
check "On again is Space" "$(cfg "c['peekPanel']['key']")" space

# Updates: the pop-up writes updates.automatic, the checkbox updates.showWhatsNew, the menu bar menu has no update
# line while none waits, and a development build's Check for Updates… says it doesn't update.
"$DRIVE" choose Peeker "Download and Install" "Automatic updates" && sleep 1
check "Download and Install writes download" "$(cfg "c['updates']['automatic']")" download
"$DRIVE" shot Peeker "$OUT/12f-settings-updates-download.png"
"$DRIVE" choose Peeker "Off" "Automatic updates" && sleep 1
check "Updates Off writes off" "$(cfg "c['updates']['automatic']")" off
"$DRIVE" choose Peeker "Check and Ask" "Automatic updates" && sleep 1
check "Check and Ask writes check" "$(cfg "c['updates']['automatic']")" check
"$DRIVE" press Peeker "Show what's new after updating" && sleep 1
check "Clearing what's new writes false" "$(cfg "c['updates']['showWhatsNew']")" False
"$DRIVE" press Peeker "Show what's new after updating" && sleep 1
check "Ticking it again writes true" "$(cfg "c['updates']['showWhatsNew']")" True
check "No update line while none waits" "$(DRIVE_HOLD=1 "$DRIVE" menuextra Peeker | grep -c 'Update to')" 0
"$DRIVE" menuextra Peeker "Check for Updates…"
"$DRIVE" wait Peeker control OK
check "A development build says it doesn't update" "$("$DRIVE" tree Peeker 8 | grep -c "Development builds don’t update\|Development builds don't update")" 1
screencapture -x "$OUT/12g-development-build-update.png"
"$DRIVE" press Peeker OK
"$DRIVE" wait Peeker control OK --gone
front

# A new Highlight shortcut works in an open PDF: it arms the highlighter at once. (Synthetic
# drags and Select All don't select PDF text, so the highlight itself is left to the integration test.)
"$DRIVE" row Peeker PDF && sleep 0.8
"$DRIVE" press Peeker "Shortcut H, click to record" && sleep 0.5 && "$DRIVE" keys Peeker ctrl+opt+h && sleep 1
check "Recording ⌃⌥H writes it" "$(cfg "c['plugins']['pdf']['tools']['highlight']['shortcut']")" ctrl+opt+h
# The clear button leaves Zoom In without a shortcut; Reset (Zoom In's is the pane's first) brings Cmd+= back.
"$DRIVE" press Peeker "Clear the shortcut for Zoom In" && sleep 1
check "Clearing a shortcut writes off" "$(cfg "c['plugins']['pdf']['tools']['zoom-in']['shortcut']")" off
"$DRIVE" shot Peeker "$OUT/12b-shortcut-cleared.png" Settings
"$DRIVE" press Peeker Reset && sleep 1
check "Reset brings the default back" "$(cfg "c['plugins']['pdf']['tools']['zoom-in']['shortcut']")" "cmd+="
open -a "$APP" "$F/form.pdf" && "$DRIVE" wait Peeker window form.pdf && front
"$DRIVE" keys Peeker ctrl+opt+h && sleep 1
check "The new shortcut arms Highlight" "$("$DRIVE" menuitems Peeker Tools | grep -cx '✓ Highlight')" 1
"$DRIVE" shot Peeker "$OUT/12c-pdf-shortcut.png" form.pdf
# Highlight colors: the Highlight button has an arrow for them, and Tools > Highlight Color picks one, arms Highlight,
# and is remembered for the next PDF window and in the app's preferences.
# AppKit names the group, "Highlight" and the shortcut; the arrow is an unnamed menu button in it.
check "The Highlight button has a color menu" "$("$DRIVE" tree Peeker 7 | grep -A3 'AXGroup “Highlight' | grep -c 'AXMenuButton')" 1
"$DRIVE" keys Peeker escape && sleep 0.3
"$DRIVE" menu Peeker Tools "Highlight Color>Green" && sleep 0.5
check "Picking Green checks it" "$("$DRIVE" menuitems Peeker "Tools>Highlight Color" | grep '^✓' | paste -sd ' ' -)" "✓ Green"
check "and arms Highlight" "$("$DRIVE" menuitems Peeker Tools | grep -cx '✓ Highlight')" 1
"$DRIVE" menu Peeker File Close && "$DRIVE" wait Peeker window form.pdf --gone
open -a "$APP" "$F/form.pdf" && "$DRIVE" wait Peeker window form.pdf && front
check "Green is still checked in the next window" "$("$DRIVE" menuitems Peeker "Tools>Highlight Color" | grep '^✓' | paste -sd ' ' -)" "✓ Green"
check "and remembered in the preferences" "$(defaults read "$PREFS" plugins.pdf.highlightColor 2>/dev/null)" green
"$DRIVE" menu Peeker File Close && "$DRIVE" wait Peeker window form.pdf --gone

# Settings reopens on the pane last shown, here PDF.
front
"$DRIVE" menu Peeker File Close && "$DRIVE" wait Peeker window Settings --gone
"$DRIVE" menuextra Peeker "Settings…"
"$DRIVE" wait Peeker window Settings
check "Settings reopens on the PDF pane" "$("$DRIVE" enabled Peeker "Open files with PDF" 2>/dev/null)" true

# Only one shortcut recorder listens at a time, the key goes to its command, and switching apps stops it, so Space
# reaches the panel again either way.
front
"$DRIVE" press Peeker "Shortcut ⌘=, click to record" && sleep 0.3
"$DRIVE" press Peeker "Shortcut ⌘-, click to record" && sleep 0.3
check "Only the last recorder pressed listens" "$("$DRIVE" tree Peeker 14 | grep -c '“Recording a shortcut”')" 1
"$DRIVE" keys Peeker opt+cmd+z && sleep 1
check "The key goes to that recorder's tool" "$(cfg "c['plugins']['pdf']['tools']['zoom-in']['shortcut'] + ' ' + c['plugins']['pdf']['tools']['zoom-out']['shortcut']")" "cmd+= opt+cmd+z"
space 12d-space-after-recording "$F/notes.md" Peeker
front
"$DRIVE" press Peeker "Shortcut ⌘=, click to record" && sleep 0.3
"$DRIVE" select "$F/notes.md" && sleep 1
check "Switching to Finder stops the recorder" "$("$DRIVE" tree Peeker 14 | grep -c '“Recording a shortcut”')" 0
space 12e-space-after-switching "$F/notes.md" Peeker
front

"$DRIVE" row Peeker Permissions && sleep 2
"$DRIVE" shot Peeker "$OUT/12-settings-permissions.png"
check "Permissions holds only the permissions" "$("$DRIVE" tree Peeker 16 | grep -c -E 'Open at Login|Default app')" 0
"$DRIVE" row Peeker General && sleep 0.8
printf '{"plugins": ' > "$CONFIG"
sleep 1.5
check "Broken JSON locks the switches" "$("$DRIVE" enabled Peeker "Peek panel")" false
"$DRIVE" shot Peeker "$OUT/13-settings-locked.png"
echo '{}' > "$CONFIG"
sleep 1.5
check "Fixing the file unlocks them" "$("$DRIVE" enabled Peeker "Peek panel")" true

# A file no plugin opens: the alert's Open Settings shows the Plain Text pane, where its extension can be added.
open -a "$APP" "$F/movie.mp4"
"$DRIVE" wait Peeker control "Open Settings"
"$DRIVE" shot Peeker "$OUT/14-no-plugin-alert.png"
"$DRIVE" press Peeker "Open Settings" && sleep 1
check "Open Settings shows the Plain Text pane" "$("$DRIVE" enabled Peeker "Open files with Plain Text" 2>/dev/null)" true

echo '{}' > "$CONFIG"
finish
