@tool
extends EditorExportPlugin

const BUNDLE_BUILDER := preload("res://addons/rg35xxh_exporter/rg35xxh_bundle_builder.gd")

var _bundle_dir := ""
var _payload_dir := ""
var _artifact_path := ""
var _artifact_name := ""
var _export_features: PackedStringArray = []
var _is_debug_export := false


func _get_name() -> String:
	return "RG35XX H Export"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	if platform == null:
		return false

	var platform_name: String = String(platform.get_os_name()).to_lower()
	return "linux" in platform_name


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	_export_features = features
	_is_debug_export = is_debug
	_artifact_path = path
	_artifact_name = path.get_file()
	_bundle_dir = _resolve_bundle_dir(path)

	_prepare_dir(_bundle_dir)
	var bundle := BUNDLE_BUILDER.build_bundle(path, _artifact_name, _export_features, _is_debug_export)
	_bundle_dir = String(bundle["bundle_dir"])
	_payload_dir = String(bundle["payload_dir"])


func _export_file(path: String, type: String, features: PackedStringArray) -> void:
	if path.ends_with(".import"):
		skip()


func _export_end() -> void:
	if _artifact_path.is_empty():
		return

	if FileAccess.file_exists(_artifact_path):
		BUNDLE_BUILDER.copy_artifact_into_bundle(_artifact_path, _payload_dir, _artifact_name)

	_reset_state()


func _resolve_bundle_dir(export_path: String) -> String:
	var configured_dir := String(ProjectSettings.get_setting("rg35xxh/export/package_dir", "build/rg35xxh")).strip_edges()
	var export_dir := export_path.get_base_dir()
	var bundle_name := export_path.get_basename().get_file().validate_node_name()
	if bundle_name.is_empty():
		bundle_name = "rg35xxh_game"

	if configured_dir.is_absolute_path():
		return configured_dir.path_join(bundle_name)

	return export_dir.path_join(configured_dir).path_join(bundle_name)


func _prepare_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func _reset_state() -> void:
	_bundle_dir = ""
	_payload_dir = ""
	_artifact_path = ""
	_artifact_name = ""
	_export_features = PackedStringArray()
	_is_debug_export = false
