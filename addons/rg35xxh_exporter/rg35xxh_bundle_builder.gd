@tool
extends RefCounted

const RUNTIME_DIR_NAME := "runtime"
const GAME_DIR_NAME := "game"
const PAYLOAD_ROOT_DIR_NAME := "ports"
const ROMS_DIR_NAME := "ROMS"
const ROMS_PORTS_DIR_NAME := "Ports"
const DEFAULT_LAUNCHER_NAME := "launch.sh"
const MENU_LAUNCHER_SUFFIX := ".sh"
const GPTOKEYB_NAME := "rg35xxh.gptk"


static func build_bundle(export_path: String, artifact_name: String, export_features: PackedStringArray, is_debug_export: bool, options: Dictionary = {}) -> Dictionary:
	var bundle_dir := _resolve_bundle_dir(export_path)
	var manifest := _build_manifest(artifact_name, export_features, is_debug_export, options)
	var payload_dir := bundle_dir.path_join(PAYLOAD_ROOT_DIR_NAME).path_join(String(manifest["payload_dir_name"]))
	var visible_ports_dir := bundle_dir.path_join(ROMS_DIR_NAME).path_join(ROMS_PORTS_DIR_NAME)
	var menu_launcher_name := _menu_launcher_name(manifest)
	var menu_launcher_path := visible_ports_dir.path_join(menu_launcher_name)

	_prepare_dir(payload_dir.path_join(GAME_DIR_NAME))
	_prepare_dir(visible_ports_dir)

	_write_text_file(payload_dir.path_join("manifest.json"), JSON.stringify(manifest, "\t"), payload_dir, artifact_name)
	_write_text_file(payload_dir.path_join("port.json"), JSON.stringify(_build_port_json(manifest), "\t"), payload_dir, artifact_name)
	_write_text_file(payload_dir.path_join(DEFAULT_LAUNCHER_NAME), _build_payload_launcher_script(artifact_name, manifest), payload_dir, artifact_name)
	_write_text_file(menu_launcher_path, _build_menu_launcher_script(manifest), bundle_dir, artifact_name)
	_write_text_file(payload_dir.path_join(GPTOKEYB_NAME), _build_gptokeyb_config(), payload_dir, artifact_name)
	_write_text_file(payload_dir.path_join("README.txt"), _build_readme(manifest), payload_dir, artifact_name)
	_copy_runtime_if_configured(payload_dir, artifact_name, manifest)

	return {
		"bundle_dir": bundle_dir,
		"payload_dir": payload_dir,
		"manifest": manifest,
		"artifact_path": payload_dir.path_join(GAME_DIR_NAME).path_join(artifact_name),
		"launcher_script_path": menu_launcher_path,
	}


static func copy_artifact_into_bundle(source_path: String, bundle_dir: String, artifact_name: String) -> void:
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		return

	var packaged_artifact := bundle_dir.path_join(GAME_DIR_NAME).path_join(artifact_name)
	_copy_file(source_path, packaged_artifact, bundle_dir, artifact_name)


static func _resolve_bundle_dir(export_path: String) -> String:
	var configured_dir := String(ProjectSettings.get_setting("rg35xxh/export/package_dir", "build/rg35xxh")).strip_edges()
	var export_dir := export_path.get_base_dir()
	var bundle_name := export_path.get_basename().get_file().validate_node_name()
	if bundle_name.is_empty():
		bundle_name = "rg35xxh_game"

	if configured_dir.is_absolute_path():
		return configured_dir.path_join(bundle_name)

	return export_dir.path_join(configured_dir).path_join(bundle_name)


