extends Control

const APP_SETTINGS_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/config/app_settings.gd")
const OPTION_CONTROL_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/menus/options_menu/option_control/option_control.gd")

## Scene for adjusting the volume of the audio busses.
@export var audio_control_scene : PackedScene
## Optional names of audio busses that should be ignored.
@export var hide_busses : Array[String]

@onready var mute_control = %MuteControl

func _on_bus_changed(bus_value : float, bus_iter : int) -> void:
	APP_SETTINGS_SCRIPT.set_bus_volume(bus_iter, bus_value)

func _add_audio_control(bus_name : String, bus_value : float, bus_iter : int) -> void:
	if audio_control_scene == null or bus_name in hide_busses or bus_name.begins_with(APP_SETTINGS_SCRIPT.SYSTEM_BUS_NAME_PREFIX):
		return
	var audio_control = audio_control_scene.instantiate()
	%AudioControlContainer.call_deferred("add_child", audio_control)
	if audio_control is OPTION_CONTROL_SCRIPT:
		audio_control.option_section = OPTION_CONTROL_SCRIPT.OptionSections.AUDIO
		audio_control.option_name = bus_name
		audio_control.value = bus_value
		audio_control.connect("setting_changed", _on_bus_changed.bind(bus_iter))

func _add_audio_bus_controls() -> void:
	for bus_iter in AudioServer.bus_count:
		var bus_name : String = APP_SETTINGS_SCRIPT.get_audio_bus_name(bus_iter)
		var linear : float = APP_SETTINGS_SCRIPT.get_bus_volume(bus_iter)
		_add_audio_control(bus_name, linear, bus_iter)

func _update_ui() -> void:
	_add_audio_bus_controls()
	mute_control.value = APP_SETTINGS_SCRIPT.is_muted()

func _ready() -> void:
	_update_ui()

func _on_mute_control_setting_changed(value : bool) -> void:
	APP_SETTINGS_SCRIPT.set_mute(value)
