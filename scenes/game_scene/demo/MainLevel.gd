extends Control
class_name MainLevel

signal level_lost
signal level_won(level_path : String)

const RADICAL_SCRIPT := preload("res://scripts/Radical.gd")
const RADICAL_TYPE_NAMES : PackedStringArray = ["WATER", "FIRE", "WOOD", "STONE"]

enum EnvironmentState {
	LICHUN,
	DAHAN,
}

@export_file("*.tscn") var next_level_path : String = ""
@export var word_data : Resource
@export var starter_word_scene : PackedScene
@export var radical_scene : PackedScene
@export_range(8.0, 180.0, 1.0) var word_click_radius : float = 64.0
@export_range(8.0, 200.0, 1.0) var synthesis_cluster_radius : float = 84.0
@export_range(20.0, 320.0, 1.0) var configured_split_impulse_strength : float = 120.0
@export var initial_environment_state : EnvironmentState = EnvironmentState.LICHUN
@export var auto_switch_environment : bool = true
@export_range(1.0, 120.0, 0.5) var environment_switch_interval_seconds : float = 12.0
@export_flags_2d_physics var radical_collision_layer : int = 1 << 5
@export_flags_2d_physics var radical_collision_mask : int = 1 << 5
@export_flags_2d_physics var floor_collision_layer : int = 1 << 5
@export_flags_2d_physics var floor_collision_mask : int = 1 << 5
@export var default_split_types : Array[int] = [
	RADICAL_SCRIPT.Type.WATER,
	RADICAL_SCRIPT.Type.FIRE,
	RADICAL_SCRIPT.Type.FIRE,
]

@onready var _world_root : Node2D = $WorldRoot
@onready var _word_spawn : Marker2D = $WorldRoot/WordSpawn
@onready var _floor : StaticBody2D = $WorldRoot/Floor
@onready var _hint_label : Label = $Hint

var _pending_radical_types : Array[int] = []
var _consumed_radical_ids : Dictionary = {}
var _current_environment_state : EnvironmentState = EnvironmentState.LICHUN
var _environment_elapsed_seconds : float = 0.0

func _ready() -> void:
	_current_environment_state = _sanitize_environment_state(int(initial_environment_state))
	_environment_elapsed_seconds = 0.0
	_floor.collision_layer = floor_collision_layer
	_floor.collision_mask = floor_collision_mask
	_world_root.child_entered_tree.connect(_on_world_root_child_entered_tree)
	_connect_existing_radicals()
	_spawn_starter_word()
	_set_hint("Click the word to split. Keep radicals overlapping to synthesize.")

func _process(delta : float) -> void:
	if not auto_switch_environment:
		return
	_environment_elapsed_seconds += delta
	if _environment_elapsed_seconds < environment_switch_interval_seconds:
		return
	_environment_elapsed_seconds = 0.0
	_toggle_environment_state()

func _input(event : InputEvent) -> void:
	var mouse_event : InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not mouse_event.pressed:
		return
	var target_word : Node2D = _pick_word_at_position(mouse_event.position)
	if target_word == null:
		return
	_prepare_pending_split_types()
	_configure_word_for_split(target_word)
	target_word.call("split")
	_set_hint("Word split: overlap radicals for more than 1s to synthesize.")

func request_level_lost() -> void:
	level_lost.emit()

func request_level_won() -> void:
	level_won.emit(next_level_path)

func _spawn_starter_word() -> void:
	var scene_to_spawn : PackedScene = _resolve_initial_word_scene()
	if scene_to_spawn == null:
		return
	var instance := scene_to_spawn.instantiate()
	if not (instance is Node2D):
		instance.queue_free()
		return
	var word_node := instance as Node2D
	_world_root.add_child(word_node)
	word_node.global_position = _word_spawn.global_position
	_configure_word_for_split(word_node)

func _resolve_initial_word_scene() -> PackedScene:
	if word_data != null and word_data.has_method("get_initial_word_scene"):
		var resolved_scene : Variant = word_data.call("get_initial_word_scene")
		if resolved_scene is PackedScene:
			return resolved_scene as PackedScene
	return starter_word_scene

func _pick_word_at_position(position : Vector2) -> Node2D:
	var picked : Node2D
	var best_distance : float = word_click_radius + 0.001
	for child in _world_root.get_children():
		if not (child is Node2D):
			continue
		var candidate := child as Node2D
		if not candidate.has_method("split"):
			continue
		var distance : float = candidate.global_position.distance_to(position)
		if distance > word_click_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			picked = candidate
	return picked

func _prepare_pending_split_types() -> void:
	for radical_type in default_split_types:
		_pending_radical_types.append(radical_type)