static func _build_manifest(artifact_name: String, export_features: PackedStringArray, is_debug_export: bool, options: Dictionary = {}) -> Dictionary:
	var runtime_override := String(options.get("runtime_path_override", "")).strip_edges()
	var runtime_path := runtime_override if not runtime_override.is_empty() else String(ProjectSettings.get_setting("rg35xxh/export/runtime_path", "")).strip_edges()
	var include_runtime := bool(ProjectSettings.get_setting("rg35xxh/export/include_runtime", true))
	var game_name := String(ProjectSettings.get_setting("rg35xxh/project/game_name", ProjectSettings.get_setting("application/config/name", "My RG35XX H Game")))
	var payload_dir_name := _payload_dir_name(game_name, artifact_name)

	return {
		"game_name": game_name,
		"target_device": "RG35XX H",
		"artifact_name": artifact_name,
		"payload_dir_name": payload_dir_name,
		"visible_launcher_name": _menu_launcher_name({"game_name": game_name, "artifact_name": artifact_name}),
		"artifact_relative_path": "%s/%s" % [GAME_DIR_NAME, artifact_name],
		"artifact_kind": _detect_artifact_kind(artifact_name),
		"export_features": export_features,
		"is_debug": is_debug_export,
		"runtime_configured": not runtime_path.is_empty(),
		"runtime_included": include_runtime and not runtime_path.is_empty(),
		"runtime_path_is_file": FileAccess.file_exists(runtime_path),
		"runtime_source_path": runtime_path,
		"runtime_relative_path": _runtime_relative_path(runtime_path),
		"use_gptokeyb": bool(ProjectSettings.get_setting("rg35xxh/export/use_gptokeyb", true)),
		"gptokeyb_command": String(ProjectSettings.get_setting("rg35xxh/export/gptokeyb_path", "$GPTOKEYB")),
		"gptokeyb_relative_path": GPTOKEYB_NAME,
	}


static func _build_payload_launcher_script(artifact_name: String, manifest: Dictionary) -> String:
	var artifact_kind := String(manifest["artifact_kind"])
	var launcher: PackedStringArray = []
	var process_target := '$GAME_ARTIFACT'

	launcher.append("#!/bin/sh")
	launcher.append("set -eu")
	launcher.append("")
	launcher.append('PAYLOAD_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"')
	launcher.append('GAME_DIR="$PAYLOAD_DIR/%s"' % GAME_DIR_NAME)
	launcher.append('GAME_ARTIFACT="$GAME_DIR/%s"' % artifact_name)
	launcher.append('GPTK_FILE="$PAYLOAD_DIR/%s"' % GPTOKEYB_NAME)
	launcher.append('USE_GPTOKEYB="%s"' % ("1" if manifest["use_gptokeyb"] else "0"))
	launcher.append('GPTOKEYB_CMD="%s"' % String(manifest["gptokeyb_command"]).replace("$GPTOKEYB", '${GPTOKEYB:-}').replace('"', '\\"'))
	launcher.append("")

	if artifact_kind == "pck":
		process_target = '$RUNTIME_PATH'
		launcher.append('RUNTIME_PATH="$PAYLOAD_DIR/%s"' % String(manifest["runtime_relative_path"]))
		launcher.append('if [ ! -x "$RUNTIME_PATH" ]; then')
		launcher.append('  echo "Missing executable Godot ARM64 runtime at: $RUNTIME_PATH"')
		launcher.append('  echo "Set rg35xxh/export/runtime_path to the runtime binary before exporting."')
		launcher.append('  exit 1')
		launcher.append("fi")
		launcher.append('if [ ! -f "$GAME_ARTIFACT" ]; then')
		launcher.append('  echo "Missing PCK payload at: $GAME_ARTIFACT"')
		launcher.append('  exit 1')
		launcher.append("fi")
		launcher.append('chmod +x "$RUNTIME_PATH"')
	else:
		launcher.append('if [ ! -x "$GAME_ARTIFACT" ]; then')
		launcher.append('  chmod +x "$GAME_ARTIFACT" 2>/dev/null || true')
		launcher.append("fi")

	launcher.append("")
	launcher.append('cd "$PAYLOAD_DIR"')
	launcher.append('if [ "$USE_GPTOKEYB" = "1" ] && [ -n "$GPTOKEYB_CMD" ] && [ "$GPTOKEYB_CMD" != "${GPTOKEYB:-}" ] && [ -f "$GPTK_FILE" ]; then')
	launcher.append('  "$GPTOKEYB_CMD" "%s" -c "$GPTK_FILE" &' % process_target)
	launcher.append('  GPTK_PID=$!')
	launcher.append('elif [ "$USE_GPTOKEYB" = "1" ] && [ -n "${GPTOKEYB:-}" ] && [ -f "$GPTK_FILE" ]; then')
	launcher.append('  "$GPTOKEYB" "%s" -c "$GPTK_FILE" &' % process_target)
	launcher.append('  GPTK_PID=$!')
	launcher.append("else")
	launcher.append("  GPTK_PID=\"\"")
	launcher.append("fi")
	launcher.append("")
	if artifact_kind == "pck":
		launcher.append('"$RUNTIME_PATH" --main-pack "$GAME_ARTIFACT" "$@"')
	else:
		launcher.append('"$GAME_ARTIFACT" "$@"')
	launcher.append("")
	launcher.append('STATUS=$?')
	launcher.append('if [ -n "${GPTK_PID:-}" ]; then')
	launcher.append('  kill "$GPTK_PID" 2>/dev/null || true')
	launcher.append("fi")
	launcher.append("exit $STATUS")

	return "\n".join(launcher) + "\n"


