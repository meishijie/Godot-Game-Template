extends Control

signal level_lost
signal level_won(level_path : String)

@export_file("*.tscn") var next_level_path : String

@export_group("Level")
@export var level_title : String = "Fireworks Night"
@export var level_description : String = "Click rockets near the guide line for better scores."
@export var level_duration_seconds : float = 45.0
@export var target_score : int = 4200

@export_group("Spawning")
@export var max_active_fireworks : int = 4
@export var spawn_interval_base : float = 1.05
@export var spawn_interval_floor : float = 0.35
@export var spawn_acceleration : float = 0.012
@export var rocket_speed_min : float = 260.0
@export var rocket_speed_max : float = 420.0
@export var rocket_drift_strength : float = 80.0
@export var rocket_escape_y : float = -48.0

@export_group("Scoring")
@export_range(0.1, 0.9, 0.01) var perfect_height_ratio : float = 0.26
@export var perfect_window_px : float = 26.0
@export var good_window_px : float = 74.0
@export var click_radius_px : float = 80.0
@export var perfect_base_score : int = 220
@export var good_base_score : int = 120
@export var miss_penalty : int = 50
@export var combo_bonus_step : float = 0.2
@export var combo_bonus_max : float = 3.0

@export_group("HUD")
@export var compact_hud : bool = true
@export var show_objective_text : bool = false
@export var show_hint_text : bool = false

const ROCKET_RADIUS := 6.0
const TRAIL_LENGTH := 9
const PARTICLE_COUNT := 26
const PARTICLE_LIFETIME_MIN := 0.35
const PARTICLE_LIFETIME_MAX := 0.75
const PARTICLE_SPEED_MIN := 90.0
const PARTICLE_SPEED_MAX := 300.0
const FEEDBACK_LIFETIME := 0.6
const BACKGROUND_COLOR := Color(0.04, 0.04, 0.1, 1.0)
const BACKGROUND_TOP_COLOR := Color(0.07, 0.05, 0.2, 1.0)

var _rng := RandomNumberGenerator.new()
var _fireworks : Array[Dictionary] = []
var _particles : Array[Dictionary] = []
var _score : int = 0
var _combo : int = 0
var _max_combo : int = 0
var _time_left : float = 0.0
var _spawn_timer : float = 0.0
var _spawn_interval : float = 0.0
var _level_finished : bool = false
var _feedback_time_left : float = 0.0
var _perfect_line_y : float = 0.0
var _left_click_was_pressed : bool = false
var _accept_was_pressed : bool = false

@onready var _title_label : Label = %TitleLabel
@onready var _objective_label : Label = %ObjectiveLabel
@onready var _score_label : Label = %ScoreLabel
@onready var _combo_label : Label = %ComboLabel
@onready var _timer_label : Label = %TimerLabel
@onready var _progress_bar : ProgressBar = %ScoreProgressBar
@onready var _hint_label : Label = %HintLabel
@onready var _feedback_label : Label = %FeedbackLabel
@onready var _hud_margin : MarginContainer = $HUDMargin
@onready var _hud_vbox : VBoxContainer = $HUDMargin/HUDPanel/HUDVBox
@onready var _top_row : HBoxContainer = $HUDMargin/HUDPanel/HUDVBox/TopRow
@onready var _left_vbox : VBoxContainer = $HUDMargin/HUDPanel/HUDVBox/TopRow/LeftVBox
@onready var _right_vbox : VBoxContainer = $HUDMargin/HUDPanel/HUDVBox/TopRow/RightVBox
@onready var _bottom_row : HBoxContainer = $HUDMargin/HUDPanel/HUDVBox/BottomRow

func _ready() -> void:
	_rng.randomize()
	_time_left = level_duration_seconds
	_spawn_interval = spawn_interval_base
	_spawn_timer = 0.25
	_left_click_was_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_accept_was_pressed = Input.is_action_pressed(&"ui_accept")
	_title_label.text = level_title
	_objective_label.text = level_description
	_hint_label.text = "Target %d points in %ds. Left click rockets near the guide line." % [target_score, int(round(level_duration_seconds))]
	_apply_hud_layout()
	_progress_bar.max_value = max(target_score, 1)
	_update_perfect_line()
	_update_hud()
	resized.connect(_on_resized)
	queue_redraw()

