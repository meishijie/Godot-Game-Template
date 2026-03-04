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

const ROCKET_RADIUS := 6.0
const TRAIL_LENGTH := 9
const PARTICLE_COUNT := 26
const PARTICLE_LIFETIME_MIN := 0.35
const PARTICLE_LIFETIME_MAX := 0.75
const PARTICLE_SPEED_MIN := 90.0
const PARTICLE_SPEED_MAX := 300.0
const TYPE_BURST := &"burst"
const TYPE_RING := &"ring"
const TYPE_PALM := &"palm"
const FIREWORK_TYPE_ORDER : Array[StringName] = [TYPE_BURST, TYPE_RING, TYPE_PALM]
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
var _next_firework_type_index : int = 0

@onready var _title_label : Label = %TitleLabel
@onready var _objective_label : Label = %ObjectiveLabel
@onready var _score_label : Label = %ScoreLabel
@onready var _combo_label : Label = %ComboLabel
@onready var _timer_label : Label = %TimerLabel
@onready var _progress_bar : ProgressBar = %ScoreProgressBar
@onready var _hint_label : Label = %HintLabel
@onready var _feedback_label : Label = %FeedbackLabel

func _ready() -> void:
	_rng.randomize()
	_time_left = level_duration_seconds
	_spawn_interval = spawn_interval_base
	_spawn_timer = 0.25
	_title_label.text = level_title
	_objective_label.text = level_description
	_hint_label.text = "Target %d points in %ds. Burst -> Ring -> Palm cycle." % [target_score, int(round(level_duration_seconds))]
	_progress_bar.max_value = max(target_score, 1)
	_update_perfect_line()
	_update_hud()
	resized.connect(_on_resized)
	queue_redraw()

func _on_resized() -> void:
	_update_perfect_line()
	queue_redraw()

func _update_perfect_line() -> void:
	_perfect_line_y = clampf(size.y * perfect_height_ratio, 64.0, max(64.0, size.y - 64.0))

func _unhandled_input(event : InputEvent) -> void:
	if _level_finished:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_try_detonate(mouse_event.position)
	elif event.is_action_pressed(&"ui_accept"):
		_try_detonate(get_global_mouse_position())

