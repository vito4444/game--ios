#!/usr/bin/env bash
# Export the Xcode project for iOS.
#
# This part does run on Linux: with `export_project_only` set, Godot writes a
# complete Xcode project and stops short of the parts that need Apple's
# toolchain. Only the signing and packaging that follows needs macOS.
#
# The bundle identifier and team ID in export_presets.cfg are placeholders. Set
# IOS_BUNDLE_ID and APPLE_TEAM_ID and this script substitutes them into a
# scratch copy of the preset file, leaving the committed one untouched.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-${REPO_ROOT}/.tools/godot}"
OUTPUT_DIR="${REPO_ROOT}/build/ios"
PRESET_FILE="${REPO_ROOT}/export_presets.cfg"
PLACEHOLDER_BUNDLE_ID="com.example.deepcontract"
PLACEHOLDER_TEAM_ID="APPLE_TEAM_ID"
SCHEME_NAME="DeepContract"

if [[ ! -x "${GODOT_BIN}" ]]; then
	echo "godot binary not found at ${GODOT_BIN}; run tools/get_godot.sh --templates first" >&2
	exit 1
fi

restore_preset() {
	if [[ -f "${PRESET_FILE}.orig" ]]; then
		mv -f "${PRESET_FILE}.orig" "${PRESET_FILE}"
	fi
}
trap restore_preset EXIT

if [[ -n "${IOS_BUNDLE_ID:-}" || -n "${APPLE_TEAM_ID:-}" ]]; then
	cp "${PRESET_FILE}" "${PRESET_FILE}.orig"
	if [[ -n "${IOS_BUNDLE_ID:-}" ]]; then
		sed -i.bak "s|${PLACEHOLDER_BUNDLE_ID}|${IOS_BUNDLE_ID}|g" "${PRESET_FILE}"
	fi
	if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
		sed -i.bak "s|\"${PLACEHOLDER_TEAM_ID}\"|\"${APPLE_TEAM_ID}\"|g" "${PRESET_FILE}"
	fi
	rm -f "${PRESET_FILE}.bak"
fi

if [[ -n "${IOS_BUILD_NUMBER:-}" ]]; then
	# TestFlight rejects a build number it has already seen, so CI passes the
	# run number through.
	sed -i.bak "s|^application/version=.*|application/version=\"${IOS_BUILD_NUMBER}\"|" \
		"${PRESET_FILE}"
	rm -f "${PRESET_FILE}.bak"
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

"${GODOT_BIN}" --headless --path "${REPO_ROOT}" \
	--export-release "iOS" "${OUTPUT_DIR}/${SCHEME_NAME}.xcodeproj"

for required in \
	"${SCHEME_NAME}.xcodeproj/project.pbxproj" \
	"${SCHEME_NAME}.pck" \
	"PrivacyInfo.xcprivacy"
do
	if [[ ! -e "${OUTPUT_DIR}/${required}" ]]; then
		echo "export did not produce ${required}" >&2
		exit 1
	fi
done

echo "xcode project ready in ${OUTPUT_DIR}"
ls "${OUTPUT_DIR}"
