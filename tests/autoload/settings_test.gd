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


func test_round_trip() -> void:
	_settings.master_volume = 0.4
	_settings.fullscreen = true
	assert_int(_settings.save_settings()).is_equal(OK)

	var other: Node = auto_free(SettingsScript.new())
	other.path = TEST_PATH
	other.load_settings()
	assert_float(other.master_volume).is_equal_approx(0.4, 0.001)
	assert_bool(other.fullscreen).is_true()


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