static func _build_menu_launcher_script(manifest: Dictionary) -> String:
	var payload_dir_name := String(manifest["payload_dir_name"])
	return "\n".join([
		"#!/bin/sh",
		"set -eu",
		'PAYLOAD_DIR="/mnt/union/ports/%s"' % payload_dir_name,
		'PAYLOAD_LAUNCHER="$PAYLOAD_DIR/%s"' % DEFAULT_LAUNCHER_NAME,
		'if [ ! -x "$PAYLOAD_LAUNCHER" ]; then',
		'  chmod +x "$PAYLOAD_LAUNCHER" 2>/dev/null || true',
		"fi",
		'"$PAYLOAD_LAUNCHER" "$@"',
		"",
	]) + "\n"


static func _build_gptokeyb_config() -> String:
	return "\n".join([
		"up = up",
		"down = down",
		"left = left",
		"right = right",
		"a = z",
		"b = x",
		"x = a",
		"y = s",
		"start = enter",
		"select = rightshift",
		"l1 = q",
		"r1 = w",
		"l2 = e",
		"r2 = r",
		"hotkey = esc",
	]) + "\n"


static func _build_port_json(manifest: Dictionary) -> Dictionary:
	return {
		"name": String(manifest["game_name"]),
		"version": "0.1.0",
		"device": String(manifest["target_device"]),
		"payload_dir": String(manifest["payload_dir_name"]),
		"launcher": String(manifest["visible_launcher_name"]),
		"entrypoint": DEFAULT_LAUNCHER_NAME,
		"runtime": String(manifest["runtime_relative_path"]),
		"artifact": String(manifest["artifact_relative_path"]),
	}


static func _build_readme(manifest: Dictionary) -> String:
	var lines: PackedStringArray = []

	lines.append("RG35XX H muOS export bundle")
	lines.append("==========================")
	lines.append("")
	lines.append("Game: %s" % String(manifest["game_name"]))
	lines.append("Visible launcher: ROMS/Ports/%s" % String(manifest["visible_launcher_name"]))
	lines.append("Payload folder: ports/%s" % String(manifest["payload_dir_name"]))
	lines.append("Artifact: %s" % String(manifest["artifact_relative_path"]))
	lines.append("Artifact kind: %s" % String(manifest["artifact_kind"]))
	lines.append("")
	lines.append("Bundle contents:")
	lines.append("- ROMS/Ports/<game>.sh: menu-visible launcher for muOS")
	lines.append("- ports/<payload>/launch.sh: payload launcher that starts the runtime")
	lines.append("- ports/<payload>/port.json: metadata stub for muOS-style ports")
	lines.append("- ports/<payload>/game/: exported artifact copied after export finishes")
	lines.append("- ports/<payload>/rg35xxh.gptk: starter controller mapping")
	lines.append("")

	if manifest["runtime_included"]:
		lines.append("Runtime: included in %s" % String(manifest["runtime_relative_path"]))
	elif manifest["runtime_configured"]:
		lines.append("Runtime: configured but not copied; update the launcher or toggle include_runtime")
	else:
		lines.append("Runtime: not configured. PCK exports will not boot until a matching Godot ARM64 runtime is supplied.")

	if manifest["runtime_configured"] and not manifest["runtime_path_is_file"]:
		lines.append("Warning: runtime_path currently points to a directory. For the generated launcher, point it to the runtime executable file instead.")
		lines.append("")

	lines.append("")
	lines.append("Suggested workflow:")
	lines.append("1. Export your Godot project as a .pck using the RG35XX H preset.")
	lines.append("2. Copy the generated ROMS/Ports and ports folders onto the muOS SD card roots.")
	lines.append("3. Launch the visible script from the Ports menu and adjust the gptokeyb mapping if needed.")

	return "\n".join(lines) + "\n"


