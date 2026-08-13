#!/usr/bin/env bash
# Export the game for Linux and run the packaged build's self-test.
#
# The unit suite runs against the source tree, where every file exists by
# definition. An export only packs what the export filter matches, and a file
# it drops causes nothing to fail until the game is on a device. This exports,
# runs the result, and fails if the packaged game cannot find its own data.
#
# It caught exactly that: data/maps/*.map is not a format Godot recognises as a
# resource, so "all_resources" left the rig layout out of every build.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/godot}"
OUTPUT="${REPO_ROOT}/build/linux/DeepContract.x86_64"

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "godot binary not found at ${GODOT_BIN}; run tools/get_godot.sh --templates first" >&2
	exit 1
fi

mkdir -p "$(dirname "${OUTPUT}")"
"${GODOT_BIN}" --headless --path "${REPO_ROOT}" --export-release "Linux" "${OUTPUT}"

if [[ ! -x "${OUTPUT}" ]]; then
	echo "export did not produce ${OUTPUT}" >&2
	exit 1
fi

echo "--- running the packaged build's self-test ---"
DEEPCONTRACT_SELFTEST=1 "${OUTPUT}" --headless 2>&1 | grep -E "^\[selftest\]" || true

# The pipeline above swallows the status, so run it once more for the verdict.
if DEEPCONTRACT_SELFTEST=1 "${OUTPUT}" --headless > /dev/null 2>&1; then
	echo "packaged build is complete"
else
	echo "the packaged build is missing data - see the self-test output above" >&2
	exit 1
fi
