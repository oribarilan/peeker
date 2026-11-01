#!/bin/bash
# Prints the notes for one version from CHANGELOG.md: the body of its "## [VERSION] - DATE" section. Fails when the
# version has no section or an empty one, so a release can't go out without notes.
# usage: scripts/changelog-notes.sh VERSION [CHANGELOG]
set -u
version=${1:-}
file=${2:-$(dirname "$0")/../CHANGELOG.md}
[ -n "$version" ] && [ "$version" != Unreleased ] || { echo "usage: changelog-notes.sh VERSION [CHANGELOG], with a released version" >&2; exit 2; }
notes=$(awk -v heading="## [$version]" '
    index($0, heading) == 1 { inside = 1; next }
    inside && /^## / { exit }
    inside { print }
' "$file" | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')
[ -n "$notes" ] || { echo "CHANGELOG.md has no notes for $version: add a “## [$version] - YYYY-MM-DD” section" >&2; exit 1; }
printf '%s\n' "$notes"
