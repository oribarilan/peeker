#!/usr/bin/env python3
"""Peeker benchmark: README numbers on a reference Mac, regression gate in CI.

    bench/ppbench.py run [--suite inapp,launch,apple] [--files a.md,b.pdf] [--launches 5] [--out FILE]
    bench/ppbench.py ab --base APP --head APP [--suite inapp,launch] [--launches 7]   exit 1 on regressions
    bench/ppbench.py compare BASE.json HEAD.json                                         exit 1 on regressions
    bench/ppbench.py check [RESULTS.json]                                                missing or noisy metrics
    bench/ppbench.py publish [RESULTS.json]                                              README highlights + BENCHMARKS.md

Suites (all open real windows; nothing needs extra permissions):
    inapp   inside the app, per file, in the quick-look panel and a window: warm open, open with a cold plugin
            process, plugin startup cost, plugin memory
    launch  from `open` (app not running) until the content is drawn
    apple   Preview / TextEdit launch-to-window, for the README only (quits those apps between runs)

A file the base build can't open (a format it has no plugin for) shows in `ab` and `compare` as new, not compared.
A metric the base has and head lacks (head failed to open the file) counts as a regression.

Gate: a metric regresses when head is both more than 15% and more than 10 ms (5 MB for memory) worse than base.
Only Peeker's own measured metrics are gated; derived plugin_startup is reported, not gated. Standard library only.
"""
import argparse
import datetime
import json
import os
import platform
import re
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "bench/fixtures"
TOOLS = ROOT / "build/bench-tools"
DEFAULT_APP = ROOT / "build/dd/Build/Products/Release/Peeker.app"
REFERENCE = ROOT / "bench/results/reference.json"
FILES = ["small.md", "large.md", "small.pdf", "large.pdf", "small.png", "photo.jpg", "photo.heic", "large.png", "small.txt", "medium.log", "large.log"]
TEXTEDIT = ("TextEdit", "/System/Applications/TextEdit.app")
APPLE = {"md": TEXTEDIT, "txt": TEXTEDIT, "log": TEXTEDIT}
APPLE_DEFAULT = ("Preview", "/System/Applications/Preview.app")
GATE_PCT = 0.15
GATE_FLOOR = {"ms": 10.0, "MB": 5.0}
SCHEMA = 1
# No hotkey during benchmarks, so no Accessibility prompt appears.
CONFIG = Path(tempfile.gettempdir()) / "ppbench-config"


# MARK: Setup

def ensure_tools():
    """Compiles the fixture generator and window probe on first use; generates fixtures if missing."""
    TOOLS.mkdir(parents=True, exist_ok=True)
    for name in ("make-fixtures", "winwait"):
        binary, source = TOOLS / name, ROOT / f"bench/{name}.swift"
        if not binary.exists() or binary.stat().st_mtime < source.stat().st_mtime:
            subprocess.run(["swiftc", "-O", str(source), "-o", str(binary)], check=True)
    if not all((FIXTURES / f).exists() for f in FILES):
        subprocess.run([str(TOOLS / "make-fixtures")], cwd=ROOT, check=True)
    CONFIG.write_text("quicklook.key = off\n")


def apple_app(file):
    return APPLE.get(file.rsplit(".", 1)[-1], APPLE_DEFAULT)


def refuse_if_running(*apps):
    for app in apps:
        if subprocess.run(["pgrep", "-x", app], capture_output=True).returncode == 0:
            sys.exit(f"{app} is running. Quit it first; this suite force-quits it between runs.")


# MARK: Samples (one launch each)

