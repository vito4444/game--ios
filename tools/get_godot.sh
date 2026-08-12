#!/usr/bin/env bash
# Download the pinned Godot editor build (and optionally the export templates)
# into .tools/ so local runs and CI use the exact same engine version.
#
# Usage:
#   tools/get_godot.sh              # editor binary only
#   tools/get_godot.sh --templates  # editor binary + export templates
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.1}"
GODOT_RELEASE="${GODOT_RELEASE:-stable}"
GODOT_TAG="${GODOT_VERSION}-${GODOT_RELEASE}"
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_TAG}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="${REPO_ROOT}/.tools"
BIN_PATH="${TOOLS_DIR}/godot"

case "$(uname -s)" in
	Linux)  PLATFORM="linux.x86_64" ;;
	Darwin) PLATFORM="macos.universal" ;;
	*) echo "unsupported host platform: $(uname -s)" >&2; exit 1 ;;
esac

mkdir -p "${TOOLS_DIR}"

download() {
	local url="$1" dest="$2"
	echo "downloading ${url}"
	curl --fail --location --silent --show-error --retry 3 --retry-delay 4 -o "${dest}" "${url}"
}

if [[ -x "${BIN_PATH}" ]] && "${BIN_PATH}" --version 2>/dev/null | grep -q "^${GODOT_VERSION}"; then
	echo "godot ${GODOT_TAG} already present at ${BIN_PATH}"
else
	ARCHIVE="${TOOLS_DIR}/godot.zip"
	if [[ "${PLATFORM}" == "macos.universal" ]]; then
		download "${BASE_URL}/Godot_v${GODOT_TAG}_macos.universal.zip" "${ARCHIVE}"
		rm -rf "${TOOLS_DIR}/Godot.app"
		unzip -q -o "${ARCHIVE}" -d "${TOOLS_DIR}"
		ln -sf "${TOOLS_DIR}/Godot.app/Contents/MacOS/Godot" "${BIN_PATH}"
	else
		download "${BASE_URL}/Godot_v${GODOT_TAG}_${PLATFORM}.zip" "${ARCHIVE}"
		unzip -q -o "${ARCHIVE}" -d "${TOOLS_DIR}"
		mv -f "${TOOLS_DIR}/Godot_v${GODOT_TAG}_${PLATFORM}" "${BIN_PATH}"
		chmod +x "${BIN_PATH}"
	fi
	rm -f "${ARCHIVE}"
fi

"${BIN_PATH}" --version

if [[ "${1:-}" == "--templates" ]]; then
	# Godot looks for templates under a fixed, version-named directory.
	if [[ "$(uname -s)" == "Darwin" ]]; then
		TEMPLATE_DIR="${HOME}/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"
	else
		TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"
	fi

	if [[ -d "${TEMPLATE_DIR}" ]] && [[ -n "$(ls -A "${TEMPLATE_DIR}" 2>/dev/null)" ]]; then
		echo "export templates already present at ${TEMPLATE_DIR}"
	else
		TPZ="${TOOLS_DIR}/templates.tpz"
		download "${BASE_URL}/Godot_v${GODOT_TAG}_export_templates.tpz" "${TPZ}"
		rm -rf "${TOOLS_DIR}/templates"
		unzip -q -o "${TPZ}" -d "${TOOLS_DIR}"
		mkdir -p "${TEMPLATE_DIR}"
		mv -f "${TOOLS_DIR}"/templates/* "${TEMPLATE_DIR}/"
		rmdir "${TOOLS_DIR}/templates"
		rm -f "${TPZ}"
		echo "export templates installed to ${TEMPLATE_DIR}"
	fi
fi
