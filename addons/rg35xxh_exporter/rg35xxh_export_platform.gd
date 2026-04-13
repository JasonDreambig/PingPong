@tool
extends EditorExportPlatformExtension

const BUNDLE_BUILDER := preload("res://addons/rg35xxh_exporter/rg35xxh_bundle_builder.gd")
const LOGO := preload("res://addons/rg35xxh_exporter/icon.png")


func _get_name() -> String:
	return "RG35XX H"


func _get_os_name() -> String:
	return "Linux"


func _get_logo() -> Texture2D:
	return LOGO


func _get_platform_features() -> PackedStringArray:
	return PackedStringArray(["linux", "rg35xxh", "handheld"])


func _get_preset_features(preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["linux", "rg35xxh", "muos"])


func _get_binary_extensions(preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["sh"])


func _get_export_options() -> Array[Dictionary]:
	return [
		{
			"option": {
				"name": "rg35xxh/export_as_pck",
				"type": TYPE_BOOL,
			},
			"default_value": true,
		},
		{
			"option": {
				"name": "rg35xxh/runtime_path_override",
				"type": TYPE_STRING,
			},
			"default_value": "",
		},
	]


func _can_export(preset: EditorExportPreset, debug: bool) -> bool:
	var valid := _has_valid_project_configuration(preset) and _has_valid_export_configuration(preset, debug)
	if not valid and get_config_error().is_empty():
		set_config_error("RG35XX H export configuration is incomplete.")
	return valid


func _has_valid_export_configuration(preset: EditorExportPreset, debug: bool) -> bool:
	set_config_error("")
	set_config_missing_templates(false)

	var export_as_pck := bool(preset.get("rg35xxh/export_as_pck"))
	var runtime_override := String(preset.get("rg35xxh/runtime_path_override")).strip_edges()
	var runtime_path := runtime_override if not runtime_override.is_empty() else String(ProjectSettings.get_setting("rg35xxh/export/runtime_path", "")).strip_edges()

	if not export_as_pck:
		set_config_error("RG35XX H exports currently package a .pck plus a Godot ARM64 runtime for muOS ports deployment. Leave Export as PCK enabled.")
		return false

	if runtime_path.is_empty():
		set_config_error("Set rg35xxh/export/runtime_path or the preset runtime override before exporting as PCK.")
		return false

	return true


func _has_valid_project_configuration(preset: EditorExportPreset) -> bool:
	set_config_error("")

	var width := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var height := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	if width <= 0 or height <= 0:
		set_config_error("Project viewport size is not configured.")
		return false

	return true


func _is_executable(path: String) -> bool:
	return path.get_extension().to_lower() == "sh"


func _export_project(preset: EditorExportPreset, debug: bool, path: String, flags: int) -> Error:
	var bundle_name := path.get_basename().get_file().validate_node_name()
	if bundle_name.is_empty():
		bundle_name = "rg35xxh_game"

	var runtime_override := String(preset.get("rg35xxh/runtime_path_override")).strip_edges()
	var artifact_name := "%s.pck" % bundle_name
	var staged_artifact_path := path.get_base_dir().path_join(".%s" % artifact_name)

	var save_result: Dictionary = save_pack(preset, debug, staged_artifact_path)
	var result := int(save_result.get("result", ERR_CANT_CREATE))
	if result != OK:
		return result

	var bundle := BUNDLE_BUILDER.build_bundle(path, artifact_name, _get_preset_features(preset), debug, {
		"runtime_path_override": runtime_override,
	})
	BUNDLE_BUILDER.copy_artifact_into_bundle(staged_artifact_path, String(bundle["payload_dir"]), artifact_name)

	var launch_script_path := String(bundle["launcher_script_path"])
	if FileAccess.file_exists(launch_script_path):
		DirAccess.copy_absolute(launch_script_path, path)

	DirAccess.remove_absolute(staged_artifact_path)
	return OK
