extends Node2D

const SCREEN_W = 640
const SCREEN_H = 480

# Selectable rows: 0 = score limit, 1 = START, 2 = EXIT
var selected := 1

var score_value_label: Label
var row_labels: Array = []  # labels for START and EXIT

func _ready() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "PING PONG"
	title.add_theme_font_size_override("font_size", 72)
	title.modulate = Color.WHITE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(SCREEN_W, 90)
	title.position = Vector2(0, 80)
	add_child(title)

	var divider := ColorRect.new()
	divider.color = Color(0.35, 0.35, 0.35)
	divider.size = Vector2(200, 3)
	divider.position = Vector2(SCREEN_W / 2 - 100, 180)
	add_child(divider)

	# --- Score limit row ---
	var score_header := Label.new()
	score_header.text = "SCORE LIMIT"
	score_header.add_theme_font_size_override("font_size", 20)
	score_header.modulate = Color(0.6, 0.6, 0.6)
	score_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_header.size = Vector2(SCREEN_W, 28)
	score_header.position = Vector2(0, 200)
	add_child(score_header)

	score_value_label = Label.new()
	score_value_label.add_theme_font_size_override("font_size", 38)
	score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_value_label.size = Vector2(SCREEN_W, 52)
	score_value_label.position = Vector2(0, 232)
	add_child(score_value_label)

	# --- START / EXIT ---
	var button_texts := ["START", "EXIT"]
	var start_y := 320
	for i in range(button_texts.size()):
		var lbl := Label.new()
		lbl.text = button_texts[i]
		lbl.add_theme_font_size_override("font_size", 38)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(SCREEN_W, 52)
		lbl.position = Vector2(0, start_y + i * 64)
		add_child(lbl)
		row_labels.append(lbl)

	# Controls hint
	var hint := Label.new()
	hint.text = "D-Pad / stick to navigate     Left/Right to change score     A/X/Start to select     B/Menu to back out"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(0.35, 0.35, 0.35)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(SCREEN_W, 24)
	hint.position = Vector2(0, SCREEN_H - 28)
	add_child(hint)

	_update_display()


func _update_display() -> void:
	# Score value label: show arrows only when row is selected
	if selected == 0:
		score_value_label.text = "<  %d  >" % Global.score_limit
		score_value_label.modulate = Color.YELLOW
	else:
		score_value_label.text = str(Global.score_limit)
		score_value_label.modulate = Color(0.45, 0.45, 0.45)

	# START / EXIT labels (selected index 1 and 2 map to row_labels 0 and 1)
	for i in range(row_labels.size()):
		if selected == i + 1:
			row_labels[i].modulate = Color.YELLOW
		else:
			row_labels[i].modulate = Color(0.45, 0.45, 0.45)


func _process(_delta: float) -> void:
	# Navigate up / down
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("rg35xxh_left_up"):
		selected = max(0, selected - 1)
		_update_display()

	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("rg35xxh_left_down"):
		selected = min(2, selected + 1)
		_update_display()

	# Change score limit when on score row
	if selected == 0:
		if Input.is_action_just_pressed("ui_left"):
			Global.score_limit = max(1, Global.score_limit - 1)
			_update_display()
		if Input.is_action_just_pressed("ui_right"):
			Global.score_limit = min(20, Global.score_limit + 1)
			_update_display()

	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("rg_x") or Input.is_action_just_pressed("rg_a") or Input.is_action_just_pressed("rg_start"):
		_confirm()

	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("menu_back") or Input.is_action_just_pressed("rg_menu") or Input.is_action_just_pressed("rg_b"):
		if selected == 2:
			_confirm()
		else:
			selected = 2
			_update_display()


func _input(event: InputEvent) -> void:
	# Mouse click for START / EXIT on desktop
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(row_labels.size()):
			var lbl: Label = row_labels[i]
			if Rect2(lbl.position, lbl.size).has_point(event.position):
				selected = i + 1
				_update_display()
				_confirm()
				return


func _confirm() -> void:
	match selected:
		1:
			get_tree().change_scene_to_file("res://main.tscn")
		2:
			get_tree().quit()
