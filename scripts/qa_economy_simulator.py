#!/usr/bin/env python3
"""Capture DEBUG economy fixtures on an existing Simulator; preserve player prefs."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--device", required=True, help="Existing booted Simulator UUID")
parser.add_argument("--display", default="primary", help="Active screen name or ID (Duo closed screen: primary)")
parser.add_argument("--app", type=Path, help="Built Debug .app to install")
parser.add_argument("--output", type=Path, default=Path("build/endless-qa"))
args = parser.parse_args()
bundle = "com.lxygame.gummydrop.prototype"
env = dict(os.environ, DEVELOPER_DIR=os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"))

def sim(*command):
    result = subprocess.run(["xcrun", "simctl", *map(str, command)], env=env, text=True, capture_output=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f"simctl {command[0]} exited {result.returncode}: {result.stderr.strip()}")
    return result.stdout.strip()

if args.app:
    sim("install", args.device, args.app.resolve())
container = Path(sim("get_app_container", args.device, bundle, "data"))
prefs_path = container / "Library/Preferences" / f"{bundle}.plist"

def prefs():
    return plistlib.loads(prefs_path.read_bytes()) if prefs_path.exists() else {}

before = prefs()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
results = []
failure = None
try:
    for variant in ("flow", "shop", "supply", "buffs", "cut", "rescue"):
        log = output / f"{variant}.log"
        # Console forwarding works on iOS 27.1; host-file redirection can fail to launch.
        with log.open("w") as stream:
            process = subprocess.Popen(["xcrun", "simctl", "launch", "--console", "--terminate-running-process", args.device, bundle, "-qa-economy", variant], env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                marker = "QA economy PASS:" if variant == "flow" else f"QA economy READY: {variant}"
                deadline = time.monotonic() + 40
                while marker not in log.read_text(errors="replace"):
                    if process.poll() is not None:
                        raise RuntimeError(f"{variant}: launch exited {process.returncode}; inspect {log}")
                    if time.monotonic() >= deadline:
                        raise RuntimeError(f"{variant}: readiness marker missing; inspect {log}")
                    time.sleep(0.25)
                time.sleep(0.8)  # Allow SpriteKit to render after setup.
                sim("io", args.device, "screenshot", f"--display={args.display}", output / f"{variant}.png")
            finally:
                if process.poll() is None:
                    sim("terminate", args.device, bundle)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.terminate()
                        process.wait(timeout=10)
        results.append({"variant": variant, "ready": True, "screenshot": f"{variant}.png"})
        print(f"PASS: {variant}", flush=True)
except Exception as error:
    failure = str(error)
finally:
    try:
        sim("launch", "--terminate-running-process", args.device, bundle)
    except Exception as error:
        failure = f"{failure + '; ' if failure else ''}return to Home: {error}"

after = prefs()
changed = sorted(key for key in set(before) | set(after) if before.get(key) != after.get(key))
report = {"device": args.device, "captureDisplay": args.display, "bundle": bundle, "variants": results, "failure": failure, "preferencesUnchanged": not changed, "changedKeys": changed,
          "scope": "DEBUG scene controls and render fixtures; not synthetic or manual touch input"}
(output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
if changed:
    raise RuntimeError(f"Player preference keys changed: {changed}")
if failure:
    raise RuntimeError(failure)
print("PASS: player preferences and saves unchanged; returned to normal Home", flush=True)
