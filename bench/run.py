#!/usr/bin/env python3
"""Preview++ POC benchmarks. Writes bench/results/results.json and bench/results/results.md.

Prerequisites: both schemes built in Release into build/dd, `swift bench/make-fixtures.swift`,
and `swiftc -O bench/winwait.swift -o build/winwait`. Opens and closes real windows for a few minutes.
"""
import json
import os
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRODUCTS = ROOT / "build/dd/Build/Products/Release"
FIXTURES = ROOT / "bench/fixtures"
RESULTS = ROOT / "bench/results"
COMMUNITY = ROOT / "build/community"
WINWAIT = ROOT / "build/winwait"
RUNS = int(os.environ.get("RUNS", "5"))
APPS = {"bundled": "PreviewPP", "external": "PreviewPPLean"}


def binary(app):
    return PRODUCTS / f"{app}.app/Contents/MacOS/{app}"


def stage_community():
    """Community plugin folder: the CSV plugin in all three runtimes."""
    shutil.rmtree(COMMUNITY, ignore_errors=True)
    COMMUNITY.mkdir(parents=True)
    shutil.copytree(PRODUCTS / "PreviewPPLean.app/Contents/PlugIns/PPCSV.pppplugin", COMMUNITY / "PPCSV.pppplugin")
    for name in ("csv-web.pppweb", "csv-proc.pppproc"):
        shutil.copytree(ROOT / "ExternalPlugins" / name, COMMUNITY / name)


def in_app(app, file, config="", env=None, timeout=120):
    """One launch in bench mode. Returns the app's JSON record, or {"exit": code} if it wrote none."""
    with tempfile.TemporaryDirectory() as tmp:
        conf, out = Path(tmp, "config"), Path(tmp, "out.jsonl")
        conf.write_text(config)
        full_env = {**os.environ, "PPP_CONFIG": str(conf), "PPP_BENCH_OUT": str(out), "PPP_PLUGINS_DIR": str(COMMUNITY), **(env or {})}
        try:
            proc = subprocess.run([binary(app), FIXTURES / file], env=full_env, capture_output=True, timeout=timeout)
            code = proc.returncode
        except subprocess.TimeoutExpired:
            code = "timeout"
        if out.exists() and out.read_text().strip():
            return json.loads(out.read_text().strip().splitlines()[-1])
        return {"exit": code}


def median_of(runs, key):
    values = [r[key] for r in runs if key in r]
    return round(statistics.median(values), 1) if values else None


def content_matrix():
    files = ["small.txt", "medium.log", "large.log", "small.md", "large.md", "small.pdf", "large.pdf", "small.csv", "large.csv"]
    cases = [(variant, app, f, "", {}) for variant, app in APPS.items() for f in files]
    for plugin in ("csv@bundle", "csv-web", "csv-proc"):
        for f in ("small.csv", "large.csv"):
            cases.append((f"split:{plugin}", "PreviewPP", f, f"disable = csv\nopen.csv = {plugin}\n", {}))
    cases.append(("bundled+textkit1", "PreviewPP", "large.log", "", {"PPP_TEXTKIT1": "1"}))
    cases.append(("bundled+textkit1", "PreviewPP", "medium.log", "", {"PPP_TEXTKIT1": "1"}))

    rows = []
    for variant, app, f, config, env in cases:
        in_app(app, f, config, env)  # warm-up, discarded
        runs = [in_app(app, f, config, env) for _ in range(RUNS)]
        row = {
            "variant": variant, "file": f, "plugin": runs[-1].get("plugin"), "runtime": runs[-1].get("runtime"),
            "processToReadyMs": median_of(runs, "processToReadyMs"), "openToReadyMs": median_of(runs, "openToReadyMs"),
            "discoveryMs": median_of(runs, "discoveryMs"), "footprintMB": median_of(runs, "footprintMB"),
            "failures": [r for r in runs if "processToReadyMs" not in r],
        }
        print(json.dumps(row), flush=True)
        rows.append(row)
    return rows


def window_time(process_name, window_owner, app_path, file, timeout=120):
    subprocess.run(["pkill", "-x", process_name], capture_output=True)
    time.sleep(0.8)
    out = subprocess.run([WINWAIT, window_owner, app_path, FIXTURES / file, str(timeout)], capture_output=True, text=True).stdout.strip()
    time.sleep(0.3)
    subprocess.run(["pkill", "-x", process_name], capture_output=True)
    return None if out in ("", "timeout") else float(out)


def head_to_head():
    # (process name for pkill, window owner name as CGWindowList reports it, app path)
    ours = ("PreviewPP", "Preview++", str(PRODUCTS / "PreviewPP.app"))
    pairs = [
        (("Preview", "Preview", "/System/Applications/Preview.app"), ["small.pdf", "large.pdf"]),
        (("TextEdit", "TextEdit", "/System/Applications/TextEdit.app"), ["small.txt", "medium.log", "large.log", "small.md", "large.md"]),
    ]
    rows = []
    for theirs, files in pairs:
        for f in files:
            runs = max(3, RUNS) if "large" not in f else 3
            for target in (theirs, ours):
                label = target[1]
                window_time(*target, f)  # warm-up
                times = [t for t in (window_time(*target, f) for _ in range(runs)) if t is not None]
                row = {"app": label, "file": f, "windowMs": round(statistics.median(times), 1) if times else None, "runs": len(times)}
                print(json.dumps(row), flush=True)
                rows.append(row)
    return rows


