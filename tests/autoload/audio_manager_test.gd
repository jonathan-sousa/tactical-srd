## Son : bus séparés, catalogue de bruitages, musique de chaque écran.
extends GdUnitTestSuite


func test_music_and_effects_have_their_own_bus() -> void:
	for bus: StringName in [AudioManager.MUSIC_BUS, AudioManager.EFFECTS_BUS]:
		var index := AudioServer.get_bus_index(bus)
		assert_int(index).override_failure_message("Bus manquant : %s" % bus).is_greater(0)
		assert_str(AudioServer.get_bus_send(index)).is_equal("Master")


func test_every_effect_has_at_least_one_sound() -> void:
	for effect: StringName in AudioManager.EFFECTS:
		var variants: Array = AudioManager.EFFECTS[effect]
		assert_array(variants).override_failure_message("Son vide : %s" % effect).is_not_empty()
		for stream: Variant in variants:
			assert_object(stream).is_instanceof(AudioStream)


func test_playing_an_effect_remembers_it() -> void:
	AudioManager.play(AudioManager.HIT)
	assert_str(AudioManager.last_effect).is_equal(AudioManager.HIT)


func test_music_switch_and_stop() -> void:
	AudioManager.play_music(AudioManager.COMBAT_MUSIC)
	assert_object(AudioManager.current_music()).is_same(AudioManager.COMBAT_MUSIC)
	AudioManager.play_music(AudioManager.MENU_MUSIC)
	assert_object(AudioManager.current_music()).is_same(AudioManager.MENU_MUSIC)
	AudioManager.stop_music()
	assert_object(AudioManager.current_music()).is_null()


func test_menu_plays_the_menu_music() -> void:
	AudioManager.stop_music()
	var runner := scene_runner("res://scenes/menu/menu.tscn")
	await runner.simulate_frames(2)
	assert_object(AudioManager.current_music()).is_same(AudioManager.MENU_MUSIC)
