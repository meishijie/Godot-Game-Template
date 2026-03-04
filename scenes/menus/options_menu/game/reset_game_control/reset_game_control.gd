extends HBoxContainer

const RESET_STRING := "Reset Game:"
const CONFIRM_STRING := "Confirm Reset:"
const SCENE_LOADER_PATH := ^"/root/SceneLoader"

signal reset_confirmed

func _reload_current_scene() -> void:
	var scene_loader := get_node_or_null(SCENE_LOADER_PATH)
	if scene_loader:
		scene_loader.call("reload_current_scene")

func _on_cancel_button_pressed():
	%CancelButton.hide()
	%ConfirmButton.hide()
	%ResetButton.show()
	%ResetLabel.text = RESET_STRING

func _on_reset_button_pressed():
	%CancelButton.show()
	%ConfirmButton.show()
	%ResetButton.hide()
	%ResetLabel.text = CONFIRM_STRING

func _on_confirm_button_pressed():
	reset_confirmed.emit()
	get_tree().paused = false
	_reload_current_scene()
