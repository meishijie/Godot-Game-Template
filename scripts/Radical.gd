extends RigidBody2D
class_name Radical

signal synthesis_prepared(other_radical : Node)
signal absorb_finished

enum Type {
	WATER,
	FIRE,
	WOOD,
	STONE,
}

enum EnvironmentState {
	LICHUN,
	DAHAN,
}

const RADICAL_COLLISION_LAYER : int = 1 << 5
const RADICAL_COLLISION_MASK : int = 1 << 5
const LICHUN_WOOD_GROWTH_RATE : float = 0.1
const LICHUN_WOOD_GROWTH_CAP : float = 1.1

@export var radical_type : Type = Type.WATER
@export_range(0.1, 3.0, 0.1) var stick_hold_seconds : float = 1.0
@export_range(0.05, 2.0, 0.05) var absorb_duration : float = 0.25
@export var absorb_on_prepare : bool = true

@onready var _area_2d : Area2D = $Area2D

var _overlap_elapsed : Dictionary = {}
var _overlap_bodies : Dictionary = {}
var _prepared_targets : Dictionary = {}
var _absorb_tween : Tween
var _environment_state : EnvironmentState = EnvironmentState.LICHUN
var _base_stick_hold_seconds : float = 1.0
var _base_absorb_duration : float = 0.25
var _base_environment_initialized : bool = false

func _ready() -> void:
	collision_layer = RADICAL_COLLISION_LAYER
	collision_mask = RADICAL_COLLISION_MASK
	_area_2d.collision_layer = 0
	_area_2d.collision_mask = RADICAL_COLLISION_MASK
	_area_2d.monitoring = true
	_area_2d.monitorable = false
	_ensure_base_environment_parameters()
	_apply_type_physics()

func _physics_process(delta : float) -> void:
	if _overlap_elapsed.is_empty():
		return
	for body_id in _overlap_elapsed.keys():
		var body : Node = _overlap_bodies.get(body_id)
		if not is_instance_valid(body):
			_clear_overlap_for_id(body_id)
			continue
		var elapsed : float = _overlap_elapsed[body_id]
		elapsed += delta
		_overlap_elapsed[body_id] = elapsed
		if elapsed >= stick_hold_seconds and not _prepared_targets.has(body_id):
			_prepared_targets[body_id] = true
			synthesis_prepared.emit(body)
			_try_absorb_pair(body)

func get_radical_type() -> Type:
	return radical_type

func absorb_to(target_position : Vector2) -> void:
	if _absorb_tween != null and _absorb_tween.is_valid():
		_absorb_tween.kill()
	freeze = true
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	_absorb_tween = create_tween()
	_absorb_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_absorb_tween.tween_property(self, "global_position", target_position, absorb_duration)
	_absorb_tween.finished.connect(_on_absorb_tween_finished, CONNECT_ONE_SHOT)

func apply_environment_state(new_state : int) -> void:
	_ensure_base_environment_parameters()
	_environment_state = _sanitize_environment_state(new_state)
	_apply_type_physics()

func _on_area_2d_body_entered(body : Node) -> void:
	if body == self:
		return
	if not body is RigidBody2D:
		return
	if not _can_prepare_with(body):
		return
	var body_id := body.get_instance_id()
	_overlap_elapsed[body_id] = 0.0
	_overlap_bodies[body_id] = body
	_prepared_targets.erase(body_id)

func _on_area_2d_body_exited(body : Node) -> void:
	if body == self:
		return
	_clear_overlap_for_id(body.get_instance_id())

func _can_prepare_with(body : Node) -> bool:
	if not body.has_method("get_radical_type"):
		return false
	var other_type : Type = body.call("get_radical_type")
	if radical_type == Type.WATER and other_type == Type.FIRE:
		return true
	if radical_type == Type.FIRE and other_type == Type.WATER:
		return true
	return radical_type == other_type

func _try_absorb_pair(body : Node) -> void:
	if not absorb_on_prepare:
		return
	if not body is Node2D:
		return
	if get_instance_id() > body.get_instance_id():
		return
	var midpoint : Vector2 = (global_position + (body as Node2D).global_position) * 0.5
	absorb_to(midpoint)
	if body.has_method("absorb_to"):
		body.call_deferred("absorb_to", midpoint)

func _apply_type_physics() -> void:
	_ensure_base_environment_parameters()
	match radical_type:
		Type.WATER:
			mass = 1.05
			gravity_scale = 0.85
			linear_damp = 4.8
			angular_damp = 3.0
		Type.FIRE:
			mass = 0.72
			gravity_scale = 0.35
			linear_damp = 1.9
			angular_damp = 1.1
		Type.WOOD:
			mass = 1.35
			gravity_scale = 1.0
			linear_damp = 2.5
			angular_damp = 2.0
		Type.STONE:
			mass = 2.2
			gravity_scale = 1.2
			linear_damp = 5.5
			angular_damp = 4.0
	_apply_environment_modifiers()

func _ensure_base_environment_parameters() -> void:
	if _base_environment_initialized:
		return
	_base_stick_hold_seconds = stick_hold_seconds
	_base_absorb_duration = absorb_duration
	_base_environment_initialized = true

func _sanitize_environment_state(value : int) -> EnvironmentState:
	if value <= EnvironmentState.LICHUN:
		return EnvironmentState.LICHUN
	return EnvironmentState.DAHAN

func _apply_environment_modifiers() -> void:
	stick_hold_seconds = _base_stick_hold_seconds
	absorb_duration = _base_absorb_duration
	match _environment_state:
		EnvironmentState.LICHUN:
			if radical_type == Type.WOOD:
				var growth_factor : float = min(1.0 + LICHUN_WOOD_GROWTH_RATE, LICHUN_WOOD_GROWTH_CAP)
				mass *= growth_factor
			return
		EnvironmentState.DAHAN:
			gravity_scale *= 1.18
			linear_damp *= 1.12
			angular_damp *= 1.12
			stick_hold_seconds = _base_stick_hold_seconds * 1.35
			absorb_duration = _base_absorb_duration * 1.2

func _clear_overlap_for_id(body_id : int) -> void:
	_overlap_elapsed.erase(body_id)
	_overlap_bodies.erase(body_id)
	_prepared_targets.erase(body_id)

func _on_absorb_tween_finished() -> void:
	freeze = false
	absorb_finished.emit()
