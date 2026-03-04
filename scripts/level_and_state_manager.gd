extends "res://addons/maaacks_game_template/extras/scripts/level_manager.gd"

const GAME_STATE_SCRIPT := preload("res://scripts/game_state.gd")

func set_current_level_path(value : String) -> void:
	super.set_current_level_path(value)
	GAME_STATE_SCRIPT.set_current_level_path(value)

func set_checkpoint_level_path(value : String) -> void:
	super.set_checkpoint_level_path(value)
	GAME_STATE_SCRIPT.set_checkpoint_level_path(value)

func get_checkpoint_level_path() -> String:
	var state_level_path := GAME_STATE_SCRIPT.get_checkpoint_level_path()
	if not state_level_path.is_empty():
		return state_level_path
	return super.get_checkpoint_level_path()
