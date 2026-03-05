extends Control
class_name MainLevel

signal level_lost
signal level_won(level_path : String)

@export_file("*.tscn") var next_level_path : String = ""
@export var word_data : Resource
@export var starter_word_scene : PackedScene
@export var radical_scene : PackedScene

@onready var _world_root : Node2D = $WorldRoot
@onready var _word_spawn : Marker2D = $WorldRoot/WordSpawn

func _ready() -> void:
	_spawn_starter_word()

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

func _resolve_initial_word_scene() -> PackedScene:
	if word_data != null and word_data.has_method("get_initial_word_scene"):
		var resolved_scene : Variant = word_data.call("get_initial_word_scene")
		if resolved_scene is PackedScene:
			return resolved_scene as PackedScene
	return starter_word_scene
