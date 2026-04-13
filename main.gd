extends Node2D

const SCREEN_W = 640
const SCREEN_H = 480
const PADDLE_W = 15
const PADDLE_H = 100
const BALL_SIZE = 15
const PADDLE_SPEED = 400
const BALL_SPEED = 500
const PADDLE_MARGIN = 30
const DOUBLE_TAP_WINDOW := 0.3   # seconds between taps to count as double-tap
const DASH_SPEED := 900.0        # extra speed applied during a dash
const DASH_DURATION := 0.14      # how long the dash lasts

var ball_vel := Vector2(BALL_SPEED, BALL_SPEED * 0.4)
var score := [0, 0]
var game_over := false

# Double-tap timestamps (-1 = never pressed)
var p1_last_up := -1.0
var p1_last_down := -1.0
var p2_last_up := -1.0
var p2_last_down := -1.0

# Active dash state per paddle: velocity + remaining time
var p1_dash_vel := 0.0
var p1_dash_timer := 0.0
var p2_dash_vel := 0.0
var p2_dash_timer := 0.0

var ball: ColorRect
var paddle1: ColorRect
var paddle2: ColorRect
var score_label: Label
var game_over_overlay: ColorRect
var result_label: Label
var continue_label: Label
var sfx_hit: AudioStreamPlayer
var sfx_gameover: AudioStreamPlayer


func _ready() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	add_child(bg)

	# Center dashed line
	for i in range(0, SCREEN_H, 30):
		var dash := ColorRect.new()
		dash.color = Color(0.4, 0.4, 0.4)
		dash.size = Vector2(4, 18)
		dash.position = Vector2(SCREEN_W / 2 - 2, i)
		add_child(dash)

	# Ball
	ball = ColorRect.new()
	ball.color = Color.WHITE
	ball.size = Vector2(BALL_SIZE, BALL_SIZE)
	ball.position = Vector2(SCREEN_W / 2 - BALL_SIZE / 2, SCREEN_H / 2 - BALL_SIZE / 2)
	add_child(ball)

	# Paddle 1 (left) — W / S or handheld left controls
	paddle1 = ColorRect.new()
	paddle1.color = Color.WHITE
	paddle1.size = Vector2(PADDLE_W, PADDLE_H)
	paddle1.position = Vector2(PADDLE_MARGIN, SCREEN_H / 2 - PADDLE_H / 2)
	add_child(paddle1)

	# Paddle 2 (right) — Up / Down or handheld right shoulder controls
	paddle2 = ColorRect.new()
	paddle2.color = Color.WHITE
	paddle2.size = Vector2(PADDLE_W, PADDLE_H)
	paddle2.position = Vector2(SCREEN_W - PADDLE_MARGIN - PADDLE_W, SCREEN_H / 2 - PADDLE_H / 2)
	add_child(paddle2)

	# Score label
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.modulate = Color.WHITE
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.size = Vector2(300, 60)
	score_label.position = Vector2(SCREEN_W / 2 - 150, 16)
	add_child(score_label)
	_update_score_label()

	# Controls hint
	var hint := Label.new()
	hint.text = "Left paddle: W/S, D-Pad, left stick     Right paddle: Arrows, shoulders, right stick     B/Menu to quit"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.4, 0.4, 0.4)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(SCREEN_W, 24)
	hint.position = Vector2(0, SCREEN_H - 28)
	add_child(hint)

	# Game-over overlay (hidden until game ends)
	game_over_overlay = ColorRect.new()
	game_over_overlay.color = Color(0, 0, 0, 0.72)
	game_over_overlay.size = Vector2(SCREEN_W, SCREEN_H)
	game_over_overlay.visible = false
	add_child(game_over_overlay)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 52)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.size = Vector2(SCREEN_W, 70)
	result_label.position = Vector2(0, SCREEN_H / 2 - 70)
	result_label.visible = false
	add_child(result_label)

	continue_label = Label.new()
	continue_label.text = "Press A / Enter to return to menu"
	continue_label.add_theme_font_size_override("font_size", 22)
	continue_label.modulate = Color(0.7, 0.7, 0.7)
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_label.size = Vector2(SCREEN_W, 34)
	continue_label.position = Vector2(0, SCREEN_H / 2 + 20)
	continue_label.visible = false
	add_child(continue_label)

	# Sound effects (synthesised — no external files needed)
	sfx_hit = AudioStreamPlayer.new()
	sfx_hit.stream = _make_tone(660.0, 0.08)
	add_child(sfx_hit)

	sfx_gameover = AudioStreamPlayer.new()
	sfx_gameover.stream = _make_gameover_sound()
	add_child(sfx_gameover)


