#!/usr/bin/env bash
# Reimport every asset headlessly and fail if Godot logged a single error.
# A broken .tscn or .import only surfaces at import time, which a plain test
# run happily skips over, so this runs as its own gate.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/godot}"
LOG_FILE="${REPO_ROOT}/.tools/import.log"

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "godot binary not found at ${GODOT_BIN}; run tools/get_godot.sh first" >&2
	exit 1
fi

mkdir -p "$(dirname "${LOG_FILE}")"

set +e
"${GODOT_BIN}" --headless --import --path "${REPO_ROOT}" >"${LOG_FILE}" 2>&1
IMPORT_STATUS=$?
set -e

# Godot colourises output even when redirected, so strip escapes before matching.
ERROR_COUNT="$(sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' "${LOG_FILE}" \
	| grep -E -c '(^|[[:space:]])(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR):' || true)"

echo "import exit status: ${IMPORT_STATUS}"
echo "import error lines: ${ERROR_COUNT}"

if [[ "${ERROR_COUNT}" -ne 0 ]]; then
	echo "--- offending lines ---" >&2
	sed -r 's/\x1B\[[0-9;]*[A-Za-z]//g' "${LOG_FILE}" \
		| grep -E -n '(^|[[:space:]])(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR):' >&2
	exit 1
fi

if [[ "${IMPORT_STATUS}" -ne 0 ]]; then
	echo "godot --import exited non-zero" >&2
	exit "${IMPORT_STATUS}"
fi

echo "import clean"
