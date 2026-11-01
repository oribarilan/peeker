# Shared setup for the screen flows; sourced, not run. The flow sets FLOW (its evidence folder's name) and passes
# its arguments: an optional path to Peeker.app.
#
# Gives the flow APP and BIN (the build under test), DRIVE and PDF (the tools), OUT (its evidence folder, absolute),
# CONFIG, RESULTS, check, launch, quit_app, record and finish, and installs the cleanup trap. Stops with exit 2 when
# the screen is locked or another copy of Peeker runs.
set -u
cd "$(git rev-parse --show-toplevel)"
APP=${1:-build/dd/Build/Products/Release/Peeker.app}
APP="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")"  # open -a needs an absolute path
BIN="$APP/Contents/MacOS/Peeker"
TOOLS=build/run-tools
DRIVE=$TOOLS/drive
PDF=$TOOLS/pdf-tool
mkdir -p "$TOOLS"
for tool in drive pdf-tool; do
    [ "$TOOLS/$tool" -nt "scripts/screen/$tool.swift" ] || swiftc -O "scripts/screen/$tool.swift" -o "$TOOLS/$tool" || exit 2
done
[ -x "$BIN" ] || { echo "no app at $APP; run scripts/build.sh first"; exit 2; }
"$DRIVE" locked >/dev/null && { echo "the screen is locked: unlock it and leave it alone while this runs"; exit 2; }
# Only the build under test is driven and quit; any other copy (an installed one, say) is left alone, so it must not run.
for pid in $(pgrep -x Peeker); do
    other=$(ps -o comm= -p "$pid")
    [ "$other" = "$BIN" ] || { echo "another Peeker is running ($other): quit it first"; exit 2; }
done

# Under scripts/screen-test.sh each flow gets a folder in the run's; on its own, a folder of its own.
OUT=${SCREEN_RUN:+$SCREEN_RUN/$FLOW}
OUT=${OUT:-build/evidence/$FLOW-$(date +%Y%m%d-%H%M%S)}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
CONFIG="$OUT/config.json"
echo '{}' > "$CONFIG"
RESULTS="$OUT/results.txt"
: > "$RESULTS"
check() { if [ "$2" = "$3" ]; then echo "ok    $1: $2" | tee -a "$RESULTS"; else echo "FAIL  $1: got $2, wanted $3" | tee -a "$RESULTS"; fi; }

# Asks the build under test to quit without waiting for a reply: with a Save prompt up, a waiting quit blocks until
# AppleScript's 2-minute timeout.
ask_to_quit() { osascript -e 'ignoring application responses' -e "tell application \"$APP\" to quit" -e 'end ignoring' >/dev/null 2>&1; }
# Quits the build under test and waits up to 5 s for it to go. False if it's still running (a Save prompt, say).
quit_app() {
    ask_to_quit
    for _ in $(seq 50); do pgrep -f "$BIN" >/dev/null || return 0; sleep 0.1; done
    return 1
}

# Launches the build under test with this run's config and crash-recovery folder, so the user's own are never read
# or written (both settings apply only to a fresh launch), and waits for it: for the file's window when given one.
launch() {
    open --env PEEKER_CONFIG="$CONFIG" --env PEEKER_RECOVERY="$OUT/recovery" -a "$APP" "$@"
    for _ in $(seq 100); do pgrep -f "$BIN" >/dev/null && break; sleep 0.1; done
    if [ $# -gt 0 ]; then "$DRIVE" wait Peeker window "$(basename "$1")" --timeout 10; else sleep 1; fi
}

# Opens a file in Preview and screenshots its window, as a check that another app reads what Peeker saved; then closes
# that window, quitting Preview only when it wasn't running before, so the user's own Preview windows are left alone.
preview_shot() {
    local name running id
    name=$(basename "$1")
    pgrep -xq Preview && running=yes
    open -a Preview "$1"
    "$DRIVE" wait Preview window "$name" --timeout 10
    sleep 1
    id=$("$DRIVE" windows Preview | awk -v name="$name" 'index($0, name) { print $1; exit }')
    [ -n "$id" ] && screencapture -x -o -l"$id" "$2"
    osascript -e "tell application \"Preview\" to close (every window whose name contains \"$name\")" >/dev/null 2>&1
    [ -n "${running:-}" ] || osascript -e 'tell application "Preview" to quit' >/dev/null 2>&1
    [ -n "$id" ]
}

# Screen recording, only with SCREEN_RECORD=1. screencapture can't stop early and keep its movie (it ignores SIGINT
# when started like this, and other signals drop the file), so a finished run waits for the time limit and an
# aborted one loses the recording.
RECORDER=
RECORDING=
record() {
    [ "${SCREEN_RECORD:-0}" = 1 ] || return 0
    RECORDING="$OUT/$1.mov"
    screencapture -v -V "$2" -x -k -C "$RECORDING" &
    RECORDER=$!
}

# The normal end: quit, keep the recording, and exit non-zero when a check failed.
finish() {
    quit_app
    if [ -n "$RECORDER" ]; then
        wait "$RECORDER"
        RECORDER=
        avconvert --preset Preset1920x1080 --source "$RECORDING" --output "${RECORDING%.mov}.mp4" >/dev/null 2>&1 && rm "$RECORDING"
    fi
    echo "evidence in $OUT"
    ! grep -q FAIL "$RESULTS"
    exit
}

# However the run ends, nothing is left running. Unsaved edits leave Quit waiting on a Save prompt; this run's files
# are throwaway, so answer Don't Save, and kill the build under test only if it still won't quit.
cleanup() {
    ask_to_quit
    [ -n "$RECORDER" ] && kill -TERM "$RECORDER" 2>/dev/null
    RECORDER=
    for _ in 1 2 3; do
        pgrep -f "$BIN" >/dev/null || return 0
        sleep 1
        "$DRIVE" press Peeker "Don't Save" >/dev/null 2>&1
    done
    pkill -f "$BIN" 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT TERM

quit_app || { echo "Peeker from $APP won't quit (a Save prompt?): close it first"; exit 2; }
