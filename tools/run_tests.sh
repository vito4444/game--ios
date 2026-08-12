#!/usr/bin/env bash
# Run the GUT suite headlessly. Extra arguments are forwarded to gut_cmdln.gd,
# e.g. tools/run_tests.sh -gunit_test_name=test_oxygen
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/godot}"

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "godot binary not found at ${GODOT_BIN}; run tools/get_godot.sh first" >&2
	exit 1
fi

"${GODOT_BIN}" --headless --path "${REPO_ROOT}" \
	-s addons/gut/gut_cmdln.gd \
	-gdir=res://tests/unit \
	-ginclude_subdirs \
	-gexit \
	"$@"
