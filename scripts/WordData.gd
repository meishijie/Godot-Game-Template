extends Resource
class_name WordData

@export var initial_word_scene : PackedScene
@export var synthesis_recipes : Dictionary[String, PackedScene] = {}

func get_initial_word_scene() -> PackedScene:
	return initial_word_scene

func get_recipe_result(recipe_key : String) -> PackedScene:
	var result : Variant = synthesis_recipes.get(recipe_key)
	if result is PackedScene:
		return result as PackedScene
	return null