def sample_inapp(app, file, mode):
    """One launch opening `file` three times: cold app, warm, then warm app with the plugin process stopped first."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp, "out.jsonl")
        env = {**os.environ, "PEEKER_CONFIG": str(CONFIG), "PEEKER_BENCH_OUT": str(out), "PEEKER_BENCH_MODE": mode, "PEEKER_BENCH_REPEAT": "3"}
        try:
            subprocess.run([str(Path(app) / "Contents/MacOS/Peeker"), str(FIXTURES / file)], env=env, capture_output=True, timeout=60)
        except subprocess.TimeoutExpired:
            return {}
        runs = {r.get("run"): r for r in map(json.loads, out.read_text().splitlines())} if out.exists() else {}
    if not {1, 2} <= runs.keys() or any("failure" in r for r in runs.values()):
        return {}
    warm, cold = runs[1], runs[2]
    key = f"inapp.{mode}.{file}"
    return {
        f"{key}.warm_open": ("ms", warm["openToReadyMs"]),
        f"{key}.cold_plugin_open": ("ms", cold["openToReadyMs"]),
        f"{key}.plugin_startup": ("ms", round(cold["replyMs"] - warm["replyMs"], 1)),
        f"{key}.plugin_memory": ("MB", round(warm["pluginFootprintMB"], 1)),
    }


def sample_launch(app, file):
    """From the `open` command until Peeker has drawn the content (it writes its record after drawing)."""
    subprocess.run(["pkill", "-x", "Peeker"], capture_output=True)
    time.sleep(0.8)
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp, "out.jsonl")
        start = time.perf_counter()
        subprocess.run(["open", "-F", "--env", f"PEEKER_CONFIG={CONFIG}", "--env", f"PEEKER_BENCH_OUT={out}", "--env", "PEEKER_BENCH_MODE=window",
                        "-a", str(Path(app).resolve()), str(FIXTURES / file)])
        while not (out.exists() and out.read_text().strip()) and time.perf_counter() - start < 20:
            time.sleep(0.001)
        ok = out.exists() and "failure" not in out.read_text()
        elapsed = (time.perf_counter() - start) * 1000
    subprocess.run(["pkill", "-x", "Peeker"], capture_output=True)
    return {f"launch.{file}.content": ("ms", round(elapsed, 1))} if ok else {}


def sample_apple(file):
    """Apple's app from `open` until its window appears (its content may come later)."""
    name, path = apple_app(file)
    subprocess.run(["pkill", "-x", name], capture_output=True)
    time.sleep(0.8)
    out = subprocess.run([str(TOOLS / "winwait"), name, path, str(FIXTURES / file), "60"], capture_output=True, text=True).stdout.strip()
    time.sleep(0.3)
    subprocess.run(["pkill", "-x", name], capture_output=True)
    return {} if out in ("", "timeout") else {f"apple.{file}.{name.lower()}_window": ("ms", float(out))}


def cases(suites, files):
    """(label, sampler) pairs; each sampler takes an app path and returns {metric: (unit, value)} for one launch."""
    out = []
    for file in files:
        if "inapp" in suites:
            for mode in ("panel", "window"):
                out.append((f"inapp {mode} {file}", lambda app, f=file, m=mode: sample_inapp(app, f, m)))
        if "launch" in suites:
            out.append((f"launch {file}", lambda app, f=file: sample_launch(app, f)))
        if "apple" in suites:
            out.append((f"apple {file}", lambda app, f=file: sample_apple(f)))
    return out


# MARK: Collection

def collect(apps, suites, files, launches):
    """Runs every case `launches` times per app after a warm-up. With two apps, launches alternate between them in
    flipping order, so drift on a shared CI machine hits base and head equally."""
    results = {name: {} for name in apps}
    for label, sampler in cases(suites, files):
        print(f"  {label}", file=sys.stderr, flush=True)
        for app in apps.values():
            sampler(app)  # warm-up, discarded
        for i in range(launches):
            order = list(apps.items()) if i % 2 == 0 else list(reversed(apps.items()))
            for name, app in order:
                for metric, (unit, value) in sampler(app).items():
                    results[name].setdefault(metric, {"unit": unit, "samples": []})["samples"].append(value)
    return results


def document(metrics, app, launches):
    for metric in metrics.values():
        metric["median"] = round(statistics.median(metric["samples"]), 1)
    chip = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True, text=True).stdout.strip()
    commit = subprocess.run(["git", "-C", str(Path(app).resolve().parents[5]), "describe", "--always", "--dirty"],
                            capture_output=True, text=True).stdout.strip()
    return {
        "schema": SCHEMA,
        "date": datetime.date.today().isoformat(),
        "commit": commit or None,
        "machine": f"{chip}, macOS {platform.mac_ver()[0]}",
        "ci": bool(os.environ.get("CI")),
        "launches": launches,
        "metrics": dict(sorted(metrics.items())),
    }


# MARK: Gate

def gated(metric_id):
    # plugin_startup is cold minus warm reply time, two noisy samples whose difference flips sign; cold_plugin_open stays gated.
    return not metric_id.startswith("apple.") and not metric_id.endswith(".plugin_startup")


