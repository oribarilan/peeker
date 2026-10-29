#!/bin/zsh
# Builds Preview++ (Release, this Mac's architecture). Signs with your first "Apple Development" identity when you
# have one, so macOS keeps the Accessibility and Automation permissions across rebuilds (ad-hoc signatures change
# every build). Full log: build/build.log.
set -uo pipefail
cd ${0:A:h:h}
identity=$(security find-identity -v -p codesigning | grep -m1 -o '"Apple Development: [^"]*"' | tr -d '"')
xcodegen generate --quiet
mkdir -p build
xcodebuild -project PreviewPP.xcodeproj -scheme PreviewPP -configuration Release -derivedDataPath build/dd \
  -destination "platform=macOS,arch=$(uname -m)" ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY="${identity:--}" "${@:-build}" > build/build.log 2>&1
result=$?
grep -E "^/.*(error|warning): |^\*\* .* \*\*$|✘|✔ Test run" build/build.log | sort -u
exit $result
