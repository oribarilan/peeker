#!/bin/bash
# Prints the version and build number of a release tag, such as "0.2.1 201" for v0.2.1. The build number is
# major × 10000 + minor × 100 + patch, so it grows with every release; minor and patch stay under 100 for that.
# usage: scripts/release-version.sh vMAJOR.MINOR.PATCH
set -u
tag=${1:-}
number='(0|[1-9][0-9]*)'
small='(0|[1-9][0-9]?)'
if [[ ! $tag =~ ^v$number\.$small\.$small$ ]]; then
    echo "“${tag}” isn't a release tag: use vMAJOR.MINOR.PATCH, such as v0.2.1, without leading zeros and with minor and patch under 100" >&2
    exit 1
fi
major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
echo "$major.$minor.$patch $((major * 10000 + minor * 100 + patch))"
