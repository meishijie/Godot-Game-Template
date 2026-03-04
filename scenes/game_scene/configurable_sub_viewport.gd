extends SubViewport
## Script to apply the anti-aliasing setting from [PlayerConfig] to a [SubViewport].

const APP_SETTINGS_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/config/app_settings.gd")
const PLAYER_CONFIG_SCRIPT := preload("res://addons/maaacks_game_template/base/nodes/config/player_config.gd")

## The name of the anti-aliasing variable in the [ConfigFile].
@export var anti_aliasing_key : StringName = "Anti-aliasing"
## The name of the section of the anti-aliasing variable in the [ConfigFile].
@export var video_section : StringName = APP_SETTINGS_SCRIPT.VIDEO_SECTION

func _ready() -> void:
	var anti_aliasing : int = PLAYER_CONFIG_SCRIPT.get_config(video_section, anti_aliasing_key, Viewport.MSAA_DISABLED)
	msaa_2d = anti_aliasing as MSAA
	msaa_3d = anti_aliasing as MSAA
