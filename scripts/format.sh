#!/bin/bash
# Formats every Swift file in the repo as .swift-format says, in place. scripts/lint.sh fails until this has run.
# usage: scripts/format.sh
set -euo pipefail
cd "$(dirname "$0")/.."
git ls-files -z '*.swift' | xargs -0 xcrun swift-format format --in-place --parallel