func _apply_hud_layout() -> void:
	_objective_label.visible = show_objective_text
	_hint_label.visible = show_hint_text
	if not compact_hud:
		return
	_hud_margin.add_theme_constant_override("margin_left", 12)
	_hud_margin.add_theme_constant_override("margin_top", 12)
	_hud_margin.add_theme_constant_override("margin_right", 12)
	_hud_margin.add_theme_constant_override("margin_bottom", 12)
	_hud_vbox.add_theme_constant_override("separation", 4)
	_top_row.add_theme_constant_override("separation", 10)
	_left_vbox.add_theme_constant_override("separation", 1)
	_right_vbox.add_theme_constant_override("separation", 1)
	_bottom_row.add_theme_constant_override("separation", 8)
	_title_label.add_theme_font_size_override("font_size", 22)
	_feedback_label.add_theme_font_size_override("font_size", 18)
	_progress_bar.custom_minimum_size = Vector2(_progress_bar.custom_minimum_size.x, 10.0)

func _on_resized() -> void:
	_update_perfect_line()
	queue_redraw()

func _update_perfect_line() -> void:
	_perfect_line_y = clampf(size.y * perfect_height_ratio, 64.0, max(64.0, size.y - 64.0))

func _update_click_input() -> void:
	var left_click_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var accept_pressed := Input.is_action_pressed(&"ui_accept")
	if _level_finished:
		_left_click_was_pressed = left_click_pressed
		_accept_was_pressed = accept_pressed
		return
	if left_click_pressed and not _left_click_was_pressed:
		_try_detonate(get_local_mouse_position())
	elif accept_pressed and not _accept_was_pressed:
		_try_detonate(get_local_mouse_position())
	_left_click_was_pressed = left_click_pressed
	_accept_was_pressed = accept_pressed

func _process(delta : float) -> void:
	_update_click_input()
	_update_timers(delta)
	_update_fireworks(delta)
	_update_particles(delta)
	_update_feedback(delta)
	queue_redraw()

func _update_timers(delta : float) -> void:
	if _level_finished:
		return
	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		_finish_level()
		return
	_spawn_interval = maxf(spawn_interval_floor, spawn_interval_base - ((level_duration_seconds - _time_left) * spawn_acceleration))
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _get_active_fireworks_count() < max_active_fireworks:
		_spawn_firework()
		_spawn_timer = maxf(0.18, _spawn_interval + _rng.randf_range(-0.15, 0.2))
	_update_hud()

func _update_fireworks(delta : float) -> void:
	for firework in _fireworks:
		if not firework["alive"]:
			continue
		firework["position"] += firework["velocity"] * delta
		firework["age"] += delta
		var trail : Array[Vector2] = firework["trail"]
		trail.push_back(firework["position"])
		if trail.size() > TRAIL_LENGTH:
			trail.pop_front()
		if firework["position"].y < rocket_escape_y:
			firework["alive"] = false
			_register_miss("Escaped")
	_fireworks = _fireworks.filter(func(firework : Dictionary) -> bool: return firework["alive"])

func _update_particles(delta : float) -> void:
	for particle in _particles:
		particle["life"] -= delta
		if particle["life"] <= 0.0:
			continue
		var velocity : Vector2 = particle["velocity"]
		velocity *= 0.98
		velocity.y += 180.0 * delta
		particle["velocity"] = velocity
		particle["position"] += velocity * delta
	_particles = _particles.filter(func(particle : Dictionary) -> bool: return particle["life"] > 0.0)

func _update_feedback(delta : float) -> void:
	if _feedback_time_left <= 0.0:
		return
	_feedback_time_left = maxf(0.0, _feedback_time_left - delta)
	var color : Color = _feedback_label.modulate
	color.a = _feedback_time_left / FEEDBACK_LIFETIME
	_feedback_label.modulate = color

func _get_active_fireworks_count() -> int:
	var count := 0
	for firework in _fireworks:
		if firework["alive"]:
			count += 1
	return count

func _spawn_firework() -> void:
	var margin := 56.0
	var x_position := _rng.randf_range(margin, max(margin, size.x - margin))
	var trail : Array[Vector2] = []
	var firework := {
		"position": Vector2(x_position, size.y + 20.0),
		"velocity": Vector2(
			_rng.randf_range(-rocket_drift_strength, rocket_drift_strength),
			-_rng.randf_range(rocket_speed_min, rocket_speed_max)
		),
		"color": Color.from_hsv(_rng.randf(), _rng.randf_range(0.6, 0.9), _rng.randf_range(0.85, 1.0)),
		"trail": trail,
		"alive": true,
		"age": 0.0,
	}
	_fireworks.push_back(firework)

