## Options persistées dans un ConfigFile, indépendamment de la sauvegarde.
extends GdUnitTestSuite

const SettingsScript := preload("res://autoload/settings.gd")
const TEST_PATH := "user://test_settings.cfg"

var _settings: Node


func before_test() -> void:
	_cleanup()
	_settings = auto_free(SettingsScript.new())
	_settings.path = TEST_PATH


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func test_defaults_without_file() -> void:
	_settings.load_settings()
	assert_float(_settings.master_volume).is_equal(1.0)
	assert_bool(_settings.fullscreen).is_false()
	assert_bool(_settings.large_text).is_false()


func test_round_trip() -> void:
	_settings.master_volume = 0.4
	_settings.fullscreen = true
	_settings.large_text = true
	assert_int(_settings.save_settings()).is_equal(OK)

	var other: Node = auto_free(SettingsScript.new())
	other.path = TEST_PATH
	other.load_settings()
	assert_float(other.master_volume).is_equal_approx(0.4, 0.001)
	assert_bool(other.fullscreen).is_true()
	assert_bool(other.large_text).is_true()


func test_invalid_values_fall_back_to_defaults() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[audio]\nmaster_volume=\"fort\"\n[display]\nfullscreen=12\n")
	file.close()
	_settings.load_settings()
	assert_float(_settings.master_volume).is_equal(1.0)
	assert_bool(_settings.fullscreen).is_false()


func test_volume_is_clamped() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[audio]\nmaster_volume=7.5\n")
	file.close()
	_settings.load_settings()
	assert_float(_settings.master_volume).is_equal(1.0)


func test_volume_to_decibels() -> void:
	assert_float(SettingsScript.volume_to_db(1.0)).is_equal_approx(0.0, 0.001)
	assert_float(SettingsScript.volume_to_db(0.0)).is_less(-60.0)


func test_large_text_is_announced_and_picks_the_bigger_size() -> void:
	var announced: Array[bool] = []
	_settings.large_text_changed.connect(func(enabled: bool) -> void: announced.append(enabled))
	assert_int(_settings.font_size(15, 19)).is_equal(15)
	_settings.set_large_text(true)
	assert_array(announced).contains_exactly([true])
	assert_int(_settings.font_size(15, 19)).is_equal(19)


func test_music_and_effects_volumes_round_trip() -> void:
	_settings.music_volume = 0.3
	_settings.effects_volume = 0.7
	assert_int(_settings.save_settings()).is_equal(OK)
	var other: Node = auto_free(SettingsScript.new())
	other.path = TEST_PATH
	other.load_settings()
	assert_float(other.music_volume).is_equal_approx(0.3, 0.001)
	assert_float(other.effects_volume).is_equal_approx(0.7, 0.001)


func test_file_from_before_the_music_volume_keeps_its_master_volume() -> void:
	# Fichier de la v1 : seulement le volume général.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[audio]
master_volume=0.5
[display]
fullscreen=false
")
	file.close()
	_settings.load_settings()
	assert_float(_settings.master_volume).is_equal_approx(0.5, 0.001)
	assert_float(_settings.music_volume).is_equal(1.0)
	assert_float(_settings.effects_volume).is_equal(1.0)


func test_volumes_are_applied_to_their_bus() -> void:
	var saved_music: float = Settings.music_volume
	_settings.music_volume = 0.5
	_settings.effects_volume = 0.0
	_settings.apply_volume()
	assert_float(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music"))).is_equal_approx(linear_to_db(0.5), 0.01)
	assert_bool(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Effects"))).is_true()
	# Remet les volumes du jeu.
	Settings.music_volume = saved_music
	Settings.apply_volume()


func test_enemy_hit_points_are_approximate_by_default() -> void:
	# Fichier d'avant le sprint 4 : pas de clé, PV ennemis approximatifs.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[display]\nlarge_text=true\n")
	file.close()
	_settings.load_settings()
	assert_bool(_settings.exact_enemy_hp).is_false()


func test_exact_enemy_hit_points_round_trip_and_announce() -> void:
	var announced: Array[bool] = []
	_settings.exact_enemy_hp_changed.connect(func(enabled: bool) -> void: announced.append(enabled))
	_settings.set_exact_enemy_hp(true)
	assert_array(announced).contains_exactly([true])
	var other: Node = auto_free(SettingsScript.new())
	other.path = TEST_PATH
	other.load_settings()
	assert_bool(other.exact_enemy_hp).is_true()


func test_invalid_exact_enemy_hit_points_falls_back_to_default() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("[gameplay]\nexact_enemy_hp=\"oui\"\n")
	file.close()
	_settings.load_settings()
	assert_bool(_settings.exact_enemy_hp).is_false()
