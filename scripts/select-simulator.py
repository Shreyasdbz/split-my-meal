#!/usr/bin/env python3
"""Select an available iOS simulator by explicit UDID, OS and device family.

Print a JSON record with its name, runtime and UDID; fail instead of choosing a
runtime that disagrees with an explicit request. No simulator data is modified.
"""
import json
import os
import subprocess
import sys

inventory = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))
requested_id = os.environ.get("SIMULATOR_UDID")
requested_os = os.environ.get("SIMULATOR_OS")
family = os.environ.get("SIMULATOR_FAMILY", "iPhone")
if family not in {"iPhone", "iPad"}:
    sys.exit("SIMULATOR_FAMILY must be iPhone or iPad.")
candidates = []
for runtime, devices in inventory["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = runtime.split(".iOS-", 1)[1].replace("-", ".")
    for device in devices:
        if not device.get("isAvailable", False):
            continue
        if requested_id:
            if device["udid"] != requested_id:
                continue
        elif not device["name"].startswith(family):
            continue
        if requested_os and version != requested_os:
            continue
        candidates.append({"udid": device["udid"], "name": device["name"], "os": version, "runtime": runtime})
if not candidates:
    sys.exit("No available iOS simulator matches the request. Install the requested runtime in Xcode, or set SIMULATOR_OS / SIMULATOR_UDID to an installed simulator.")
# Prefer the highest installed OS; ties use a stable device name and UDID.
candidates.sort(key=lambda d: (tuple(-int(n) for n in d["os"].split(".")), d["name"], d["udid"]))
print(json.dumps(candidates[0]))
