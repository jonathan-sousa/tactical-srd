## Boîte de dialogue : texte lettre par lettre, Entrée pour tout afficher
## puis passer à la réplique suivante, signal `finished` à la fin.
extends GdUnitTestSuite

var _runner: GdUnitSceneRunner
var _scene: Control
var _dialogue: DialogueDef


func before_test() -> void:
	_dialogue = DataRegistry.load_from().dialogue(&"intro")
	_scene = auto_free(load("res://scenes/dialogue/dialogue.tscn").instantiate())
	_scene.set("dialogue", _dialogue)
	_runner = scene_runner(_scene)
	await _runner.simulate_frames(2)


func test_first_line_is_typed_letter_by_letter() -> void:
	assert_int(_scene.call("current_index")).is_equal(0)
	assert_bool(_scene.call("is_typing")).is_true()
	var text_label: Label = _scene.get_node("%TextLabel")
	assert_int(text_label.visible_characters).is_less(text_label.get_total_character_count())
	assert_str((_scene.get_node("%SpeakerLabel") as Label).text).is_equal(_dialogue.lines[0].speaker)


func test_enter_shows_whole_line_then_next_line() -> void:
	_runner.simulate_key_pressed(KEY_ENTER)
	await _runner.await_input_processed()
	assert_bool(_scene.call("is_typing")).is_false()
	assert_int(_scene.call("current_index")).is_equal(0)

	_runner.simulate_key_pressed(KEY_ENTER)
	await _runner.await_input_processed()
	assert_int(_scene.call("current_index")).is_equal(1)
	assert_bool(_scene.call("is_typing")).is_true()


func test_line_finishes_typing_by_itself() -> void:
	# 3 s de jeu simulées : assez pour écrire la première réplique.
	await _runner.simulate_frames(30, 100)
	assert_bool(_scene.call("is_typing")).is_false()


func test_finished_after_last_line() -> void:
	var emitted := [false]
	_scene.connect("finished", func() -> void: emitted[0] = true)
	# Deux appuis par réplique : tout afficher, puis passer à la suivante.
	for i in _dialogue.lines.size() * 2:
		_scene.call("advance")
	assert_bool(emitted[0]).is_true()


func test_skip_finishes_the_whole_dialogue() -> void:
	var emitted := [false]
	_scene.connect("finished", func() -> void: emitted[0] = true)
	_runner.simulate_key_pressed(KEY_TAB)
	await _runner.await_input_processed()
	assert_bool(emitted[0]).is_true()


func test_history_lists_lines_already_read_and_pauses_the_dialogue() -> void:
	_scene.call("advance")
	_scene.call("advance")
	_runner.simulate_key_pressed(KEY_H)
	await _runner.await_input_processed()
	assert_bool(_scene.call("is_history_open")).is_true()
	var history: RichTextLabel = _scene.get_node("%HistoryText")
	assert_str(history.get_parsed_text()).contains(_dialogue.lines[0].text)
	assert_str(history.get_parsed_text()).contains(_dialogue.lines[1].text)
	# Historique ouvert : Entrée ne fait pas avancer le dialogue.
	_scene.call("advance")
	assert_int(_scene.call("current_index")).is_equal(1)
	_runner.simulate_key_pressed(KEY_H)
	await _runner.await_input_processed()
	assert_bool(_scene.call("is_history_open")).is_false()


func test_after_a_short_rest_the_narrator_tells_what_each_one_recovered() -> void:
	var saved_step := GameState.current_step_id
	GameState.current_step_id = &"after_ambush"
	var healed := ShortRestResult.new()
	healed.hit_die_roll = 6
	healed.healed = 8
	healed.second_wind_regained = true
	var report: Array[ShortRestResult] = [healed, ShortRestResult.new()]
	GameState.rest_report = report
	var story_scene: Control = auto_free(load("res://scenes/dialogue/dialogue.tscn").instantiate())
	scene_runner(story_scene)
	GameState.current_step_id = saved_step
	var told: DialogueDef = story_scene.get("dialogue")
	var written := DataRegistry.load_from().dialogue(&"after_ambush")
	assert_int(told.lines.size()).is_equal(written.lines.size() + 2)
	assert_str(told.lines[-2].text).is_equal("Repos court : Guerrier panse ses plaies (dé de vie 6, +8 PV) et retrouve une utilisation de Second souffle.")
	assert_str(told.lines[-1].text).is_equal("Repos court : Roublard n'a besoin de rien.")
	# Le dialogue de l'histoire n'est pas modifié, et le compte rendu est lu.
	assert_int(written.lines.size()).is_equal(4)
	assert_array(GameState.rest_report).is_empty()
