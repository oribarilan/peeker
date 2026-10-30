#!/bin/zsh
# Benchmarks the current checkout against a base ref on this machine and fails on clear regressions.
# CI runs exactly this; run it locally before merging too.
#
# usage: scripts/bench-ab.sh <base-ref> [bench/ppbench.py ab options, e.g. --launches 9]
set -euo pipefail
root=${0:A:h:h}
base_ref=${1:?usage: scripts/bench-ab.sh <base-ref>}
shift
worktree=$root/build/base-src
app=build/dd/Build/Products/Release/Peeker.app

git -C $root worktree remove --force $worktree 2>/dev/null || true
git -C $root worktree add --detach --quiet $worktree $base_ref
trap 'git -C $root worktree remove --force $worktree 2>/dev/null || true' EXIT
if [[ ! -f $worktree/bench/ppbench.py ]]; then
  echo "Base $base_ref predates the benchmark; nothing to compare against."
  exit 0
fi

echo "Building head…"; $root/scripts/build.sh
echo "Building base ($base_ref)…"; $worktree/scripts/build.sh
python3 $root/bench/ppbench.py ab --base $worktree/$app --head $root/$app "$@"
