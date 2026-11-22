## Tests de fumée des écrans : chargement sans erreur et état initial.
extends GdUnitTestSuite


func test_title_shows_game_name_and_prompt() -> void:
	var runner := scene_runner("res://scenes/title/title.tscn")
	await runner.simulate_frames(2)
	var scene := runner.scene()
	assert_str((scene.get_node("%TitleLabel") as Label).text).is_equal("Projet Phénix")
	assert_str((scene.get_node("%PressKeyLabel") as Label).text).is_equal(Texts.PRESS_ANY_KEY)


const TEST_SAVE := "user://test_menu_save.json"
const TEST_SETTINGS := "user://test_menu_settings.cfg"

var _real_save_path: String
var _real_settings_path: String


# Les singletons pointent vers des fichiers de test pendant ces tests, pour
# ne jamais lire ni écraser la vraie sauvegarde ou les vraies options.
func before_test() -> void:
	_real_save_path = SaveManager.path
	_real_settings_path = Settings.path
	SaveManager.path = TEST_SAVE
	Settings.path = TEST_SETTINGS
	_remove_test_files()
	SaveManager.reload()


func after_test() -> void:
	_remove_test_files()
	SaveManager.path = _real_save_path
	Settings.path = _real_settings_path
	SaveManager.reload()
	Settings.load_settings()


func _remove_test_files() -> void:
	for file: String in [TEST_SAVE, TEST_SETTINGS]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


func _write_save(text: String) -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	SaveManager.reload()


func test_menu_disables_continue_without_game() -> void:
	assert_bool(GameState.has_game()).is_false()
	var runner := scene_runner("res://scenes/menu/menu.tscn")
	await runner.simulate_frames(2)
	var scene := runner.scene()
	var continue_button: Button = scene.get_node("%ContinueButton")
	assert_bool(continue_button.disabled).is_true()
	assert_str(continue_button.tooltip_text).is_equal(Texts.NO_SAVE)
	assert_bool((scene.get_node("%NewGameButton") as Button).has_focus()).is_true()


func test_defeat_screen_offers_retry_and_menu() -> void:
	var runner := scene_runner("res://scenes/defeat/defeat.tscn")
	await runner.simulate_frames(2)
	var scene := runner.scene()
	assert_str((scene.get_node("%RetryButton") as Button).text).is_equal(Texts.RETRY_COMBAT)
	assert_str((scene.get_node("%MainMenuButton") as Button).text).is_equal(Texts.MAIN_MENU)


func test_escape_opens_and_closes_pause() -> void:
	var dialogue: Control = auto_free(load("res://scenes/dialogue/dialogue.tscn").instantiate())
	dialogue.set("dialogue", DataRegistry.load_from().dialogue(&"intro"))
	var runner := scene_runner(dialogue)
	await runner.simulate_frames(2)
	var pause: CanvasLayer = dialogue.get_node("PauseMenu")

	runner.simulate_key_pressed(KEY_ESCAPE)
	await runner.await_input_processed()
	assert_bool(pause.visible).is_true()
	assert_bool(dialogue.get_tree().paused).is_true()

	pause.call("close")
	assert_bool(pause.visible).is_false()
	assert_bool(dialogue.get_tree().paused).is_false()


func test_menu_enables_continue_with_a_valid_save() -> void:
	_write_save('{"version": 1, "story_step": "goblin_ambush", "player": {"def_id": "fighter_lvl1", "hp_current": 9}}')
	var runner := scene_runner("res://scenes/menu/menu.tscn")
	await runner.simulate_frames(2)
	var continue_button: Button = runner.scene().get_node("%ContinueButton")
	assert_bool(continue_button.disabled).is_false()
	assert_bool(continue_button.has_focus()).is_true()


func test_menu_explains_a_corrupted_save() -> void:
	_write_save("{ cassé")
	var runner := scene_runner("res://scenes/menu/menu.tscn")
	await runner.simulate_frames(2)
	var scene := runner.scene()
	assert_bool((scene.get_node("%ContinueButton") as Button).disabled).is_true()
	assert_str((scene.get_node("%MessageLabel") as Label).text).is_equal(Texts.SAVE_CORRUPT)


func test_menu_explains_an_unknown_version() -> void:
	_write_save('{"version": 42, "story_step": "intro", "player": {"def_id": "fighter_lvl1", "hp_current": 12}}')
	var runner := scene_runner("res://scenes/menu/menu.tscn")
	await runner.simulate_frames(2)
	assert_str((runner.scene().get_node("%MessageLabel") as Label).text).is_equal(Texts.SAVE_UNKNOWN_VERSION)


func test_options_screen_changes_and_saves_volume() -> void:
	var runner := scene_runner("res://scenes/options/options.tscn")
	await runner.simulate_frames(2)
	var slider: HSlider = runner.scene().get_node("%OptionsPanel/%VolumeSlider")
	assert_bool(slider.has_focus()).is_true()
	slider.value = 40
	assert_float(Settings.master_volume).is_equal_approx(0.4, 0.001)
	assert_bool(FileAccess.file_exists(TEST_SETTINGS)).is_true()
	Settings.set_master_volume(1.0)


func test_pause_menu_opens_options_and_escape_comes_back() -> void:
	var dialogue: Control = auto_free(load("res://scenes/dialogue/dialogue.tscn").instantiate())
	dialogue.set("dialogue", DataRegistry.load_from().dialogue(&"intro"))
	var runner := scene_runner(dialogue)
	await runner.simulate_frames(2)
	var pause: CanvasLayer = dialogue.get_node("PauseMenu")
	pause.call("open")
	(pause.get_node("%PauseOptionsButton") as Button).pressed.emit()
	var options_center: Control = pause.get_node("%OptionsCenter")
	assert_bool(options_center.visible).is_true()

	runner.simulate_key_pressed(KEY_ESCAPE)
	await runner.await_input_processed()
	# Échap ferme les options mais laisse la pause ouverte.
	assert_bool(options_center.visible).is_false()
	assert_bool(pause.visible).is_true()
	pause.call("close")
