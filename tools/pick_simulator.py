#!/usr/bin/env python3
"""Choose a simulator to run the game on, newest iPhone first.

The hosted runner images rotate which iOS runtimes they carry, so naming a
device in the workflow means the workflow breaks every time the image changes.
This asks the machine what it has instead.

    xcrun simctl list devices available --json | tools/pick_simulator.py
    xcrun simctl list devices available --json | tools/pick_simulator.py --kind iPad

Prints "<udid>\t<name>\t<runtime>" and exits non-zero if nothing matches.
"""

from __future__ import annotations

import argparse
import json
import re
import sys

RUNTIME_PATTERN = re.compile(r"iOS-([0-9]+)(?:-([0-9]+))?")

# Newer hardware first when two devices share a runtime. Anything unlisted
# sorts below these but is still usable.
PREFERRED_ORDER = (
    "iPhone 17 Pro Max",
    "iPhone 17 Pro",
    "iPhone 17",
    "iPhone Air",
    "iPhone 16 Pro Max",
    "iPhone 16 Pro",
    "iPhone 16",
    "iPad Pro 13-inch",
    "iPad Pro 11-inch",
    "iPad Air 13-inch",
    "iPad Air 11-inch",
)


def runtime_version(identifier: str) -> tuple[int, int]:
    match = RUNTIME_PATTERN.search(identifier)
    if match is None:
        return (0, 0)
    return (int(match.group(1)), int(match.group(2) or 0))


def device_rank(name: str) -> int:
    for index, preferred in enumerate(PREFERRED_ORDER):
        if name.startswith(preferred):
            return len(PREFERRED_ORDER) - index
    return 0


def choose(payload: dict, kind: str) -> tuple[str, str, str] | None:
    best: tuple[tuple[int, int], int, str, str, str] | None = None
    for runtime, devices in payload.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        version = runtime_version(runtime)
        for device in devices:
            name = device.get("name", "")
            if not device.get("isAvailable") or not name.startswith(kind):
                continue
            candidate = (version, device_rank(name), name, device["udid"], runtime)
            if best is None or candidate[:3] > best[:3]:
                best = candidate
    if best is None:
        return None
    return best[3], best[2], best[4]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", default="iPhone", help="device family prefix, e.g. iPad")
    args = parser.parse_args()

    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        print(f"could not parse simctl output: {error}", file=sys.stderr)
        return 2

    chosen = choose(payload, args.kind)
    if chosen is None:
        print(f"no available {args.kind} simulator", file=sys.stderr)
        return 1

    print("\t".join(chosen))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
