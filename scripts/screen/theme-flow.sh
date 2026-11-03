#!/bin/bash
# The text theme flow on screen: clicking the Paper card in Settings > Appearance writes "textTheme": "paper" to
# config.json and recolors an open Markdown file and a text file at once, without reopening them; Space on a Markdown
# file then shows the Peek panel in Paper too, and a Python file's `def` moves from System's keyword color to Paper's
# (sampled with drive closest, since text is antialiased). Appearance Dark turns the app dark, and Text appearance Light then gives
# the Markdown window Paper's light page in the dark app. A config naming a theme Peeker doesn't have is reported in
# the menu bar icon while the files go back to System. Writes screenshots and results.txt (one ok/FAIL line per check)
# to its evidence folder, plus a screen recording with SCREEN_RECORD=1.
#
# Colors are read from window screenshots with drive pixel, at a spot right of the sidebar and below the short text,
# so it's the text area's background. Takes over the keyboard and Finder for about 30 seconds: the screen must be
# unlocked and left alone.
# usage: theme-flow.sh [path/to/Peeker.app]
FLOW=theme
source "$(dirname "$0")/common.sh" "$@"

MD="$OUT/notes.md" TXT="$OUT/notes.txt" PEEK="$OUT/peek.md" PY="$OUT/tool.py"
printf '# Notes\n\nSome **bold** words.\n' > "$MD"
printf 'Plain text.\n' > "$TXT"
printf '# Peek\n\nShort.\n' > "$PEEK"  # its own name, so the Peek panel's title isn't a window's
printf 'def size(path):\n    return len(path)\n' > "$PY"
# Paper's background, light or dark to match the system.
paper=F7F3EA
[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = Dark ] && paper=23211D
# The keyword color of System and of Paper, in the system's look.
system_keyword=9B2393 paper_keyword=9A3D6B
[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = Dark ] && system_keyword=FC5FA3 paper_keyword=D48BB2

