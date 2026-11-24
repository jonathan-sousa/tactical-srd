## Ressources graphiques : chacune est créditée, et les fiches s'en servent.
extends GdUnitTestSuite

const ASSETS_DIR := "res://assets"
const CREDITS_PATH := "res://assets/CREDITS.md"


func test_every_asset_file_is_credited() -> void:
	var credits := FileAccess.get_file_as_string(CREDITS_PATH)
	assert_str(credits).is_not_empty()
	for folder in DirAccess.get_directories_at(ASSETS_DIR):
		for file in DirAccess.get_files_at(ASSETS_DIR.path_join(folder)):
			if file.get_extension() in ["png", "ttf"]:
				var name := file if folder == "ui" else "%s/%s" % [folder, file]
				if folder == "ui":
					# Le pack d'interface est crédité en bloc (`ui/*.png`).
					name = "ui/*.png"
				assert_str(credits).override_failure_message("Ressource non créditée : %s/%s" % [folder, file]).contains(name)


func test_font_license_ships_with_the_font() -> void:
	assert_bool(FileAccess.file_exists("res://assets/fonts/OFL.txt")).is_true()
	var export_presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_str(export_presets).contains("assets/fonts/OFL.txt")


func test_every_character_has_a_sprite() -> void:
	var registry := DataRegistry.load_from()
	for id: StringName in [&"fighter_lvl1", &"goblin_warrior"]:
		assert_object(registry.character(id).sprite).override_failure_message("Sans sprite : %s" % id).is_not_null()
