extends Node

const GLOBAL_STATE_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/state/global_state.gd")
const APP_SETTINGS_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/config/app_settings.gd")

@export_group("Scenes")
@export_file("*.tscn") var main_menu_scene_path : String
@export_file("*.tscn") var game_scene_path : String
@export_file("*.tscn") var ending_scene_path : String

func _ready() -> void:
	GLOBAL_STATE_SCRIPT.open()
	APP_SETTINGS_SCRIPT.set_from_config_and_window(get_window())