def compare(base, head):
    """Returns (markdown table, regression count)."""
    rows, regressions = [], 0
    for metric_id in sorted(set(base["metrics"]) | set(head["metrics"])):
        b, h = base["metrics"].get(metric_id), head["metrics"].get(metric_id)
        if not h:
            # Head stopped producing it, such as a fixture it no longer opens: that's a failure, not a skip.
            rows.append(f"| `{metric_id}` | {b['median']} {b['unit']} | – | | {'**missing in head**' if gated(metric_id) else 'missing in head (not gated)'} |")
            regressions += gated(metric_id)
            continue
        if not b:
            rows.append(f"| `{metric_id}` | – | {h['median']} {h['unit']} | | new, not compared |")
            continue
        unit, delta = h["unit"], h["median"] - b["median"]
        pct = delta / b["median"] if b["median"] else 0
        worse = pct > GATE_PCT and delta > GATE_FLOOR[unit]
        better = -pct > GATE_PCT and -delta > GATE_FLOOR[unit]
        status = "**regression**" if worse and gated(metric_id) else "slower (not gated)" if worse else "faster" if better else ""
        regressions += worse and gated(metric_id)
        rows.append(f"| `{metric_id}` | {b['median']} {unit} | {h['median']} {unit} | {delta:+.1f} ({pct:+.0%}) | {status} |")
    header = [f"Base `{base.get('commit')}` vs head `{head.get('commit')}` on {head['machine']}, "
              f"{head['launches']} interleaved launches each. Gate: worse by more than {GATE_PCT:.0%} and "
              f"{GATE_FLOOR['ms']:g} ms / {GATE_FLOOR['MB']:g} MB.", "",
              "| metric | base | head | change | |", "|---|---|---|---|---|"]
    verdict = f"\n**{regressions} regression(s).**" if regressions else "\nNo regressions."
    return "\n".join(header + rows) + "\n" + verdict + "\n", regressions


def report(markdown):
    print(markdown)
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(summary, "a") as handle:
            handle.write("## Peeker benchmark\n\n" + markdown)


# MARK: Publishing

# README rows are fixed in advance, not picked by result, so the highlights can't cherry-pick wins.
HIGHLIGHTS = ["large.pdf", "photo.jpg", "large.png", "small.md"]
DESCRIPTIONS = {
    "small.md": "Markdown, 1 KB", "large.md": "Markdown, 844 KB", "small.pdf": "PDF, 3 pages", "large.pdf": "PDF, 2,000 pages",
    "small.png": "PNG, 512×512", "photo.jpg": "JPEG, 12 MP", "photo.heic": "HEIC, 12 MP", "large.png": "PNG, 48 MP",
    "small.txt": "Text, 10 KB", "medium.log": "Log, 11 MB", "large.log": "Log, 86 MB",
}


def medians(results):
    return {k: v["median"] for k, v in results["metrics"].items()}


def versus_apple(m, file):
    """(apple app name, apple window ms, peeker content ms, verdict) or None."""
    name = apple_app(file)[0]
    theirs, ours = m.get(f"apple.{file}.{name.lower()}_window"), m.get(f"launch.{file}.content")
    if not (theirs and ours):
        return None
    ratio = theirs / ours
    # Within 10% is noise on a single machine, not a win or a loss.
    verdict = "about the same" if 1 / 1.1 < ratio < 1.1 else f"{ratio:.1f}× faster" if ratio > 1 else f"{1 / ratio:.1f}× slower"
    return name, theirs, ours, verdict


def fmt(value, unit="ms"):
    return "–" if value is None else f"{value:.0f} {unit}" if unit == "ms" else f"{value:.1f} {unit}"


def readme_highlights(results):
    m = medians(results)
    lines = ["| Opening, app not running | Apple | Peeker | |", "|---|---|---|---|"]
    for file in HIGHLIGHTS:
        if row := versus_apple(m, file):
            name, theirs, ours, verdict = row
            lines.append(f"| {DESCRIPTIONS[file]} | {name} {theirs:.0f} ms | {ours:.0f} ms | {verdict if verdict == 'about the same' else f'**{verdict}**'} |")
    pdf, photo = m.get("inapp.panel.small.pdf.warm_open"), m.get("inapp.panel.photo.jpg.warm_open")
    if pdf and photo:
        lines += ["", f"Space in Finder shows a PDF in {pdf:.0f} ms and a 12 MP photo in {photo:.0f} ms, with every format "
                      "running in its own plugin process."]
    lines += ["", f"{results['machine']}, {results['date']}. Apple's apps are timed until their window appears, Peeker "
                  "until its content is drawn. Every file, method and caveat: [BENCHMARKS.md](BENCHMARKS.md)."]
    return "\n".join(lines)


