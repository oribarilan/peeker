#!/usr/bin/env python3
"""Preview++ process plugin: newline-delimited JSON on stdin/stdout, returns a declarative view tree."""
import csv
import json
import os
import sys

state = {"header": [], "rows": []}


def view():
    return {"type": "table", "columns": state["header"], "rows": state["rows"]}


def handle(method, params):
    if method == "open":
        with open(params["path"], newline="", encoding="utf-8") as f:
            rows = list(csv.reader(f))
        state["header"], state["rows"] = (rows[0], rows[1:]) if rows else ([], [])
        return {"view": view()}
    if method == "command" and params.get("id") == "sort":
        state["rows"].sort(key=lambda r: r[0] if r else "")
        return {"view": view()}
    if method == "command" and params.get("id") == "simulate-crash":
        os._exit(3)
    raise ValueError(f"unknown request {method} {params}")


for line in sys.stdin:
    request = json.loads(line)
    try:
        reply = {"id": request["id"], "result": handle(request["method"], request.get("params", {}))}
    except Exception as error:  # report to the host instead of dying
        reply = {"id": request["id"], "error": str(error)}
    sys.stdout.write(json.dumps(reply) + "\n")
    sys.stdout.flush()
