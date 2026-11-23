## Sauvegarde JSON : aller-retour, fichier corrompu, version inconnue,
## écriture atomique. Chaque test écrit dans son propre fichier de test,
## jamais dans la vraie sauvegarde du joueur.
extends GdUnitTestSuite

const SaveManagerScript := preload("res://autoload/save_manager.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
const TEST_PATH := "user://test_save_manager.json"

var _saves: Node


func before_test() -> void:
	_cleanup()
	_saves = auto_free(SaveManagerScript.new())
	_saves.path = TEST_PATH


func after_test() -> void:
	_cleanup()


func _cleanup() -> void:
	for file: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)


func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _valid_save(overrides: Dictionary = {}) -> Dictionary:
	var save := {
		"version": 1,
		"saved_at": "2026-11-17T09:30:00Z",
		"story_step": "goblin_ambush",
		"story_completed": false,
		"player": {"def_id": "fighter_lvl1", "hp_current": 9},
	}
	save.merge(overrides, true)
	return save


# --- Lecture -------------------------------------------------------------------


func test_no_file_means_no_save() -> void:
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.NONE)
	assert_bool(_saves.has_save_file()).is_false()
	assert_bool(_saves.can_continue()).is_false()


func test_round_trip() -> void:
	assert_int(_saves.write(_valid_save())).is_equal(OK)
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.OK)
	assert_str(_saves.data["story_step"]).is_equal("goblin_ambush")
	assert_int(_saves.data["player"]["hp_current"]).is_equal(9)
	assert_bool(_saves.can_continue()).is_true()


func test_corrupted_file_is_reported_without_crash() -> void:
	_write_raw("{ ceci n'est pas du JSON")
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.CORRUPT)
	assert_bool(_saves.can_continue()).is_false()
	assert_bool(_saves.has_save_file()).is_true()
	assert_str(_saves.status_message()).is_equal(Texts.SAVE_CORRUPT)


func test_unknown_version_is_reported() -> void:
	_write_raw(JSON.stringify(_valid_save({"version": 99})))
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.UNKNOWN_VERSION)
	assert_bool(_saves.can_continue()).is_false()
	assert_str(_saves.status_message()).is_equal(Texts.SAVE_UNKNOWN_VERSION)


func test_fields_are_validated_one_by_one(save: Dictionary, test_parameters := [
	[{"version": 1}],
	[{"version": "1", "story_step": "intro", "player": {"def_id": "fighter_lvl1", "hp_current": 12}}],
	[{"version": 1, "story_step": 3, "player": {"def_id": "fighter_lvl1", "hp_current": 12}}],
	[{"version": 1, "story_step": "intro", "player": "fighter"}],
	[{"version": 1, "story_step": "intro", "player": {"def_id": "fighter_lvl1", "hp_current": "beaucoup"}}],
	[{"version": 1, "story_step": "intro", "player": {"def_id": "fighter_lvl1", "hp_current": 2.5}}],
	[{"version": 1, "story_step": "intro", "player": {"def_id": "fighter_lvl1", "hp_current": -4}}],
	[{"version": 1, "story_step": "intro", "player": {"def_id": "fighter_lvl1", "hp_current": 0}}],
	[{"version": 1, "story_step": "intro", "story_completed": "oui", "player": {"def_id": "fighter_lvl1", "hp_current": 12}}],
]) -> void:
	_write_raw(JSON.stringify(save))
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.CORRUPT)


func test_top_level_must_be_an_object() -> void:
	_write_raw("[1, 2, 3]")
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.CORRUPT)


func test_completed_story_cannot_be_continued() -> void:
	_saves.write(_valid_save({"story_step": "", "story_completed": true}))
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.OK)
	assert_bool(_saves.can_continue()).is_false()
	assert_bool(_saves.has_save_file()).is_true()


# --- Écriture ------------------------------------------------------------------


func test_write_is_atomic_and_leaves_no_temp_file() -> void:
	_saves.write(_valid_save())
	_saves.write(_valid_save({"story_step": "victory"}))
	assert_bool(FileAccess.file_exists(TEST_PATH + ".tmp")).is_false()
	_saves.reload()
	assert_str(_saves.data["story_step"]).is_equal("victory")


func test_stale_temp_file_does_not_break_loading() -> void:
	# Simule un plantage pendant une écriture : un .tmp à moitié écrit traîne.
	_saves.write(_valid_save())
	var tmp := FileAccess.open(TEST_PATH + ".tmp", FileAccess.WRITE)
	tmp.store_string("{ \"version\": 1, \"story")
	tmp.close()
	assert_int(_saves.reload()).is_equal(SaveManagerScript.Status.OK)
	assert_str(_saves.data["story_step"]).is_equal("goblin_ambush")


func test_written_file_is_plain_json_with_version() -> void:
	_saves.write(_valid_save())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	assert_int(int(parsed["version"])).is_equal(SaveManagerScript.CURRENT_VERSION)


# --- Lien avec GameState -------------------------------------------------------


func test_snapshot_and_restore_a_game() -> void:
	var game: Node = auto_free(GameStateScript.new())
	game.setup(DataRegistry.load_from())
	game.new_game()
	game.complete_step(GameStateScript.Outcome.DONE)
	game.player_hp = 8
	_saves.write(SaveManagerScript.snapshot(game))
	_saves.reload()

	var restored: Node = auto_free(GameStateScript.new())
	restored.setup(DataRegistry.load_from())
	assert_bool(_saves.restore_into(restored)).is_true()
	assert_str(restored.current_step_id).is_equal("goblin_ambush")
	assert_int(restored.player_hp).is_equal(8)


func test_save_pointing_to_unknown_step_cannot_be_restored() -> void:
	_saves.write(_valid_save({"story_step": "chapitre_inexistant"}))
	_saves.reload()
	var game: Node = auto_free(GameStateScript.new())
	game.setup(DataRegistry.load_from())
	assert_bool(_saves.restore_into(game)).is_false()
	assert_int(_saves.status).is_equal(SaveManagerScript.Status.CORRUPT)


func test_saves_automatically_when_progress_changes() -> void:
	var game: Node = auto_free(GameStateScript.new())
	game.setup(DataRegistry.load_from())
	_saves.watch(game)
	game.new_game()
	_saves.reload()
	assert_str(_saves.data["story_step"]).is_equal("intro")
	game.complete_step(GameStateScript.Outcome.DONE)
	_saves.reload()
	assert_str(_saves.data["story_step"]).is_equal("goblin_ambush")
