#!/bin/bash
# Launches the built app once per case in benchmark mode, which opens the file through the real catalog and config
# and records which plugin opened it (or "no plugin"). Works with the screen locked; no permissions needed.
#
# usage: e2e-routing.sh [path/to/Peeker.app]
set -u
APP=${1:-build/dd/Build/Products/Release/Peeker.app}
BIN="$APP/Contents/MacOS/Peeker"
[ -x "$BIN" ] || { echo "no app at $APP; run scripts/build.sh first"; exit 2; }
pgrep -qf "$BIN" && { echo "Peeker is already running from $APP; quit it first"; exit 2; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
F="$WORK/files"
mkdir -p "$F/folder"
printf '# Notes\n\nSome **Markdown**.\n' > "$F/notes.md"
printf '# Upper\n' > "$F/README.MD"
printf 'server {\n  listen 80;\n}\n' > "$F/nginx.conf"
printf 'export EDITOR=vim\n' > "$F/.zshrc"
printf 'all:\n\tswift build\n' > "$F/Makefile"
printf 'const x: number = 1\n' > "$F/app.ts"
printf 'not a real movie' > "$F/movie.mp4"
printf '%%PDF-1.4\n' > "$F/empty.pdf"
sips -s format png -z 32 32 /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericDocumentIcon.icns --out "$F/photo.png" >/dev/null
ln -s "$F/notes.md" "$F/link.txt"

config() { printf '%s' "$2" > "$WORK/$1.json"; }
config default '{}'
config moved '{"plugins": {"text": {"extensions": ["txt", "md"]}, "markdown": {"extensions": ["markdown"]}}}'
config off '{"plugins": {"markdown": {"enabled": false}}}'
config clash '{"plugins": {"text": {"extensions": ["txt", "png"]}}}'

# config | file | expected plugin id, or "no plugin" (expected failures from opening count as routed to that plugin)
CASES="
default|notes.md|markdown
default|README.MD|markdown
default|nginx.conf|text
default|.zshrc|text
default|Makefile|text
default|app.ts|text
default|photo.png|image
default|empty.pdf|pdf
default|link.txt|markdown
default|movie.mp4|no plugin
default|folder|no plugin
moved|notes.md|text
moved|nginx.conf|no plugin
off|notes.md|no plugin
clash|photo.png|image
"

pass=0 fail=0
while IFS='|' read -r cfg file want; do
    [ -z "$cfg" ] && continue
    for mode in window panel; do
        out="$WORK/out-$cfg-$mode-${file//\//_}.jsonl"
        PEEKER_CONFIG="$WORK/$cfg.json" PEEKER_BENCH_OUT="$out" PEEKER_BENCH_MODE=$mode PEEKER_BENCH_REPEAT=1 \
            perl -e 'alarm 30; exec @ARGV' "$BIN" "$F/$file" >/dev/null 2>&1
        got=$(python3 -c 'import json,sys
rows=[json.loads(l) for l in open(sys.argv[1])] if __import__("os").path.exists(sys.argv[1]) else []
r=rows[0] if rows else {}
print(r.get("plugin") or r.get("failure") or "no output")' "$out")
        if [ "$got" = "$want" ]; then pass=$((pass+1)); mark=ok; else fail=$((fail+1)); mark=FAIL; fi
        printf '%-4s %-7s %-6s %-11s -> %s' "$mark" "$cfg" "$mode" "$file" "$got"
        [ "$mark" = FAIL ] && printf '   (wanted %s)' "$want"
        detail=$(python3 -c 'import json,sys
r=[json.loads(l) for l in open(sys.argv[1])][0]
print(r.get("failure","") if r.get("plugin") else "")' "$out" 2>/dev/null)
        [ -n "$detail" ] && printf '   [open failed: %s]' "$detail"
        echo
    done
done <<< "$CASES"
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
