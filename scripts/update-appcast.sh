#!/bin/bash
# Adds a release to Sparkle's update feed: FEED/appcast.xml gains an item for the DMG, with its download address on
# the GitHub Release, its EdDSA signature and its notes, and keeps the items already there. Only appcast.xml changes
# in FEED; the DMG never goes there. Reads the private EdDSA key from SPARKLE_PRIVATE_KEY.
# usage: scripts/update-appcast.sh VERSION path/to/Peeker-VERSION.dmg path/to/notes.md FEED_DIR
set -euo pipefail
version=${1:?} dmg=${2:?} notes=${3:?} feed=${4:?}
: "${SPARKLE_PRIVATE_KEY:?set SPARKLE_PRIVATE_KEY to the private EdDSA key (docs/releasing.md)}"
tools=$(cd "$(dirname "$0")/.." && pwd)/build/release/dd/SourcePackages/artifacts/sparkle/Sparkle/bin
[ -x "$tools/generate_appcast" ] || tools=$(cd "$(dirname "$0")/.." && pwd)/build/dd/SourcePackages/artifacts/sparkle/Sparkle/bin
[ -x "$tools/generate_appcast" ] || { echo "no Sparkle tools: build first (scripts/release.sh)" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
[ -f "$feed/appcast.xml" ] && cp "$feed/appcast.xml" "$work/"
cp "$dmg" "$work/Peeker-$version.dmg"
cp "$notes" "$work/Peeker-$version.md"
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$tools/generate_appcast" --ed-key-file - --embed-release-notes --maximum-deltas 0 \
    --download-url-prefix "https://github.com/oribarilan/peeker/releases/download/v$version/" \
    --link https://github.com/oribarilan/peeker "$work"
cp "$work/appcast.xml" "$feed/appcast.xml"