def benchmarks_page(results):
    m = medians(results)
    out = [
        "# Benchmarks", "",
        "<!-- Generated by `bench/ppbench.py publish` from bench/results/reference.json. Don't edit by hand. -->", "",
        f"Measured on {results['machine']} on {results['date']} at commit `{results['commit']}`. Each number is the median "
        f"of {results['launches']} launches after a warm-up launch.", "",
        "## Opening a file with the app not running", "",
        "From the `open` command. Apple's app is timed until its window appears; its content may arrive later. Peeker is "
        "timed until its content is drawn. Both are warm launches (not the first after a reboot).", "",
        "| File | Apple's app | Apple: window | Peeker: content | |", "|---|---|---|---|---|",
    ]
    for file in FILES:
        if row := versus_apple(m, file):
            name, theirs, ours, verdict = row
            out.append(f"| {DESCRIPTIONS[file]} | {name} | {theirs:.0f} ms | {ours:.0f} ms | {verdict} |")
    for mode, title, intro in (
        ("panel", "Quick look panel (Space in Finder)", "The app is running. *Plugin running*: its process is already up. "
         "*Plugin started on demand*: the process was stopped first, as after a minute idle."),
        ("window", "Document window", "The app is running; the file opens in a new window."),
    ):
        out += ["", f"## {title}", "", intro, "", "| File | Plugin running | Plugin started on demand |", "|---|---|---|"]
        for file in FILES:
            out.append(f"| {DESCRIPTIONS[file]} | {fmt(m.get(f'inapp.{mode}.{file}.warm_open'))} | "
                       f"{fmt(m.get(f'inapp.{mode}.{file}.cold_plugin_open'))} |")
    out += ["", "## Plugin processes", "",
            "*Startup cost*: how much longer the plugin's reply takes when its process has to start first. "
            "*Memory*: the plugin process's footprint with the file open.", "",
            "| File | Startup cost | Memory |", "|---|---|---|"]
    for file in FILES:
        out.append(f"| {DESCRIPTIONS[file]} | {fmt(m.get(f'inapp.panel.{file}.plugin_startup'))} | "
                   f"{fmt(m.get(f'inapp.panel.{file}.plugin_memory'), 'MB')} |")
    out += ["", "## Caveats", "",
            "- One machine, warm launches. Cold launches after a reboot are slower for every app.",
            "- Apple's content-drawn time isn't measured (it needs screen recording), so the gap to Apple is likely larger than shown.",
            "- TextEdit shows Markdown as raw text; Peeker renders it.",
            "- Plugin memory varies between runs by up to 2× for large files; it isn't a precise number.",
            "", "## Reproducing", "",
            "Quit Preview and TextEdit, then `scripts/build.sh && bench/ppbench.py run && bench/ppbench.py publish`. "
            "Raw samples are in `bench/results/reference.json`.", ""]
    return "\n".join(out)


def missing_metrics(results):
    needed = [f"launch.{f}.content" for f in FILES] + [f"apple.{f}.{apple_app(f)[0].lower()}_window" for f in FILES]
    needed += [f"inapp.{mode}.{f}.warm_open" for f in FILES for mode in ("panel", "window")]
    return [metric for metric in needed if metric not in results["metrics"]]


def noisy_metrics(results):
    """Published timing metrics where at least two launches ran over 1.3× the median and 15 ms above it. One outlier
    is fine (the median absorbs it); a cluster means background load skewed the run. Derived metrics (startup cost,
    cold-plugin opens) and memory vary by nature and aren't checked."""
    out = []
    for metric_id, metric in results["metrics"].items():
        if not (metric_id.startswith(("launch.", "apple.")) or metric_id.endswith(".warm_open")):
            continue
        median, samples = metric["median"], metric["samples"]
        slow = [x for x in samples if x > 1.3 * median and x - median > 15]
        if len(slow) >= 2:
            out.append(f"{metric_id}: median {median:.0f} ms, slow launches {', '.join(f'{x:.0f}' for x in slow)}")
    return out


