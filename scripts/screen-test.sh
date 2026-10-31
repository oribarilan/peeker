#!/bin/bash
# Runs the screen tests: the routing check, then each flow, on the built app. Every flow runs even after one fails;
# the summary lists each one's ok and FAIL counts, and the exit status is non-zero when a check failed or a flow
# didn't finish. Evidence goes to build/evidence/run-<time>/<flow>/.
#
# Needs an unlocked screen left alone (about three minutes without video), Accessibility and Screen Recording for the
# terminal, and no other copy of Peeker running.
# usage: scripts/screen-test.sh [--record] [--no-build] [routing|flows|pdf-edit ...]
#   --record     also save a screen recording of each flow (slower: a recording runs to its time limit)
#   --no-build   test the app already in build/ instead of building first
set -u
cd "$(dirname "$0")/.."
all=(routing flows pdf-edit)
script() {
    case $1 in
    routing) echo scripts/screen/e2e-routing.sh ;;
    flows) echo scripts/screen/record-flows.sh ;;
    pdf-edit) echo scripts/screen/pdf-edit-flow.sh ;;
    *) return 1 ;;
    esac
}

record=0 build=1 chosen=()
for arg in "$@"; do
    case $arg in
    --record) record=1 ;;
    --no-build) build=0 ;;
    -*) sed -n '2,10s/^# \{0,1\}//p' "$0"; exit 2 ;;
    *) script "$arg" >/dev/null || { echo "no flow “$arg”; the flows are: ${all[*]}"; exit 2; }; chosen+=("$arg") ;;
    esac
done
[ ${#chosen[@]} -gt 0 ] || chosen=("${all[@]}")

if [ $build = 1 ]; then
    echo "building…"
    scripts/build.sh >/dev/null || { echo "the build failed; see build/build.log"; exit 2; }
fi

RUN="$PWD/build/evidence/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN"
export SCREEN_RUN="$RUN" SCREEN_RECORD=$record
summary="$RUN/summary.txt"
printf '%-10s %4s %5s\n' flow ok FAIL > "$summary"
status=0
for flow in "${chosen[@]}"; do
    echo "running ${flow}…"
    mkdir -p "$RUN/$flow"
    "$(script "$flow")" > "$RUN/$flow/output.txt" 2>&1
    code=$?
    ok=$(grep -c '^ok' "$RUN/$flow/output.txt")
    failed=$(grep -c '^FAIL' "$RUN/$flow/output.txt")
    note=
    # A flow that stopped without failing a check (a guard, a broken script) didn't test anything after that point.
    if [ "$code" -ne 0 ] && [ "$failed" -eq 0 ]; then note="  didn't finish: $(grep -v '^ok' "$RUN/$flow/output.txt" | tail -1)"; fi
    [ "$code" -eq 0 ] && [ "$failed" -eq 0 ] || status=1
    printf '%-10s %4s %5s%s\n' "$flow" "$ok" "$failed" "$note" >> "$summary"
done

echo
cat "$summary"
grep -h '^FAIL' "$RUN"/*/output.txt
echo "evidence in $RUN"
exit $status
