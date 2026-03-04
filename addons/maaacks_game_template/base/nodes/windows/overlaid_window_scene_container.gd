@tool
class_name OverlaidWindowContainer
extends "res://addons/maaacks_game_template/base/nodes/windows/overlaid_window.gd"

var instance : Node
@onready var scene_container : Container = %SceneContainer

@export var packed_scene : PackedScene :
	set(value):
		packed_scene = value
		if is_inside_tree():
			for child in scene_container.get_children():
				child.queue_free()
			if packed_scene:
				instance = packed_scene.instantiate()
				scene_container.add_child(instance)

func _ready() -> void:
	packed_scene = packed_scene
