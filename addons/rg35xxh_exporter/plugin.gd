@tool
extends EditorPlugin

const EXPORT_PLUGIN := preload("res://addons/rg35xxh_exporter/rg35xxh_export_plugin.gd")
const EXPORT_PLATFORM := preload("res://addons/rg35xxh_exporter/rg35xxh_export_platform.gd")

const SETTINGS := {
	"rg35xxh/project/game_name": {
		"default": "My RG35XX H Game",
		"type": TYPE_STRING,
	},
	"rg35xxh/export/runtime_path": {
		"default": "",
		"type": TYPE_STRING,
	},
	"rg35xxh/export/package_dir": {
		"default": "build/rg35xxh",
		"type": TYPE_STRING,
	},
	"rg35xxh/export/include_runtime": {
		"default": true,
		"type": TYPE_BOOL,
	},
	"rg35xxh/export/use_gptokeyb": {
		"default": true,
		"type": TYPE_BOOL,
	},
	"rg35xxh/export/gptokeyb_path": {
		"default": "$GPTOKEYB",
		"type": TYPE_STRING,
	},
}

var _export_plugin: EditorExportPlugin
var _export_platform: EditorExportPlatform


func _enter_tree() -> void:
	_register_project_settings()

	_export_plugin = EXPORT_PLUGIN.new()
	add_export_plugin(_export_plugin)

	_export_platform = EXPORT_PLATFORM.new()
	add_export_platform(_export_platform)

	add_tool_menu_item("RG35XX H/Apply Project Preset", _apply_project_preset)
	add_tool_menu_item("RG35XX H/Install Input Preset", _install_input_preset)
	add_tool_menu_item("RG35XX H/Validate Project", _validate_project)


func _exit_tree() -> void:
	remove_tool_menu_item("RG35XX H/Apply Project Preset")
	remove_tool_menu_item("RG35XX H/Install Input Preset")
	remove_tool_menu_item("RG35XX H/Validate Project")

	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null

	if _export_platform != null:
		remove_export_platform(_export_platform)
		_export_platform = null


func _register_project_settings() -> void:
	for key in SETTINGS.keys():
		var spec: Dictionary = SETTINGS[key]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, spec["default"])

		ProjectSettings.set_as_basic(key, true)
		ProjectSettings.add_property_info({
			"name": key,
			"type": spec["type"],
		})

	ProjectSettings.save()


func _apply_project_preset() -> void:
	var settings := {
		"display/window/size/viewport_width": 640,
		"display/window/size/viewport_height": 480,
		"display/window/size/window_width_override": 640,
		"display/window/size/window_height_override": 480,
		"display/window/stretch/mode": "canvas_items",
		"display/window/stretch/aspect": "keep",
		"display/window/handheld/orientation": 0,
		"rendering/2d/snap/snap_2d_transforms_to_pixel": true,
		"rendering/2d/snap/snap_2d_vertices_to_pixel": true,
		"rendering/textures/canvas_textures/default_texture_filter": 0,
		"rendering/environment/defaults/default_clear_color": Color(0, 0, 0, 1),
	}

	for key in settings.keys():
		ProjectSettings.set_setting(key, settings[key])

	_install_input_preset(false)
	ProjectSettings.save()
	_show_message(
		"Applied RG35XX H defaults",
		"Viewport, pixel rendering, and handheld inputs were saved to the project."
	)


func _install_input_preset(show_success: bool = true) -> void:
	var input_preset := _build_input_preset()

	for action in input_preset.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)

		_clear_action_events(action)

		for event_spec in input_preset[action]:
			InputMap.action_add_event(action, _create_input_event(event_spec))

	ProjectSettings.save()

	if show_success:
		_show_message(
			"Installed RG35XX H inputs",
			"Added baseline joypad actions for the device controls."
		)


func _validate_project() -> void:
	var warnings: PackedStringArray = []

	if ProjectSettings.get_setting("display/window/size/viewport_width", 0) != 640:
		warnings.append("Viewport width is not set to 640.")

	if ProjectSettings.get_setting("display/window/size/viewport_height", 0) != 480:
		warnings.append("Viewport height is not set to 480.")

	if ProjectSettings.get_setting("display/window/stretch/mode", "") != "canvas_items":
		warnings.append("Stretch mode should be 'canvas_items'.")

	if not ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false):
		warnings.append("2D transform snapping is disabled.")

	if not ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false):
		warnings.append("2D vertex snapping is disabled.")

	if not ProjectSettings.has_setting("rg35xxh/export/runtime_path") or String(ProjectSettings.get_setting("rg35xxh/export/runtime_path", "")).is_empty():
		warnings.append("Runtime path is empty. PCK exports need the Godot ARM64 runtime binary to boot on muOS.")

	for required_action in ["rg_a", "rg_b", "rg_start", "rg_select", "rg_up", "rg_down", "rg_left", "rg_right"]:
		if not InputMap.has_action(required_action):
			warnings.append("Missing input action: %s" % required_action)

	if warnings.is_empty():
		_show_message(
			"RG35XX H validation",
			"No obvious issues found. The project matches the current handheld preset."
		)
		return

	_show_message(
		"RG35XX H validation warnings",
		"\n".join(warnings)
	)


