#!/bin/zsh
# Fails when a plugin imports something other than PeekerKit, a module from the macOS SDK, or a package it declares
# below. Xcode can let a target import a module it doesn't depend on, so this keeps plugins from reaching into the
# host or each other. Usage: scripts/check-plugin-imports.sh [repo root]
set -uo pipefail
root=${1:-${0:A:h:h}}
sdk=$(xcrun --sdk macosx --show-sdk-path) || exit 1

# Packages each plugin may import, by plugin folder name.
packages() {
  case $1 in
    markdown) print Markdown ;;
  esac
}

failed=0
for dir in $root/Plugins/*(/N); do
  plugin=${dir:t}
  allowed=(PeekerKit $(packages $plugin))
  for file in $dir/**/*.swift(N); do
    grep -nE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?[A-Za-z_]+' $file |
    while IFS= read -r hit; do
      module=$(print -r -- ${hit#*:} | sed -E 's/^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+((typealias|struct|class|enum|protocol|let|var|func)[[:space:]]+)?([A-Za-z_]+).*/\4/')
      (( ${allowed[(Ie)$module]} )) && continue
      [[ -d $sdk/System/Library/Frameworks/$module.framework || -e $sdk/usr/lib/swift/$module.swiftmodule ]] && continue
      print -r -- "${file#$root/}:${hit%%:*}: plugin '$plugin' may not import $module"
      failed=1
    done
  done
done
exit $failed