func _process(delta : float) -> void:
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
		var trail_limit : int = firework.get("trail_limit", TRAIL_LENGTH)
		trail.push_back(firework["position"])
		if trail.size() > trail_limit:
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
		var drag : float = particle.get("drag", 0.98)
		var gravity_scale : float = particle.get("gravity_scale", 1.0)
		velocity *= drag
		velocity.y += 180.0 * gravity_scale * delta
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
	var firework_type := _next_firework_type()
	var trail : Array[Vector2] = []
	var firework := {
		"position": Vector2(x_position, size.y + 20.0),
		"velocity": Vector2(
			_rng.randf_range(-rocket_drift_strength, rocket_drift_strength),
			-_rng.randf_range(rocket_speed_min, rocket_speed_max)
		),
		"color": _pick_firework_color(firework_type),
		"type": firework_type,
		"trail": trail,
		"trail_limit": _trail_length_for_type(firework_type),
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
	var firework_type : StringName = nearest["type"]
	var score_awarded := _score_for_hit(nearest["position"].y)
	_create_explosion(nearest["position"], nearest["color"], firework_type, score_awarded == 0)
	if score_awarded > 0:
		_combo += 1
		_max_combo = max(_max_combo, _combo)
		var combo_multiplier := 1.0 + minf(combo_bonus_max, float(_combo - 1) * combo_bonus_step)
		var final_score := int(round(score_awarded * combo_multiplier))
		_score += final_score
		var quality_text := "Perfect" if score_awarded == perfect_base_score else "Good"
		_show_feedback("%s [%s] +%d" % [quality_text, _type_label(firework_type), final_score], Color(0.7, 1.0, 0.8, 1.0))
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

func _create_explosion(center : Vector2, color : Color, firework_type : StringName, is_miss : bool) -> void:
	var particle_count := PARTICLE_COUNT
	if is_miss:
		particle_count = int(PARTICLE_COUNT / 2)
	match firework_type:
		TYPE_RING:
			_create_ring_explosion(center, color, particle_count, is_miss)
		TYPE_PALM:
			_create_palm_explosion(center, color, particle_count, is_miss)
		_:
			_create_burst_explosion(center, color, particle_count)

func _next_firework_type() -> StringName:
	if FIREWORK_TYPE_ORDER.is_empty():
		return TYPE_BURST
	var firework_type : StringName = FIREWORK_TYPE_ORDER[_next_firework_type_index % FIREWORK_TYPE_ORDER.size()]
	_next_firework_type_index = (_next_firework_type_index + 1) % FIREWORK_TYPE_ORDER.size()
	return firework_type

func _trail_length_for_type(firework_type : StringName) -> int:
	match firework_type:
		TYPE_RING:
			return TRAIL_LENGTH + 2
		TYPE_PALM:
			return TRAIL_LENGTH + 5
		_:
			return TRAIL_LENGTH

func _type_label(firework_type : StringName) -> String:
	match firework_type:
		TYPE_RING:
			return "Ring"
		TYPE_PALM:
			return "Palm"
		_:
			return "Burst"

func _pick_firework_color(firework_type : StringName) -> Color:
	match firework_type:
		TYPE_RING:
			return Color.from_hsv(_rng.randf_range(0.52, 0.67), _rng.randf_range(0.6, 0.9), _rng.randf_range(0.85, 1.0))
		TYPE_PALM:
			return Color.from_hsv(_rng.randf_range(0.08, 0.16), _rng.randf_range(0.5, 0.82), _rng.randf_range(0.88, 1.0))
		_:
			return Color.from_hsv(_rng.randf_range(0.0, 0.08), _rng.randf_range(0.62, 0.95), _rng.randf_range(0.85, 1.0))

func _create_burst_explosion(center : Vector2, color : Color, particle_count : int) -> void:
	for _i in range(particle_count):
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(PARTICLE_SPEED_MIN, PARTICLE_SPEED_MAX)
		_spawn_particle(
			center,
			Vector2.RIGHT.rotated(angle) * speed,
			color,
			_rng.randf_range(2.5, 5.5),
			1.0,
			0.98
		)

func _create_ring_explosion(center : Vector2, color : Color, particle_count : int, is_miss : bool) -> void:
	var gravity_scale := 1.0 if is_miss else 0.75
	for i in range(particle_count):
		var ratio := float(i) / float(max(particle_count, 1))
		var angle := (ratio * TAU) + _rng.randf_range(-0.08, 0.08)
		var speed := _rng.randf_range(PARTICLE_SPEED_MIN + 55.0, PARTICLE_SPEED_MAX - 40.0)
		_spawn_particle(
			center,
			Vector2.RIGHT.rotated(angle) * speed,
			color.lightened(_rng.randf_range(0.0, 0.24)),
			_rng.randf_range(2.2, 4.2),
			gravity_scale,
			0.985
		)

func _create_palm_explosion(center : Vector2, color : Color, particle_count : int, is_miss : bool) -> void:
	var gravity_scale := 1.75 if not is_miss else 1.3
	for _i in range(particle_count):
		var angle := _rng.randf_range(-PI * 0.86, -PI * 0.14)
		var speed := _rng.randf_range(PARTICLE_SPEED_MIN + 25.0, PARTICLE_SPEED_MAX - 20.0)
		var velocity := Vector2.RIGHT.rotated(angle) * speed
		velocity.x *= 0.58
		_spawn_particle(
			center,
			velocity,
			color.darkened(_rng.randf_range(0.0, 0.2)),
			_rng.randf_range(2.4, 4.8),
			gravity_scale,
			0.97
		)

func _spawn_particle(
	center : Vector2,
	velocity : Vector2,
	color : Color,
	size : float,
	gravity_scale : float,
	drag : float
) -> void:
	var life := _rng.randf_range(PARTICLE_LIFETIME_MIN, PARTICLE_LIFETIME_MAX)
	_particles.push_back({
		"position": center,
		"velocity": velocity,
		"life": life,
		"max_life": life,
		"size": size,
		"color": color,
		"gravity_scale": gravity_scale,
		"drag": drag,
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

func _draw_firework_body(position : Vector2, color : Color, firework_type : StringName) -> void:
	match firework_type:
		TYPE_RING:
			draw_rect(
				Rect2(
					position - Vector2(ROCKET_RADIUS, ROCKET_RADIUS),
					Vector2(ROCKET_RADIUS * 2.0, ROCKET_RADIUS * 2.0)
				),
				color,
				true
			)
		TYPE_PALM:
			draw_colored_polygon(
				PackedVector2Array([
					position + Vector2(0.0, -ROCKET_RADIUS - 1.0),
					position + Vector2(ROCKET_RADIUS + 1.0, 0.0),
					position + Vector2(0.0, ROCKET_RADIUS + 1.0),
					position + Vector2(-ROCKET_RADIUS - 1.0, 0.0),
				]),
				color
			)
		_:
			draw_circle(position, ROCKET_RADIUS, color)

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
		var firework_type : StringName = firework["type"]
		var trail_width := 2.0
		var trail_tint := Color(1.0, 1.0, 1.0, 1.0)
		match firework_type:
			TYPE_RING:
				trail_width = 1.6
				trail_tint = Color(0.95, 1.0, 1.0, 1.0)
			TYPE_PALM:
				trail_width = 2.6
				trail_tint = Color(0.92, 0.88, 0.8, 1.0)
		for i in range(1, trail.size()):
			var alpha := float(i) / float(trail.size())
			draw_line(trail[i - 1], trail[i], firework["color"] * trail_tint * Color(1.0, 1.0, 1.0, alpha * 0.6), trail_width)
		_draw_firework_body(firework["position"], firework["color"], firework_type)

	for particle in _particles:
		var life_ratio := clampf(particle["life"] / particle["max_life"], 0.0, 1.0)
		var particle_color : Color = particle["color"]
		particle_color.a = life_ratio
		draw_circle(particle["position"], particle["size"] * life_ratio, particle_color)
