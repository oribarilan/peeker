#!/bin/zsh
# Builds Peeker (Release, this Mac's architecture). Signs with your first "Apple Development" identity when you
# have one, so macOS keeps the Accessibility and Automation permissions across rebuilds (ad-hoc signatures change
# every build). Full log: build/build.log. `scripts/build.sh test` also checks that plugins import only what they may.
set -uo pipefail
cd ${0:A:h:h}
if [[ ${1:-} == test ]]; then scripts/check-plugin-imports.sh || exit 1; fi
identity=$(security find-identity -v -p codesigning | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"')
xcodegen generate --quiet || exit 1
mkdir -p build
# Every package is public: reading logins from ~/.netrc rather than the Keychain keeps a Keychain prompt (hidden
# behind a locked screen, say) from stalling the build.
xcodebuild -project Peeker.xcodeproj -scheme Peeker -configuration Release -derivedDataPath build/dd -packageAuthorizationProvider netrc \
  -destination "platform=macOS,arch=$(uname -m)" ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="${identity:--}" "${@:-build}" > build/build.log 2>&1
result=$?
grep -E "^/.*(error|warning): |^\*\* .* \*\*$|✘|✔ Test run" build/build.log | sort -u
exit $result