func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("rg_a") or Input.is_action_just_pressed("rg_x") or Input.is_action_just_pressed("menu_back") or Input.is_action_just_pressed("rg_menu") or Input.is_action_just_pressed("ui_cancel"):
			get_tree().change_scene_to_file("res://menu.tscn")
		return

	_process_menu_back()

	var t := Time.get_ticks_msec() / 1000.0

	# --- Paddle 1 double-tap detection ---
	var p1_up_just   := Input.is_action_just_pressed("p1_up")   or Input.is_action_just_pressed("rg35xxh_left_up") or Input.is_action_just_pressed("rg_up") or Input.is_action_just_pressed("rg_test_p1_up")
	var p1_down_just := Input.is_action_just_pressed("p1_down") or Input.is_action_just_pressed("rg35xxh_left_down") or Input.is_action_just_pressed("rg_down") or Input.is_action_just_pressed("rg_test_p1_down")
	if p1_up_just:
		if p1_last_up >= 0.0 and t - p1_last_up < DOUBLE_TAP_WINDOW:
			p1_dash_vel = -DASH_SPEED
			p1_dash_timer = DASH_DURATION
			p1_last_up = -1.0
		else:
			p1_last_up = t
	if p1_down_just:
		if p1_last_down >= 0.0 and t - p1_last_down < DOUBLE_TAP_WINDOW:
			p1_dash_vel = DASH_SPEED
			p1_dash_timer = DASH_DURATION
			p1_last_down = -1.0
		else:
			p1_last_down = t

	# --- Paddle 2 double-tap detection ---
	var p2_up_just   := Input.is_action_just_pressed("p2_up")   or Input.is_action_just_pressed("ui_up")   or Input.is_action_just_pressed("rg35xxh_right_up") or Input.is_action_just_pressed("rg_r1") or Input.is_action_just_pressed("rg_test_p2_up")
	var p2_down_just := Input.is_action_just_pressed("p2_down") or Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("rg35xxh_right_down") or Input.is_action_just_pressed("rg_r2") or Input.is_action_just_pressed("rg_test_p2_down")
	if p2_up_just:
		if p2_last_up >= 0.0 and t - p2_last_up < DOUBLE_TAP_WINDOW:
			p2_dash_vel = -DASH_SPEED
			p2_dash_timer = DASH_DURATION
			p2_last_up = -1.0
		else:
			p2_last_up = t
	if p2_down_just:
		if p2_last_down >= 0.0 and t - p2_last_down < DOUBLE_TAP_WINDOW:
			p2_dash_vel = DASH_SPEED
			p2_dash_timer = DASH_DURATION
			p2_last_down = -1.0
		else:
			p2_last_down = t

	# --- Paddle 1 movement (normal + dash) ---
	var p1_move := 0.0
	if Input.is_action_pressed("p1_up")   or Input.is_action_pressed("rg35xxh_left_up") or Input.is_action_pressed("rg_up") or Input.is_action_pressed("rg_test_p1_up"):
		p1_move -= PADDLE_SPEED
	if Input.is_action_pressed("p1_down") or Input.is_action_pressed("rg35xxh_left_down") or Input.is_action_pressed("rg_down") or Input.is_action_pressed("rg_test_p1_down"):
		p1_move += PADDLE_SPEED
	if p1_dash_timer > 0.0:
		p1_move += p1_dash_vel
		p1_dash_timer -= delta
	paddle1.position.y = clamp(paddle1.position.y + p1_move * delta, 0.0, SCREEN_H - PADDLE_H)

	# --- Paddle 2 movement (normal + dash) ---
	var p2_move := 0.0
	if Input.is_action_pressed("p2_up")   or Input.is_action_pressed("ui_up")   or Input.is_action_pressed("rg35xxh_right_up") or Input.is_action_pressed("rg_r1") or Input.is_action_pressed("rg_test_p2_up"):
		p2_move -= PADDLE_SPEED
	if Input.is_action_pressed("p2_down") or Input.is_action_pressed("ui_down") or Input.is_action_pressed("rg35xxh_right_down") or Input.is_action_pressed("rg_r2") or Input.is_action_pressed("rg_test_p2_down"):
		p2_move += PADDLE_SPEED
	if p2_dash_timer > 0.0:
		p2_move += p2_dash_vel
		p2_dash_timer -= delta
	paddle2.position.y = clamp(paddle2.position.y + p2_move * delta, 0.0, SCREEN_H - PADDLE_H)

	# Move ball
	ball.position += ball_vel * delta

	# Bounce off top / bottom
	if ball.position.y <= 0.0:
		ball.position.y = 0.0
		ball_vel.y = abs(ball_vel.y)
	if ball.position.y + BALL_SIZE >= SCREEN_H:
		ball.position.y = SCREEN_H - BALL_SIZE
		ball_vel.y = -abs(ball_vel.y)

	var ball_rect := Rect2(ball.position, ball.size)

	# Paddle 1 collision
	if ball_vel.x < 0 and ball_rect.intersects(Rect2(paddle1.position, paddle1.size)):
		ball.position.x = paddle1.position.x + PADDLE_W
		ball_vel.x = abs(ball_vel.x)
		var rel := (ball.position.y + BALL_SIZE / 2.0 - paddle1.position.y) / PADDLE_H
		ball_vel.y = (rel - 0.5) * BALL_SPEED * 1.6
		sfx_hit.play()

	# Paddle 2 collision
	if ball_vel.x > 0 and ball_rect.intersects(Rect2(paddle2.position, paddle2.size)):
		ball.position.x = paddle2.position.x - BALL_SIZE
		ball_vel.x = -abs(ball_vel.x)
		var rel := (ball.position.y + BALL_SIZE / 2.0 - paddle2.position.y) / PADDLE_H
		ball_vel.y = (rel - 0.5) * BALL_SPEED * 1.6
		sfx_hit.play()

	# Scoring
	if ball.position.x + BALL_SIZE < 0:
		score[1] += 1
		_check_winner()
		if not game_over:
			_reset_ball(1)
	elif ball.position.x > SCREEN_W:
		score[0] += 1
		_check_winner()
		if not game_over:
			_reset_ball(-1)

	_update_score_label()


