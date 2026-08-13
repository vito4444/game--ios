#!/usr/bin/env bash
# Export the browser build. Not a shipping target: it exists so gameplay can be
# played and reviewed from a pull request without a device or an Apple account.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/godot}"
OUTPUT_DIR="${REPO_ROOT}/build/web"

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "godot binary not found at ${GODOT_BIN}; run tools/get_godot.sh first" >&2
	exit 1
fi

mkdir -p "${OUTPUT_DIR}"
"${GODOT_BIN}" --headless --path "${REPO_ROOT}" --export-release "Web" "${OUTPUT_DIR}/index.html"

for required in index.html index.js index.wasm index.pck; do
	if [[ ! -s "${OUTPUT_DIR}/${required}" ]]; then
		echo "export did not produce ${required}" >&2
		exit 1
	fi
done

echo "web export complete:"
ls -la "${OUTPUT_DIR}"
