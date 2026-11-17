## Test de fumée du J0 : vérifie que la configuration du projet est celle
## du brief. Si ce test passe en ligne de commande, la chaîne de test marche.
##
## Note gdUnit4 : une suite de tests hérite de GdUnitTestSuite, et chaque
## fonction dont le nom commence par `test_` est un cas de test (comme les
## méthodes `test_*` de Minitest).
extends GdUnitTestSuite


func test_project_name() -> void:
	assert_str(ProjectSettings.get_setting("application/config/name")).is_equal("Projet Phénix")


func test_base_resolution_is_1280x720() -> void:
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_width")).is_equal(1280)
	assert_int(ProjectSettings.get_setting("display/window/size/viewport_height")).is_equal(720)


func test_stretch_settings() -> void:
	assert_str(ProjectSettings.get_setting("display/window/stretch/mode")).is_equal("canvas_items")
	assert_str(ProjectSettings.get_setting("display/window/stretch/aspect")).is_equal("keep")


func test_compatibility_renderer() -> void:
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("gl_compatibility")


func test_untyped_declaration_is_an_error() -> void:
	# 2 = Error dans l'énumération des niveaux d'avertissement GDScript.
	assert_int(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration")).is_equal(2)
