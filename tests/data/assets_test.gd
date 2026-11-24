## Ressources graphiques : chacune est créditée, et les fiches s'en servent.
extends GdUnitTestSuite

const ASSETS_DIR := "res://assets"
const CREDITS_PATH := "res://assets/CREDITS.md"


func test_every_asset_file_is_credited() -> void:
	var credits := FileAccess.get_file_as_string(CREDITS_PATH)
	assert_str(credits).is_not_empty()
	for path in _asset_files(ASSETS_DIR):
		var relative := path.trim_prefix(ASSETS_DIR + "/")
		# Le pack d'interface est crédité en bloc (`ui/*.png`).
		var name := "ui/*.png" if relative.begins_with("ui/") else relative
		assert_str(credits).override_failure_message("Ressource non créditée : %s" % relative).contains(name)


## Fichiers d'images, de sons et de police, sous-dossiers compris.
func _asset_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.get_extension() in ["png", "ttf", "ogg", "mp3"]:
			found.append(dir_path.path_join(file))
	for sub_dir in DirAccess.get_directories_at(dir_path):
		found.append_array(_asset_files(dir_path.path_join(sub_dir)))
	return found


func test_font_license_ships_with_the_font() -> void:
	assert_bool(FileAccess.file_exists("res://assets/fonts/OFL.txt")).is_true()
	var export_presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_str(export_presets).contains("assets/fonts/OFL.txt")


func test_every_character_has_a_sprite() -> void:
	var registry := DataRegistry.load_from()
	for id: StringName in [&"fighter_lvl1", &"goblin_warrior"]:
		assert_object(registry.character(id).sprite).override_failure_message("Sans sprite : %s" % id).is_not_null()
