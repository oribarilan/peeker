#!/bin/bash
# Prints the Homebrew cask for a release: packaging/peeker.rb with the version and the DMG's checksum filled in.
# usage: scripts/fill-cask.sh VERSION path/to/Peeker-VERSION.dmg
set -euo pipefail
version=${1:?usage: fill-cask.sh VERSION DMG} dmg=${2:?usage: fill-cask.sh VERSION DMG}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "“${version}” isn't a version like 0.1.0" >&2; exit 1; }
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)
sed -e "s/@VERSION@/$version/" -e "s/@SHA256@/$sha/" "$(dirname "$0")/../packaging/peeker.rb"