def memory():
    """Resident memory of host plus any helper processes it spawned, 3 s after opening large.csv."""
    def snapshot():
        out = subprocess.run(["ps", "-axo", "pid=,rss=,comm="], capture_output=True, text=True).stdout
        return {int(p): (int(r), c) for p, r, c in (line.split(None, 2) for line in out.splitlines() if line.strip())}

    rows = []
    for plugin in ("csv", "csv@bundle", "csv-web", "csv-proc"):
        config = "" if plugin == "csv" else f"disable = csv\nopen.csv = {plugin}\n"
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "config").write_text(config)
            before = snapshot()
            env = {**os.environ, "PPP_CONFIG": str(Path(tmp, "config")), "PPP_PLUGINS_DIR": str(COMMUNITY)}
            proc = subprocess.Popen([binary("PreviewPP"), FIXTURES / "large.csv"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(3)
            after = snapshot()
            new = {pid: v for pid, v in after.items() if pid not in before}
            helpers = {pid: v for pid, v in new.items() if pid != proc.pid and any(k in v[1] for k in ("WebKit", "python", "Python"))}
            host_mb = after.get(proc.pid, (0, ""))[0] / 1024
            helper_mb = sum(r for r, _ in helpers.values()) / 1024
            proc.terminate()
            proc.wait()
        row = {"plugin": plugin, "hostMB": round(host_mb, 1), "helpersMB": round(helper_mb, 1),
               "helpers": sorted({Path(c).name for _, c in helpers.values()})}
        print(json.dumps(row), flush=True)
        rows.append(row)
    return rows


def isolation():
    cases = [
        ("csv", "", "simulate-crash"),
        ("csv@bundle", "disable = csv\nopen.csv = csv@bundle\n", "simulate-crash"),
        ("csv-proc", "disable = csv\nopen.csv = csv-proc\n", "simulate-crash"),
        ("csv-web", "disable = csv\nopen.csv = csv-web\n", "simulate-hang"),
    ]
    rows = []
    for plugin, config, command in cases:
        record = in_app("PreviewPP", "small.csv", config, {"PPP_BENCH_COMMAND": command}, timeout=20)
        survived = "exit" not in record
        row = {"plugin": plugin, "command": command, "hostSurvived": survived,
               "detail": record.get("failure") or record.get("note") or f"host exited with {record.get('exit')}"}
        print(json.dumps(row), flush=True)
        rows.append(row)
    return rows


def sizes():
    def du(path):
        return int(subprocess.run(["du", "-sk", path], capture_output=True, text=True).stdout.split()[0]) / 1024
    rows = {f"{app}.app": round(du(PRODUCTS / f"{app}.app"), 2) for app in APPS.values()}
    for item in sorted((PRODUCTS / "PreviewPPLean.app/Contents/PlugIns").iterdir()):
        rows[item.name] = round(du(item), 2)
    rows["PreviewPPKit.framework"] = round(du(PRODUCTS / "PreviewPP.app/Contents/Frameworks/PreviewPPKit.framework"), 2)
    print(json.dumps(rows), flush=True)
    return rows


def write_markdown(results):
    lines = ["# Benchmark results", "", f"Machine: {results['machine']}. Median of {RUNS} runs after one warm-up unless noted.", ""]
    lines += ["## Time to content (in-app, direct launch)", "",
              "| variant | file | plugin | runtime | process start to ready (ms) | open to ready (ms) | discovery (ms) | footprint (MB) |",
              "|---|---|---|---|---|---|---|---|"]
    for r in results["content"]:
        lines.append(f"| {r['variant']} | {r['file']} | {r['plugin']} | {r['runtime']} | {r['processToReadyMs']} | {r['openToReadyMs']} | {r['discoveryMs']} | {r['footprintMB']} |")
    lines += ["", "## Head to head: launch to first document window (LaunchServices `open -F`)", "", "| file | app | window (ms) | runs |", "|---|---|---|---|"]
    for r in results["headToHead"]:
        lines.append(f"| {r['file']} | {r['app']} | {r['windowMs']} | {r['runs']} |")
    lines += ["", "## Memory with large.csv open (RSS, 3 s after launch)", "", "| plugin | host (MB) | helpers (MB) | helper processes |", "|---|---|---|---|"]
    for r in results["memory"]:
        lines.append(f"| {r['plugin']} | {r['hostMB']} | {r['helpersMB']} | {', '.join(r['helpers']) or '-'} |")
    lines += ["", "## Crash and hang isolation", "", "| plugin | command | host survived | detail |", "|---|---|---|---|"]
    for r in results["isolation"]:
        lines.append(f"| {r['plugin']} | {r['command']} | {'yes' if r['hostSurvived'] else 'no'} | {r['detail']} |")
    lines += ["", "## Sizes (MB on disk)", "", "| item | MB |", "|---|---|"]
    lines += [f"| {k} | {v} |" for k, v in results["sizes"].items()]
    (RESULTS / "results.md").write_text("\n".join(lines) + "\n")


def main():
    for app in ("Preview", "TextEdit"):
        if subprocess.run(["pgrep", "-x", app], capture_output=True).returncode == 0:
            sys.exit(f"{app} is running. Quit it first; the head-to-head benchmark force-quits it between runs.")
    RESULTS.mkdir(parents=True, exist_ok=True)
    stage_community()
    machine = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"], capture_output=True, text=True).stdout.strip()
    macos = subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip()
    sections = sys.argv[1:] or ["content", "headToHead", "memory", "isolation", "sizes"]
    path = RESULTS / "results.json"
    results = json.loads(path.read_text()) if path.exists() else {}
    results["machine"] = f"{machine}, macOS {macos}"
    steps = {"content": content_matrix, "headToHead": head_to_head, "memory": memory, "isolation": isolation, "sizes": sizes}
    for name in sections:
        print(f"== {name}", flush=True)
        results[name] = steps[name]()
        path.write_text(json.dumps(results, indent=2))
    if all(k in results for k in steps):
        write_markdown(results)


if __name__ == "__main__":
    main()
