## Tests de fumée des écrans : chargement sans erreur et état initial.
extends GdUnitTestSuite


func test_title_shows_game_name_and_prompt() -> void:
	var runner := scene_runner("res://scenes/title/title.tscn")
	await runner.simulate_frames(2)
	var scene := runner.scene()
	assert_str((scene.get_node("%TitleLabel") as Label).text).is_equal("Projet Phénix")
	assert_str((scene.get_node("%PressKeyLabel") as Label).text).is_equal(Texts.PRESS_ANY_KEY)


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