def check(results):
    """Prints problems; returns False if the results must not be published."""
    ok = True
    if results.get("ci"):
        print("CI results: publish only from a reference Mac")
        ok = False
    if missing := missing_metrics(results):
        print("missing (a launch failed or timed out):\n  " + "\n  ".join(missing))
        ok = False
    if noisy := noisy_metrics(results):
        print("noisy (look for background load, then rerun the whole run):\n  " + "\n  ".join(noisy))
    if ok and not noisy:
        print(f"complete and stable: {len(results['metrics'])} metrics, commit {results.get('commit')}")
    return ok


def publish(results, readme, page):
    if results.get("ci"):
        sys.exit("refusing to publish CI numbers; run on a reference Mac")
    if missing := missing_metrics(results):
        sys.exit(f"refusing to publish partial results; missing {', '.join(missing)}")
    text = readme.read_text()
    start, end = "<!-- bench:start -->", "<!-- bench:end -->"
    if start not in text or end not in text:
        sys.exit(f"{readme} needs {start} and {end} markers")
    readme.write_text(re.sub(f"{start}.*?{end}", lambda _: f"{start}\n{readme_highlights(results)}\n{end}", text, flags=re.S))
    page.write_text(benchmarks_page(results))


# MARK: CLI

def main():
    parser = argparse.ArgumentParser(description="Peeker benchmark", formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    run = sub.add_parser("run", help="measure one build")
    run.add_argument("--app", default=str(DEFAULT_APP))
    run.add_argument("--suite", default="inapp,launch,apple")
    run.add_argument("--files", default=",".join(FILES), help="comma-separated subset of the fixtures")
    run.add_argument("--launches", type=int, default=5)
    run.add_argument("--out", default=str(REFERENCE))
    ab = sub.add_parser("ab", help="measure base and head interleaved, then gate")
    ab.add_argument("--base", required=True)
    ab.add_argument("--head", required=True)
    ab.add_argument("--suite", default="inapp,launch")
    ab.add_argument("--launches", type=int, default=7)
    ab.add_argument("--out-dir", default=str(ROOT / "build/bench-ab"))
    cmp = sub.add_parser("compare", help="gate HEAD against BASE")
    cmp.add_argument("base")
    cmp.add_argument("head")
    chk = sub.add_parser("check", help="report missing or noisy metrics")
    chk.add_argument("results", nargs="?", default=str(REFERENCE))
    pub = sub.add_parser("publish", help="write README highlights and BENCHMARKS.md from results")
    pub.add_argument("results", nargs="?", default=str(REFERENCE))
    args = parser.parse_args()

    if args.command == "compare":
        markdown, regressions = compare(json.loads(Path(args.base).read_text()), json.loads(Path(args.head).read_text()))
        report(markdown)
        sys.exit(1 if regressions else 0)
    if args.command == "check":
        sys.exit(0 if check(json.loads(Path(args.results).read_text())) else 1)
    if args.command == "publish":
        publish(json.loads(Path(args.results).read_text()), ROOT / "README.md", ROOT / "BENCHMARKS.md")
        print("updated README.md and BENCHMARKS.md")
        return

    suites = set(args.suite.split(","))
    files = args.files.split(",") if args.command == "run" else FILES
    if unknown := [f for f in files if f not in FILES]:
        sys.exit(f"unknown files: {', '.join(unknown)}; choose from {', '.join(FILES)}")
    if args.command == "run" and set(files) != set(FILES) and Path(args.out).resolve() == REFERENCE.resolve():
        sys.exit("a --files subset would overwrite the reference results; pass --out")
    if "apple" in suites:
        refuse_if_running("Preview", "TextEdit")
    ensure_tools()
    if args.command == "run":
        results = document(collect({"head": args.app}, suites, files, args.launches)["head"], args.app, args.launches)
        Path(args.out).parent.mkdir(parents=True, exist_ok=True)
        Path(args.out).write_text(json.dumps(results, indent=2) + "\n")
        print(f"wrote {args.out}")
    else:
        collected = collect({"base": args.base, "head": args.head}, suites, files, args.launches)
        out = Path(args.out_dir)
        out.mkdir(parents=True, exist_ok=True)
        docs = {name: document(collected[name], app, args.launches) for name, app in (("base", args.base), ("head", args.head))}
        for name, doc in docs.items():
            (out / f"{name}.json").write_text(json.dumps(doc, indent=2) + "\n")
        markdown, regressions = compare(docs["base"], docs["head"])
        report(markdown)
        sys.exit(1 if regressions else 0)


if __name__ == "__main__":
    main()
