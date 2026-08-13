extends GutTest

## The iOS release configuration.
##
## None of this can be exercised on a build machine without Xcode, so it is
## checked structurally instead: the settings the App Store build depends on
## are asserted here rather than discovered during a failed submission.

const PRESET_PATH := "res://export_presets.cfg"
const PRIVACY_MANIFEST := "res://ios/PrivacyInfo.xcprivacy"
const ICON_PATH := "res://assets/generated/icons/app_icon.png"

var preset: ConfigFile
var section: String = ""


func before_all() -> void:
	preset = ConfigFile.new()
	assert_eq(preset.load(PRESET_PATH), OK, "cannot read export_presets.cfg")
	for index in range(8):
		if preset.has_section("preset.%d" % index) \
				and preset.get_value("preset.%d" % index, "platform", "") == "iOS":
			section = "preset.%d" % index
			return
	fail_test("no iOS preset in export_presets.cfg")


func _option(key: String, fallback: Variant = null) -> Variant:
	return preset.get_value("%s.options" % section, key, fallback)


func test_there_is_an_ios_preset() -> void:
	assert_ne(section, "")
	assert_eq(preset.get_value(section, "name", ""), "iOS")


func test_the_preset_carries_a_bundle_identifier() -> void:
	var identifier: String = _option("application/bundle_identifier", "")
	assert_false(identifier.is_empty(), "bundle identifier is required")
	assert_true(
		identifier.contains("."), "%s is not in reverse-DNS form" % identifier
	)
	assert_true(
		RegEx.create_from_string("^[A-Za-z0-9.-]+$").search(identifier) != null,
		"a bundle id may only contain letters, digits, hyphens and dots"
	)


func test_the_preset_carries_an_app_store_team_id() -> void:
	assert_false(String(_option("application/app_store_team_id", "")).is_empty())


func test_the_provisioning_profile_matches_the_fastlane_naming() -> void:
	# fastlane match creates a profile called "match AppStore <bundle id>";
	# the two have to agree or signing picks nothing up.
	var identifier: String = _option("application/bundle_identifier", "")
	assert_eq(
		_option("application/provisioning_profile_specifier_release", ""),
		"match AppStore %s" % identifier
	)


func test_the_export_produces_a_project_rather_than_an_ipa() -> void:
	# This is what lets the export step run anywhere; fastlane does the rest.
	assert_true(
		_option("application/export_project_only", false),
		"export_project_only must be on for the Linux export step to work"
	)


func test_the_release_export_method_is_app_store() -> void:
	assert_eq(_option("application/export_method_release", -1), 0)
	assert_eq(_option("application/code_sign_identity_release", ""), "Apple Distribution")


func test_the_app_targets_both_iphone_and_ipad() -> void:
	assert_eq(_option("application/targeted_device_family", 0), 2)


func test_the_build_is_arm64() -> void:
	assert_true(_option("architectures/arm64", false))


func test_the_preset_declares_no_tracking_and_no_data_collection() -> void:
	assert_false(_option("privacy/tracking_enabled", true))
	for key in preset.get_section_keys("%s.options" % section):
		if not key.begins_with("privacy/collected_data/"):
			continue
		assert_false(_option(key, true), "%s claims data is collected" % key)


func test_the_preset_asks_for_no_device_permissions() -> void:
	for key in [
		"privacy/camera_usage_description",
		"privacy/microphone_usage_description",
		"privacy/photolibrary_usage_description",
	]:
		assert_eq(String(_option(key, "x")), "", "%s should stay empty" % key)
	assert_false(_option("capabilities/access_wifi", true))
	assert_false(_option("capabilities/push_notifications", true))


func test_the_icons_point_at_files_that_exist() -> void:
	for key in [
		"icons/icon_1024x1024",
		"icons/icon_1024x1024_dark",
		"icons/icon_1024x1024_tinted",
	]:
		var path: String = _option(key, "")
		assert_false(path.is_empty(), "%s is not set" % key)
		assert_true(ResourceLoader.exists(path), "%s points at a missing file" % path)


func test_the_app_store_icon_is_1024_square_and_opaque() -> void:
	var image := (load(ICON_PATH) as Texture2D).get_image()
	assert_eq(image.get_width(), 1024)
	assert_eq(image.get_height(), 1024)
	assert_false(image.detect_alpha() == Image.ALPHA_BLEND, "the icon must be fully opaque")


func test_tests_and_tools_are_kept_out_of_the_build() -> void:
	var excluded: String = preset.get_value(section, "exclude_filter", "")
	for path in ["addons/gut/*", "tests/*", "tools/*"]:
		assert_true(excluded.contains(path), "%s should not ship" % path)


func test_the_privacy_manifest_is_a_valid_plist_declaring_no_collection() -> void:
	var file := FileAccess.open(PRIVACY_MANIFEST, FileAccess.READ)
	assert_not_null(file, "no privacy manifest at %s" % PRIVACY_MANIFEST)
	var text := file.get_as_text()

	assert_true(text.begins_with("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
	assert_true(text.contains("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\""))
	assert_true(text.contains("<plist version=\"1.0\">"))
	assert_true(text.strip_edges().ends_with("</plist>"))

	var parser := XMLParser.new()
	assert_eq(parser.open_buffer(text.to_utf8_buffer()), OK)
	var depth := 0
	while parser.read() == OK:
		if parser.get_node_type() == XMLParser.NODE_ELEMENT and not parser.is_empty():
			depth += 1
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			depth -= 1
		assert_true(depth >= 0, "unbalanced tags in the privacy manifest")
	assert_eq(depth, 0, "unclosed tags in the privacy manifest")

	assert_true(text.contains("<key>NSPrivacyTracking</key>\n\t<false/>"))
	assert_true(text.contains("<key>NSPrivacyCollectedDataTypes</key>\n\t<array/>"))


func test_the_documented_secrets_match_what_the_workflow_reads() -> void:
	var workflow := FileAccess.open(
		"res://.github/workflows/ios-testflight.yml", FileAccess.READ
	)
	assert_not_null(workflow)
	var yaml := workflow.get_as_text()

	var docs := FileAccess.open("res://docs/APPSTORE.md", FileAccess.READ)
	assert_not_null(docs)
	var markdown := docs.get_as_text()

	for secret in [
		"APPLE_TEAM_ID",
		"IOS_BUNDLE_ID",
		"APPLE_API_KEY_ID",
		"APPLE_API_ISSUER_ID",
		"APPLE_API_KEY_CONTENT",
		"MATCH_GIT_URL",
		"MATCH_PASSWORD",
		"MATCH_GIT_BASIC_AUTHORIZATION",
	]:
		assert_true(yaml.contains("secrets.%s" % secret), "the workflow never reads %s" % secret)
		assert_true(markdown.contains(secret), "%s is not documented" % secret)