cfg() { python3 -c 'import json, sys; c = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$CONFIG" "$1" 2>/dev/null || echo "unreadable"; }
# Opening a file that's already open brings its window (or tab) to the front, so this shows it without reopening.
show() { open -a "$APP" "$1"; "$DRIVE" wait Peeker window "$(basename "$1")"; sleep 0.5; }
# Screenshots the named window into <shot>.png and prints the color of its text area's background.
background() { "$DRIVE" shot Peeker "$OUT/$2.png" "$1" && "$DRIVE" pixel "$OUT/$2.png" 0.75 0.8 || echo none; }
# Whether two RRGGBB colors are within 3 of each other on each channel (a screenshot's color conversion can be off by
# one or two). System's dark background and Paper's dark one differ by about 5, so keep it tight.
near() {
    local i d
    [ ${#1} = 6 ] && [ ${#2} = 6 ] || return 1
    for i in 0 2 4; do
        d=$((16#${1:i:2} - 16#${2:i:2}))
        [ ${d#-} -le 3 ] || return 1
    done
}
# Whether an RRGGBB color is dark: every channel under 0x60.
darkish() {
    local i
    [ ${#1} = 6 ] || return 1
    for i in 0 2 4; do [ $((16#${1:i:2})) -lt 96 ] || return 1; done
}
# The Settings window's title: "Settings" when it opens, the pane's name once a pane is clicked.
settings() { "$DRIVE" windows Peeker | grep -oE '(Settings|Appearance)$' | head -1; }
# How far the drawn color of `def` in tool.py is from $1 (0 is exact; text is antialiased, so a little off), leaving
# the screen capture in <shot>.png.
keyword_distance() {
    local x y w h
    show "$PY"
    read -r x y w h <<< "$("$DRIVE" textframe Peeker "def" || echo "0 0 0 0")"
    screencapture -x "$OUT/$2.png"
    [ "$w" -gt 0 ] && "$DRIVE" closest "$OUT/$2.png" "$x" "$y" "$w" "$h" "$1" | cut -d' ' -f1 || echo none
}
fingerprint() { shasum "$OUT/$1.png" 2>/dev/null | cut -c1-12; }
# Presses Space on peek.md in Finder and prints the Peek panel's background, leaving its screenshot in <shot>.png.
peek() {
    "$DRIVE" select "$PEEK"
    sleep 2.5  # Finder answers the select script first; Space too soon can find it busy
    "$DRIVE" keys Finder space
    if "$DRIVE" wait Peeker window peek.md >/dev/null 2>&1; then sleep 0.5; background peek.md "$1"; else echo none; fi
    "$DRIVE" keys Finder escape  # the panel never takes focus, so Finder stays in front
    "$DRIVE" wait Peeker window peek.md --gone >/dev/null 2>&1
}

# A Markdown file and a text file, in tabs or windows; with no theme set, both are System.
launch "$MD"
open -a "$APP" "$TXT"
"$DRIVE" wait Peeker window notes.txt
open -a "$APP" "$PY"
"$DRIVE" wait Peeker window tool.py
record theme 60
show "$MD"
system_md=$(background notes.md 1-system-markdown)
show "$TXT"
system_txt=$(background notes.txt 2-system-text)
system_peek=$(peek 3-system-peek-panel)
check "With no theme, the files aren't Paper" "$(near "$system_md" "$paper" || near "$system_txt" "$paper" || echo no)" no
d=$(keyword_distance "$system_keyword" 3b-system-code)
check "Python's def is in System's keyword color" "$([ "$d" != none ] && [ "$d" -le 40 ] && echo yes || echo "off by $d")" yes

# Settings > Appearance's Paper card: Paper is written to the file at once.
"$DRIVE" menuextra Peeker "Settings…"
"$DRIVE" wait Peeker window Settings
"$DRIVE" row Peeker Appearance
"$DRIVE" wait Peeker control Paper
"$DRIVE" press Peeker Paper
for _ in $(seq 20); do [ "$(cfg "c.get('textTheme')")" = paper ] && break; sleep 0.1; done
check "Picking Paper writes textTheme paper" "$(cfg "c.get('textTheme')")" paper
"$DRIVE" shot Peeker "$OUT/4-settings-paper.png" "$(settings)"

# Both files take Paper's colors without being reopened, and so does the Peek panel.
show "$MD"
paper_md=$(background notes.md 5-paper-markdown)
check "The Markdown window changes" "$([ "$(fingerprint 1-system-markdown)" != "$(fingerprint 5-paper-markdown)" ] && echo yes)" yes
check "The Markdown window has Paper's background" "$(near "$paper_md" "$paper" && echo yes || echo "$paper_md")" yes
show "$TXT"
paper_txt=$(background notes.txt 6-paper-text)
check "The text window changes" "$([ "$(fingerprint 2-system-text)" != "$(fingerprint 6-paper-text)" ] && echo yes)" yes
check "The text window has Paper's background" "$(near "$paper_txt" "$paper" && echo yes || echo "$paper_txt")" yes
paper_peek=$(peek 7-paper-peek-panel)
check "The Peek panel changes" "$([ "$(fingerprint 3-system-peek-panel)" != "$(fingerprint 7-paper-peek-panel)" ] && echo yes)" yes
d=$(keyword_distance "$paper_keyword" 7b-paper-code)
check "Python's def turns Paper's keyword color" "$([ "$d" != none ] && [ "$d" -le 40 ] && echo yes || echo "off by $d")" yes
check "The Peek panel has Paper's background" "$(near "$paper_peek" "$paper" && echo yes || echo "$paper_peek (System was $system_peek)")" yes

# Appearance Dark: written to the file, and Settings turns dark. Settings reopens on Appearance, the last pane shown.
"$DRIVE" menuextra Peeker "Settings…"
"$DRIVE" wait Peeker control Paper
"$DRIVE" press Peeker Dark "AXRadioGroup=Appearance"
for _ in $(seq 20); do [ "$(cfg "c.get('appearance')")" = dark ] && break; sleep 0.1; done
check "Picking Dark writes appearance dark" "$(cfg "c.get('appearance')")" dark
sleep 0.5
"$DRIVE" shot Peeker "$OUT/11-settings-dark.png" "$(settings)"
settings_dark=$("$DRIVE" pixel "$OUT/11-settings-dark.png" 0.1 0.9 || echo none)
check "Settings turns dark" "$(darkish "$settings_dark" && echo yes || echo "$settings_dark")" yes

# Text appearance Light: the Markdown window shows Paper's light page while its sidebar stays dark.
"$DRIVE" press Peeker Light "AXRadioGroup=Text appearance"
for _ in $(seq 20); do [ "$(cfg "c.get('textAppearance')")" = light ] && break; sleep 0.1; done
check "Picking Light writes textAppearance light" "$(cfg "c.get('textAppearance')")" light
"$DRIVE" shot Peeker "$OUT/12-appearance-settings.png" "$(settings)"
show "$MD"
light_md=$(background notes.md 13-light-page-dark-app)
check "The Markdown window has Paper's light page" "$(near "$light_md" F7F3EA && echo yes || echo "$light_md")" yes
sidebar_md=$("$DRIVE" pixel "$OUT/13-light-page-dark-app.png" 0.05 0.8 || echo none)
check "Its sidebar stays dark" "$(darkish "$sidebar_md" && echo yes || echo "$sidebar_md")" yes

# A theme Peeker doesn't have is a config problem, and the files go back to System (the config's appearances go too).
echo '{"textTheme": "nope"}' > "$CONFIG"
sleep 2
( sleep 1; screencapture -x "$OUT/8-unknown-theme-menu.png" ) &
menu=$(DRIVE_HOLD=2.5 "$DRIVE" menuextra Peeker)
wait $!
check "An unknown theme shows in the menu bar icon" "$(echo "$menu" | grep -o 'Config has 1 problem' | head -1)" "Config has 1 problem"
show "$MD"
nope_md=$(background notes.md 9-unknown-markdown)
check "The Markdown window is System again" "$(near "$nope_md" "$system_md" && echo yes || echo "$nope_md")" yes
show "$TXT"
nope_txt=$(background notes.txt 10-unknown-text)
check "The text window is System again" "$(near "$nope_txt" "$system_txt" && echo yes || echo "$nope_txt")" yes

echo '{}' > "$CONFIG"
sleep 1
finish