func _try_detonate(click_position : Vector2) -> void:
	var nearest : Dictionary = {}
	var nearest_distance_sq := click_radius_px * click_radius_px
	for firework in _fireworks:
		if not firework["alive"]:
			continue
		var distance_sq := click_position.distance_squared_to(firework["position"])
		if distance_sq <= nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = firework
	if nearest.is_empty():
		_register_miss("Whiff")
		return
	nearest["alive"] = false
	var score_awarded := _score_for_hit(nearest["position"].y)
	_create_explosion(nearest["position"], nearest["color"], score_awarded == 0)
	if score_awarded > 0:
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var combo_multiplier := 1.0 + minf(combo_bonus_max, float(_combo - 1) * combo_bonus_step)
		var final_score := int(round(score_awarded * combo_multiplier))
		_score += final_score
		var quality_text := "Perfect" if score_awarded == perfect_base_score else "Good"
		_show_feedback("%s +%d" % [quality_text, final_score], Color(0.7, 1.0, 0.8, 1.0))
	else:
		_register_miss("Miss")
	_update_hud()

func _score_for_hit(position_y : float) -> int:
	var distance_to_line := absf(position_y - _perfect_line_y)
	if distance_to_line <= perfect_window_px:
		return perfect_base_score
	if distance_to_line <= good_window_px:
		return good_base_score
	return 0

func _register_miss(reason : String) -> void:
	_combo = 0
	_score = max(0, _score - miss_penalty)
	_show_feedback("%s -%d" % [reason, miss_penalty], Color(1.0, 0.65, 0.65, 1.0))
	_update_hud()

func _show_feedback(text : String, color : Color) -> void:
	_feedback_label.text = text
	_feedback_label.modulate = color
	_feedback_time_left = FEEDBACK_LIFETIME

func _create_explosion(center : Vector2, color : Color, is_miss : bool) -> void:
	var particle_count := PARTICLE_COUNT
	if is_miss:
		particle_count = int(PARTICLE_COUNT / 2)
	for i in particle_count:
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
		_particles.push_back({
			"position": center,
			"velocity": Vector2.RIGHT.rotated(angle) * speed,
			"life": _rng.randf_range(PARTICLE_LIFETIME_MIN, PARTICLE_LIFETIME_MAX),
			"max_life": PARTICLE_LIFETIME_MAX,
			"size": _rng.randf_range(2.5, 5.5),
			"color": color,
		})

func _finish_level() -> void:
	if _level_finished:
		return
	_level_finished = true
	var won := _score >= target_score
	if won:
		_show_feedback("Target reached! Combo max x%d" % _max_combo, Color(0.8, 1.0, 0.85, 1.0))
	else:
		_show_feedback("Target missed. Needed %d." % target_score, Color(1.0, 0.72, 0.72, 1.0))
	await get_tree().create_timer(0.75).timeout
	if won:
		level_won.emit(next_level_path)
	else:
		level_lost.emit()

func _update_hud() -> void:
	_score_label.text = "Score: %d / %d" % [_score, target_score]
	_combo_label.text = "Combo: x%d" % _combo
	_timer_label.text = "Time: %02d" % int(ceil(_time_left))
	_progress_bar.value = min(_score, target_score)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.45)), BACKGROUND_TOP_COLOR, true)
	var good_rect := Rect2(Vector2(0.0, _perfect_line_y - good_window_px), Vector2(size.x, good_window_px * 2.0))
	var perfect_rect := Rect2(Vector2(0.0, _perfect_line_y - perfect_window_px), Vector2(size.x, perfect_window_px * 2.0))
	draw_rect(good_rect, Color(0.35, 0.5, 0.95, 0.12), true)
	draw_rect(perfect_rect, Color(0.2, 0.95, 0.9, 0.2), true)
	draw_line(Vector2(0.0, _perfect_line_y), Vector2(size.x, _perfect_line_y), Color(0.82, 1.0, 1.0, 0.85), 2.0)

	for firework in _fireworks:
		var trail : Array[Vector2] = firework["trail"]
		for i in range(1, trail.size()):
			var alpha := float(i) / float(trail.size())
			draw_line(trail[i - 1], trail[i], firework["color"] * Color(1, 1, 1, alpha * 0.6), 2.0)
		draw_circle(firework["position"], ROCKET_RADIUS, firework["color"])

	for particle in _particles:
		var life_ratio := clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		var particle_color : Color = particle["color"]
		particle_color.a = life_ratio
		draw_circle(particle["position"], particle["size"] * life_ratio, particle_color)