func _check_winner() -> void:
	var limit := Global.score_limit
	if score[0] >= limit:
		_show_game_over("PLAYER 2 WINS!")  # P1 scored out, P2 wins
	elif score[1] >= limit:
		_show_game_over("PLAYER 1 WINS!")  # P2 scored out, P1 wins


func _show_game_over(text: String) -> void:
	game_over = true
	ball.visible = false
	game_over_overlay.visible = true
	result_label.text = text
	result_label.modulate = Color.YELLOW
	result_label.visible = true
	continue_label.visible = true
	sfx_gameover.play()


func _update_score_label() -> void:
	score_label.text = "%d   :   %d  (first to %d loses)" % [score[0], score[1], Global.score_limit]
	score_label.add_theme_font_size_override("font_size", 28)


func _process_menu_back() -> void:
	if Input.is_action_just_pressed("menu_back"):
		get_tree().change_scene_to_file("res://menu.tscn")


func _reset_ball(direction: int) -> void:
	ball.position = Vector2(SCREEN_W / 2.0 - BALL_SIZE / 2.0, SCREEN_H / 2.0 - BALL_SIZE / 2.0)
	ball_vel = Vector2(BALL_SPEED * direction, randf_range(-180.0, 180.0))


# --- Sound synthesis helpers ---

# Generates a single sine-wave tone as an AudioStreamWAV.
func _make_tone(frequency: float, duration: float, volume: float = 0.6) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		# Quick fade-out to prevent clicks at the end
		var envelope := 1.0 - float(i) / float(num_samples)
		var sample := sin(TAU * frequency * t) * volume * envelope
		var pcm := clampi(int(sample * 32767), -32768, 32767)
		data[i * 2]     = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	return stream


# Generates a three-note descending game-over jingle (C5 -> G4 -> C4).
func _make_gameover_sound() -> AudioStreamWAV:
	var notes := [523.25, 392.0, 261.63]  # C5, G4, C4
	var note_dur := 0.22
	var sample_rate := 22050
	var samps := int(sample_rate * note_dur)
	var data := PackedByteArray()
	data.resize(samps * notes.size() * 2)
	var volume := 0.6
	for n in range(notes.size()):
		var freq: float = notes[n]
		for i in range(samps):
			var idx := n * samps + i
			var t := float(i) / float(sample_rate)
			var envelope := 1.0 - float(i) / float(samps)
			var sample := sin(TAU * freq * t) * volume * envelope
			var pcm := clampi(int(sample * 32767), -32768, 32767)
			data[idx * 2]     = pcm & 0xFF
			data[idx * 2 + 1] = (pcm >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.data = data
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	return stream