func _configure_word_for_split(word_node : Node2D) -> void:
	if radical_scene == null:
		return
	var split_count : int = max(default_split_types.size(), 1)
	var radical_scenes : Array[PackedScene] = []
	for _index in split_count:
		radical_scenes.append(radical_scene)
	_set_property_if_exists(word_node, "radicals_inside", radical_scenes)
	_set_property_if_exists(word_node, "split_impulse_strength", configured_split_impulse_strength)

func _set_property_if_exists(target : Object, property_name : StringName, value : Variant) -> void:
	for property_data in target.get_property_list():
		var current_name : Variant = property_data.get("name")
		if current_name == property_name:
			target.set(property_name, value)
			return

func _connect_existing_radicals() -> void:
	for child in _world_root.get_children():
		if _is_radical_node(child):
			_register_radical(child)

func _on_world_root_child_entered_tree(node : Node) -> void:
	if not _is_radical_node(node):
		return
	_register_radical(node)

func _is_radical_node(node : Node) -> bool:
	if not node.has_signal("synthesis_prepared"):
		return false
	return node.has_method("get_radical_type")

func _register_radical(radical : Node) -> void:
	var handler := Callable(self, "_on_radical_synthesis_prepared").bind(radical)
	if not radical.is_connected("synthesis_prepared", handler):
		radical.connect("synthesis_prepared", handler)
	if radical is CollisionObject2D:
		var body := radical as CollisionObject2D
		body.collision_layer = radical_collision_layer
		body.collision_mask = radical_collision_mask
	var radical_area := radical.get_node_or_null("Area2D")
	if radical_area is Area2D:
		var area := radical_area as Area2D
		area.collision_layer = 0
		area.collision_mask = radical_collision_mask
	if not _pending_radical_types.is_empty():
		var assigned_type : Variant = _pending_radical_types.pop_front()
		radical.set("radical_type", assigned_type)
		if radical.has_method("_apply_type_physics"):
			radical.call("_apply_type_physics")
	_apply_environment_to_radical(radical)

func _on_radical_synthesis_prepared(other_radical : Node, source_radical : Node) -> void:
	if not is_instance_valid(source_radical):
		return
	if not is_instance_valid(other_radical):
		return
	if _is_consumed(source_radical) or _is_consumed(other_radical):
		return
	var source_2d := source_radical as Node2D
	var other_2d := other_radical as Node2D
	if source_2d == null or other_2d == null:
		return
	var candidate_radicals : Array[Node] = _collect_candidate_radicals(source_2d, other_2d)
	var match : Dictionary = _find_recipe_match(candidate_radicals)
	if match.is_empty():
		_set_hint("No recipe for %s" % _build_signature(candidate_radicals))
		return
	var result_scene : PackedScene = match["result_scene"] as PackedScene
	var radicals_to_consume : Array[Node] = match["radicals"] as Array[Node]
	var recipe_key : String = match["recipe_key"]
	_consume_and_spawn(radicals_to_consume, result_scene)
	_set_hint("Synthesis success: %s" % recipe_key)

func _collect_candidate_radicals(source : Node2D, other : Node2D) -> Array[Node]:
	var candidates : Array[Node] = [source, other]
	var center : Vector2 = (source.global_position + other.global_position) * 0.5
	for child in _world_root.get_children():
		if not _is_radical_node(child):
			continue
		if _is_consumed(child):
			continue
		if child == source or child == other:
			continue
		if not (child is Node2D):
			continue
		var candidate := child as Node2D
		if candidate.global_position.distance_to(center) <= synthesis_cluster_radius:
			candidates.append(candidate)
	return candidates

func _find_recipe_match(radicals : Array[Node]) -> Dictionary:
	var recipes : Dictionary = _get_recipe_dictionary()
	if recipes.is_empty():
		return {}
	var buckets : Dictionary = {}
	for radical in radicals:
		var token := _get_radical_token(radical)
		if token.is_empty():
			continue
		if not buckets.has(token):
			buckets[token] = []
		(buckets[token] as Array).append(radical)
	var recipe_keys : Array[String] = []
	for key_variant in recipes.keys():
		if key_variant is String:
			recipe_keys.append(key_variant)
	recipe_keys.sort_custom(_recipe_sort_descending)
	for recipe_key in recipe_keys:
		var tokens : PackedStringArray = recipe_key.split("+", false)
		var picked : Array[Node] = _pick_radicals_for_tokens(buckets, tokens)
		if picked.is_empty():
			continue
		var result_variant : Variant = recipes.get(recipe_key)
		if result_variant is PackedScene:
			return {
				"recipe_key": recipe_key,
				"result_scene": result_variant,
				"radicals": picked,
			}
	return {}

