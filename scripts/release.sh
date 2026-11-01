#!/bin/zsh
# Builds a release of Peeker from a tag: the app with the tag's version, signed with a Developer ID, notarized and
# stapled, inside a signed, notarized and stapled DMG with a shortcut to Applications. Prints the DMG's path last.
#
# Without a Developer ID identity it's a dry run: an unsigned build and DMG, stopping before anything is signed.
#
# usage: scripts/release.sh vX.Y.Z
# environment:
#   SIGN_IDENTITY        the signing identity; default: the first "Developer ID Application" in the keychain
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER
#                        an App Store Connect API key (.p8 file, key id, issuer id) for notarytool
#   NOTARY_PROFILE       or a notarytool keychain profile instead of the key
set -euo pipefail
cd ${0:A:h:h}
read -r version build <<< "$(scripts/release-version.sh "${1:-}")"
OUT=build/release
rm -rf $OUT
mkdir -p $OUT

identity=${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"' || true)}
signing=$([[ -n $identity ]] && echo yes || echo no)
if [[ $signing == yes ]]; then
    grep -q 'SPARKLE_PUBLIC_KEY: "[^"]' project.yml || { echo "project.yml has no SPARKLE_PUBLIC_KEY: updates couldn't be verified (docs/releasing.md)" >&2; exit 1; }
    if [[ -n ${NOTARY_KEY_PATH:-} ]]; then notary=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER:?}")
    elif [[ -n ${NOTARY_PROFILE:-} ]]; then notary=(--keychain-profile "$NOTARY_PROFILE")
    else echo "no notarization credentials: set NOTARY_KEY_PATH, NOTARY_KEY_ID and NOTARY_ISSUER, or NOTARY_PROFILE" >&2; exit 1
    fi
fi

echo "building Peeker $version ($build)…"
xcodegen generate --quiet
xcodebuild -project Peeker.xcodeproj -scheme Peeker -configuration Release -derivedDataPath $OUT/dd -packageAuthorizationProvider netrc \
    -destination "generic/platform=macOS" MARKETING_VERSION=$version CURRENT_PROJECT_VERSION=$build \
    CODE_SIGN_IDENTITY="${identity:--}" OTHER_CODE_SIGN_FLAGS="--timestamp" build > $OUT/build.log 2>&1 \
    || { grep -E "error:" $OUT/build.log | sort -u; echo "the build failed; see $OUT/build.log" >&2; exit 1; }
APP=$OUT/Peeker.app
ditto $OUT/dd/Build/Products/Release/Peeker.app $APP
shipped=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $APP/Contents/Info.plist)
[[ $shipped == $version ]] || { echo "the app reports $shipped, not $version" >&2; exit 1; }

# Peeker isn't sandboxed, so Sparkle's XPC services go; its helpers are signed inside out, as notarization needs.
SPARKLE=$APP/Contents/Frameworks/Sparkle.framework
rm -rf $SPARKLE/Versions/B/XPCServices $SPARKLE/XPCServices
if [[ $signing == yes ]]; then
    sign() { codesign --force --sign "$identity" --options runtime --timestamp "$@"; }
    sign $SPARKLE/Versions/B/Autoupdate
    sign $SPARKLE/Versions/B/Updater.app
    sign $SPARKLE
    sign --entitlements packaging/Peeker.entitlements $APP
    codesign --verify --deep --strict --verbose=2 $APP
    notarize() { xcrun notarytool submit "$1" "${notary[@]}" --wait --timeout 30m; }
    ditto -c -k --keepParent $APP $OUT/Peeker.zip
    echo "notarizing the app…"
    notarize $OUT/Peeker.zip
    xcrun stapler staple $APP
fi

DMG=$OUT/Peeker-$version.dmg
mkdir -p $OUT/dmg
ditto $APP $OUT/dmg/Peeker.app
ln -s /Applications $OUT/dmg/Applications
hdiutil create -quiet -volname "Peeker $version" -srcfolder $OUT/dmg -format UDZO -ov $DMG
if [[ $signing == yes ]]; then
    codesign --sign "$identity" --timestamp $DMG
    echo "notarizing the DMG…"
    notarize $DMG
    xcrun stapler staple $DMG
    spctl --assess --type open --context context:primary-signature --verbose $DMG
else
    echo "dry run: no Developer ID identity, so nothing was signed or notarized" >&2
fi
echo $DMG
