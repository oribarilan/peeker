---
name: publishing-benchmarks
description: Use when refreshing Peeker performance numbers in README.md or BENCHMARKS.md, after performance work lands, before a release, or when asked to "run the benchmark" or "update the numbers".
---

# Publishing benchmarks

`bench/ppbench.py` measures, checks and writes. This skill is the judgment around it: the numbers are public claims, so they come from a quiet reference Mac and get checked before they land.

## Before running

Read-only first: `git status --short`, `pgrep -lx 'Preview|TextEdit|Peeker'`, `pmset -g batt | head -1`, `echo "${CI-unset}"`. If `CI` is set, stop: published numbers never come from CI.

Then one message to the user, and wait:

1. **Apps it will close.** The run refuses to start while Preview or TextEdit is open and quits them, plus Peeker, between launches. Ask the user to save and quit them; never quit them yourself without a yes. (Launches use `open -F`, so their documents aren't reopened during the run.)
2. **Dirty tree.** Uncommitted changes are stamped `<sha>-dirty`. Offer: commit first (recommended, their call), or measure as-is and say so in the hand-back.
3. **Conditions.** About 15 minutes of flashing windows; the Mac should be idle and on power.

## Run and check

```sh
scripts/build.sh test && scripts/build.sh      # stop on failure
python3 bench/ppbench.py run                   # run in the background; writes bench/results/reference.json
python3 bench/ppbench.py check                 # missing or noisy metrics
```

If a previous reference is committed, also compare against it:

```sh
previous=$(mktemp) && git show HEAD:bench/results/reference.json > "$previous"
python3 bench/ppbench.py compare "$previous" bench/results/reference.json
```

| Result | Action |
|---|---|
| `check` reports missing metrics | Don't publish. Tell the user which launches failed. |
| `check` reports noisy metrics | Look for background load (`top -l 1 -o cpu | head`), then rerun the whole run and keep the rerun, even if it's worse. |
| `compare` shows regressions with no code change behind them | Treat as noise: same as above. |
| `compare` shows regressions from real changes | Tell the user before publishing them. |

## Publish and hand back

```sh
python3 bench/ppbench.py publish               # README highlights block + BENCHMARKS.md
git status --short README.md BENCHMARKS.md bench/results/
```

`publish` only rewrites the `bench:start`/`bench:end` block of README.md; read that block and BENCHMARKS.md once. Tell the user the highlights, anything `check` or `compare` flagged, the commit stamp, and that Preview can be reopened. Leave everything uncommitted; a commit (including `bench/results/reference.json`, the baseline for next time) needs their go-ahead.