static func _copy_runtime_if_configured(bundle_dir: String, artifact_name: String, manifest: Dictionary) -> void:
	if not bool(ProjectSettings.get_setting("rg35xxh/export/include_runtime", true)):
		return

	var runtime_path := String(manifest.get("runtime_source_path", "")).strip_edges()
	if runtime_path.is_empty():
		return

	if FileAccess.file_exists(runtime_path):
		var target_file := bundle_dir.path_join(_runtime_relative_path(runtime_path))
		_prepare_dir(target_file.get_base_dir())
		_copy_file(runtime_path, target_file, bundle_dir, artifact_name)
		return

	if DirAccess.dir_exists_absolute(runtime_path):
		var target_dir := bundle_dir.path_join(_runtime_relative_path(runtime_path))
		_copy_dir_recursive(runtime_path, target_dir, bundle_dir, artifact_name)


static func _runtime_relative_path(runtime_path: String) -> String:
	if runtime_path.is_empty():
		return ""

	return "%s/%s" % [RUNTIME_DIR_NAME, runtime_path.get_file()]


static func _detect_artifact_kind(filename: String) -> String:
	if filename.get_extension().to_lower() == "pck":
		return "pck"
	return "binary"


static func _prepare_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


static func _write_text_file(path: String, contents: String, bundle_dir: String, artifact_name: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write file: %s" % path)
		return

	file.store_string(contents)
	_mark_executable_if_needed(path, bundle_dir, artifact_name)


static func _copy_file(from_path: String, to_path: String, bundle_dir: String, artifact_name: String) -> void:
	_prepare_dir(to_path.get_base_dir())
	var err := DirAccess.copy_absolute(from_path, to_path)
	if err != OK:
		push_error("Unable to copy file from %s to %s (error %d)" % [from_path, to_path, err])
		return

	_mark_executable_if_needed(to_path, bundle_dir, artifact_name)


static func _copy_dir_recursive(from_dir: String, to_dir: String, bundle_dir: String, artifact_name: String) -> void:
	_prepare_dir(to_dir)
	var dir := DirAccess.open(from_dir)
	if dir == null:
		push_error("Unable to open runtime directory: %s" % from_dir)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry in [".", ".."]:
			entry = dir.get_next()
			continue

		var source_path := from_dir.path_join(entry)
		var target_path := to_dir.path_join(entry)

		if dir.current_is_dir():
			_copy_dir_recursive(source_path, target_path, bundle_dir, artifact_name)
		else:
			_copy_file(source_path, target_path, bundle_dir, artifact_name)

		entry = dir.get_next()

	dir.list_dir_end()


static func _mark_executable_if_needed(path: String, bundle_dir: String, artifact_name: String) -> void:
	if bundle_dir.is_empty():
		return

	var runtime_root := bundle_dir.path_join(RUNTIME_DIR_NAME)
	var filename := path.get_file()
	if path.get_extension().to_lower() == "sh" or filename == artifact_name or path.begins_with(runtime_root):
		OS.execute("chmod", ["+x", path])


static func _payload_dir_name(game_name: String, artifact_name: String) -> String:
	var source_name := game_name.strip_edges()
	if source_name.is_empty():
		source_name = artifact_name.get_basename()

	var slug := source_name.to_lower().replace(" ", "_").replace("-", "_").replace("/", "_").replace("\\", "_").validate_node_name()
	if slug.is_empty():
		slug = artifact_name.get_basename().to_lower().replace(" ", "_").validate_node_name()
	if slug.is_empty():
		return "rg35xxh_game"
	return slug


static func _menu_launcher_name(manifest: Dictionary) -> String:
	var source_name := String(manifest.get("game_name", "")).strip_edges()
	if source_name.is_empty():
		source_name = String(manifest.get("artifact_name", "RG35XX H Game")).get_basename()

	var filename := source_name.replace("/", "_").replace("\\", "_").strip_edges()
	if filename.is_empty():
		filename = "RG35XX H Game"
	if not filename.ends_with(MENU_LAUNCHER_SUFFIX):
		filename += MENU_LAUNCHER_SUFFIX
	return filename