func _clear_action_events(action: StringName) -> void:
	for event in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, event)


func _create_input_event(event_spec: Dictionary) -> InputEvent:
	if event_spec["kind"] == "button":
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = event_spec["id"]
		button_event.pressed = true
		return button_event

	var motion_event := InputEventJoypadMotion.new()
	motion_event.axis = event_spec["axis"]
	motion_event.axis_value = event_spec["value"]
	return motion_event


func _build_input_preset() -> Dictionary:
	return {
		"ui_up": [{"kind": "button", "id": JOY_BUTTON_DPAD_UP}],
		"ui_down": [{"kind": "button", "id": JOY_BUTTON_DPAD_DOWN}],
		"ui_left": [{"kind": "button", "id": JOY_BUTTON_DPAD_LEFT}],
		"ui_right": [{"kind": "button", "id": JOY_BUTTON_DPAD_RIGHT}],
		"ui_accept": [{"kind": "button", "id": JOY_BUTTON_A}],
		"ui_cancel": [{"kind": "button", "id": JOY_BUTTON_B}],
		"rg_up": [{"kind": "button", "id": JOY_BUTTON_DPAD_UP}],
		"rg_down": [{"kind": "button", "id": JOY_BUTTON_DPAD_DOWN}],
		"rg_left": [{"kind": "button", "id": JOY_BUTTON_DPAD_LEFT}],
		"rg_right": [{"kind": "button", "id": JOY_BUTTON_DPAD_RIGHT}],
		"rg_a": [{"kind": "button", "id": JOY_BUTTON_A}],
		"rg_b": [{"kind": "button", "id": JOY_BUTTON_B}],
		"rg_x": [{"kind": "button", "id": JOY_BUTTON_X}],
		"rg_y": [{"kind": "button", "id": JOY_BUTTON_Y}],
		"rg_l1": [{"kind": "button", "id": JOY_BUTTON_LEFT_SHOULDER}],
		"rg_r1": [{"kind": "button", "id": JOY_BUTTON_RIGHT_SHOULDER}],
		"rg_l2": [{"kind": "motion", "axis": JOY_AXIS_TRIGGER_LEFT, "value": 1.0}],
		"rg_r2": [{"kind": "motion", "axis": JOY_AXIS_TRIGGER_RIGHT, "value": 1.0}],
		"rg_start": [{"kind": "button", "id": JOY_BUTTON_START}],
		"rg_select": [{"kind": "button", "id": JOY_BUTTON_BACK}],
		"rg_menu": [{"kind": "button", "id": JOY_BUTTON_GUIDE}],
		"rg_left_stick_x": [
			{"kind": "motion", "axis": JOY_AXIS_LEFT_X, "value": -1.0},
			{"kind": "motion", "axis": JOY_AXIS_LEFT_X, "value": 1.0},
		],
		"rg_left_stick_y": [
			{"kind": "motion", "axis": JOY_AXIS_LEFT_Y, "value": -1.0},
			{"kind": "motion", "axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		],
		"rg_left_stick_press": [{"kind": "button", "id": JOY_BUTTON_LEFT_STICK}],
		"rg_right_stick_x": [
			{"kind": "motion", "axis": JOY_AXIS_RIGHT_X, "value": -1.0},
			{"kind": "motion", "axis": JOY_AXIS_RIGHT_X, "value": 1.0},
		],
		"rg_right_stick_y": [
			{"kind": "motion", "axis": JOY_AXIS_RIGHT_Y, "value": -1.0},
			{"kind": "motion", "axis": JOY_AXIS_RIGHT_Y, "value": 1.0},
		],
		"rg_right_stick_press": [{"kind": "button", "id": JOY_BUTTON_RIGHT_STICK}],
	}


func _show_message(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.unresizable = false
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered_clamped(Vector2i(620, 360))
