extends Node2D

@export var radicals_inside: Array[PackedScene] = []
@export var split_impulse_strength: float = 300.0
@export var split_seed: int = 1337
@export_range(16.0, 180.0, 1.0) var placeholder_radius: float = 34.0
@export var placeholder_fill_color: Color = Color(0.18, 0.20, 0.32, 1.0)
@export var placeholder_stroke_color: Color = Color(0.95, 0.95, 0.98, 0.95)

var _has_split: bool = false

func _ready() -> void:
	z_index = 1
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, placeholder_radius, placeholder_fill_color)
	draw_arc(Vector2.ZERO, placeholder_radius, 0.0, TAU, 48, placeholder_stroke_color, 2.0, true)
	var cross_half := placeholder_radius * 0.38
	draw_line(Vector2(-cross_half, 0.0), Vector2(cross_half, 0.0), placeholder_stroke_color, 2.0, true)
	draw_line(Vector2(0.0, -cross_half), Vector2(0.0, cross_half), placeholder_stroke_color, 2.0, true)

func split() -> void:
	if _has_split:
		return
	_has_split = true

	var spawn_parent := _resolve_spawn_parent()
	if spawn_parent == null:
		queue_free()
		return

	var valid_scenes := _collect_valid_scenes()
	if valid_scenes.is_empty():
		queue_free()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = split_seed
	var total := valid_scenes.size()

	for index in total:
		var radical_scene: PackedScene = valid_scenes[index]
		var radical_instance := radical_scene.instantiate()
		if not (radical_instance is Node2D):
			continue

		var radical_node := radical_instance as Node2D
		spawn_parent.add_child(radical_node)
		radical_node.global_position = global_position

		var base_angle := TAU * (float(index) / float(total))
		var angle := base_angle + rng.randf_range(-0.8, 0.8)
		var impulse_scale := rng.randf_range(0.85, 1.15)
		var impulse := Vector2.RIGHT.rotated(angle) * split_impulse_strength * impulse_scale
		_apply_impulse(radical_node, impulse)

	queue_free()

func _collect_valid_scenes() -> Array[PackedScene]:
	var valid_scenes: Array[PackedScene] = []
	for radical_scene in radicals_inside:
		if radical_scene != null:
			valid_scenes.append(radical_scene)
	return valid_scenes

func _resolve_spawn_parent() -> Node:
	var parent := get_parent()
	if parent != null:
		return parent
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene

func _apply_impulse(radical_node: Node2D, impulse: Vector2) -> void:
	if radical_node is RigidBody2D:
		(radical_node as RigidBody2D).apply_central_impulse(impulse)
		return
	if radical_node.has_method("apply_central_impulse"):
		radical_node.call("apply_central_impulse", impulse)
