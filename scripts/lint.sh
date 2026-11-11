#!/bin/bash
# Checks the repo's style and rules, reporting every problem before failing: Swift formatted and linted as
# .swift-format says (scripts/format.sh fixes the formatting), no Swift file over 500 lines unless it's listed in
# scripts/long-files.txt and no longer than listed there, no em dashes, section signs or home-folder paths in tracked
# text, ShellCheck on the bash scripts, and plugins importing only what they may. scripts/build.sh test and CI run it.
# usage: scripts/lint.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failed=0

echo "Swift format and lint"
git ls-files -z '*.swift' | xargs -0 xcrun swift-format lint --strict --parallel || failed=1

echo "File length"
limit=500
while read -r lines file; do
    [ "$file" = total ] && continue
    allowed=$(awk -v f="$file" '$1 == f { print $2 }' scripts/long-files.txt)
    if [ "$lines" -gt "${allowed:-$limit}" ]; then
        echo "$file: $lines lines, over ${allowed:-$limit}; split it (see AGENTS.md)"
        failed=1
    fi
done < <(git ls-files -z '*.swift' | xargs -0 wc -l)

echo "Prose and privacy"
# OpenSpec writes its own skill and command files; they aren't ours to edit.
generated=(':!.claude/commands/opsx' ':!.claude/skills/openspec-*')
# Spelled as UTF-8 bytes, so this file doesn't hold the characters it looks for.
em_dash=$(printf '\342\200\224') section_sign=$(printf '\302\247')
if git grep -nI -e "$em_dash" -e "$section_sign" -- . "${generated[@]}"; then
    echo "Em dashes and section signs read as machine-written; rewrite the sentence (see AGENTS.md)."
    failed=1
fi
if git grep -nIE '/Users/[A-Za-z0-9._-]+/' -- . ':!scripts/lint.sh'; then
    echo "Home-folder paths are personal data; use a path relative to the repo."
    failed=1
fi

echo "ShellCheck"
if command -v shellcheck >/dev/null; then
    # ShellCheck reads sh and bash, not zsh.
    bash_scripts=()
    while IFS= read -r file; do head -1 "$file" | grep -q zsh || bash_scripts+=("$file"); done < <(git ls-files '*.sh')
    shellcheck "${bash_scripts[@]}" || failed=1
else
    echo "ShellCheck isn't installed: brew install shellcheck"
    failed=1
fi

echo "Plugin imports"
scripts/check-plugin-imports.sh || failed=1

[ $failed -eq 0 ] && echo "All checks pass."
exit $failed