func _pick_radicals_for_tokens(buckets : Dictionary, tokens : PackedStringArray) -> Array[Node]:
	if tokens.is_empty():
		return []
	var copied : Dictionary = {}
	for token in buckets.keys():
		copied[token] = (buckets[token] as Array).duplicate()
	var picked : Array[Node] = []
	for token in tokens:
		var bucket_variant : Variant = copied.get(token)
		if not (bucket_variant is Array):
			return []
		var bucket : Array = bucket_variant as Array
		if bucket.is_empty():
			return []
		var picked_radical : Variant = bucket.pop_back()
		if picked_radical is Node:
			picked.append(picked_radical as Node)
		copied[token] = bucket
	return picked

func _recipe_sort_descending(a : String, b : String) -> bool:
	var a_count : int = a.split("+", false).size()
	var b_count : int = b.split("+", false).size()
	if a_count == b_count:
		return a < b
	return a_count > b_count

func _consume_and_spawn(radicals : Array[Node], result_scene : PackedScene) -> void:
	if result_scene == null:
		return
	var spawn_position := Vector2.ZERO
	var counted : int = 0
	for radical in radicals:
		if not is_instance_valid(radical):
			continue
		_consumed_radical_ids[radical.get_instance_id()] = true
		if radical is Node2D:
			spawn_position += (radical as Node2D).global_position
			counted += 1
	if counted == 0:
		return
	spawn_position /= float(counted)
	for radical in radicals:
		if is_instance_valid(radical):
			radical.queue_free()
	var instance := result_scene.instantiate()
	if not (instance is Node2D):
		instance.queue_free()
		return
	var result_word := instance as Node2D
	_world_root.add_child(result_word)
	result_word.global_position = spawn_position
	_configure_word_for_split(result_word)
	_prune_consumed_ids()

func _get_recipe_dictionary() -> Dictionary:
	if word_data == null:
		return {}
	var recipes_variant : Variant = word_data.get("synthesis_recipes")
	if recipes_variant is Dictionary:
		return recipes_variant as Dictionary
	return {}

func _get_radical_token(radical : Node) -> String:
	if not radical.has_method("get_radical_type"):
		return ""
	var type_value : Variant = radical.call("get_radical_type")
	if not (type_value is int):
		return ""
	var index : int = type_value
	if index < 0 or index >= RADICAL_TYPE_NAMES.size():
		return ""
	return RADICAL_TYPE_NAMES[index]

func _build_signature(radicals : Array[Node]) -> String:
	var tokens : Array[String] = []
	for radical in radicals:
		var token := _get_radical_token(radical)
		if not token.is_empty():
			tokens.append(token)
	tokens.sort()
	if tokens.is_empty():
		return "EMPTY"
	return "+".join(tokens)

func _is_consumed(radical : Node) -> bool:
	return _consumed_radical_ids.has(radical.get_instance_id())

func _prune_consumed_ids() -> void:
	var to_remove : Array[int] = []
	for object_id_variant in _consumed_radical_ids.keys():
		if not (object_id_variant is int):
			continue
		var object_id : int = object_id_variant
		if instance_from_id(object_id) == null:
			to_remove.append(object_id)
	for object_id in to_remove:
		_consumed_radical_ids.erase(object_id)

func _set_hint(message : String) -> void:
	_hint_label.text = "[%s] %s" % [_get_environment_state_name(_current_environment_state), message]

func _toggle_environment_state() -> void:
	if _current_environment_state == EnvironmentState.LICHUN:
		_set_environment_state(EnvironmentState.DAHAN, true)
		return
	_set_environment_state(EnvironmentState.LICHUN, true)

func _set_environment_state(next_state : int, announce_switch : bool) -> void:
	_current_environment_state = _sanitize_environment_state(next_state)
	_apply_environment_to_existing_radicals()
	if announce_switch:
		_set_hint("Season switched to %s." % _get_environment_state_name(_current_environment_state))

func _apply_environment_to_existing_radicals() -> void:
	for child in _world_root.get_children():
		if _is_radical_node(child):
			_apply_environment_to_radical(child)

func _apply_environment_to_radical(radical : Node) -> void:
	if radical.has_method("apply_environment_state"):
		radical.call("apply_environment_state", int(_current_environment_state))

func _sanitize_environment_state(value : int) -> EnvironmentState:
	if value <= EnvironmentState.LICHUN:
		return EnvironmentState.LICHUN
	return EnvironmentState.DAHAN

func _get_environment_state_name(value : EnvironmentState) -> String:
	if value == EnvironmentState.DAHAN:
		return "DAHAN"
	return "LICHUN"
