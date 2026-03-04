extends Control

const GAME_STATE_SCRIPT := preload("res://scripts/game_state.gd")

func _on_ResetGameControl_reset_confirmed() -> void:
	GAME_STATE_SCRIPT.reset()
