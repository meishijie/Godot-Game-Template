extends Node

signal level_lost
signal level_won(level_path : String)
@warning_ignore("unused_signal")
signal level_changed(level_path : String)

## Optional path to the next level if using an open world level system.
@export_file("*.tscn") var next_level_path : String

const GLOBAL_STATE_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/state/global_state.gd")
const GAME_STATE_SCRIPT := preload("res://scripts/game_state.gd")

var level_state

func _on_lose_button_pressed() -> void:
	level_lost.emit()

func _on_win_button_pressed() -> void:
	level_won.emit(next_level_path)

func open_tutorials() -> void:
	%TutorialManager.open_tutorials()
	level_state.tutorial_read = true
	GLOBAL_STATE_SCRIPT.save()

func _ready() -> void:
	level_state = GAME_STATE_SCRIPT.get_level_state(scene_file_path)
	%ColorPickerButton.color = level_state.color
	%BackgroundColor.color = level_state.color
	if not level_state.tutorial_read:
		open_tutorials()

func _on_color_picker_button_color_changed(color : Color) -> void:
	%BackgroundColor.color = color
	level_state.color = color
	GLOBAL_STATE_SCRIPT.save()

func _on_tutorial_button_pressed() -> void:
	open_tutorials()
