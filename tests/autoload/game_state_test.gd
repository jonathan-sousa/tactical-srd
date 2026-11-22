## Progression dans l'histoire. On teste une instance neuve de GameState,
## sans toucher au singleton du jeu ni changer de scène.
extends GdUnitTestSuite

const GameStateScript := preload("res://autoload/game_state.gd")

var _game: Node


func before_test() -> void:
	# Note gdUnit4 : auto_free() libère le Node à la fin du test.
	_game = auto_free(GameStateScript.new())
	_game.setup(DataRegistry.load_from())


func test_new_game_starts_at_first_step_with_full_hp() -> void:
	_game.new_game()
	assert_str(_game.current_step_id).is_equal("intro")
	assert_int(_game.player_hp).is_equal(12)
	assert_bool(_game.story_completed).is_false()
	assert_bool(_game.has_game()).is_true()


func test_no_game_before_new_game() -> void:
	assert_bool(_game.has_game()).is_false()
	assert_object(_game.current_step()).is_null()


func test_dialogue_done_goes_to_next_step() -> void:
	_game.new_game()
	assert_int(_game.complete_step(GameStateScript.Outcome.DONE)).is_equal(GameStateScript.Next.STEP)
	assert_str(_game.current_step_id).is_equal("goblin_ambush")


func test_defeat_without_defeat_step_shows_defeat_screen_and_stays() -> void:
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	assert_int(_game.complete_step(GameStateScript.Outcome.DEFEAT)).is_equal(GameStateScript.Next.DEFEAT_SCREEN)
	# On reste sur le combat : « Réessayer » le relance à l'identique.
	assert_str(_game.current_step_id).is_equal("goblin_ambush")
	assert_int(_game.player_hp).is_equal(12)


func test_victory_keeps_remaining_hp() -> void:
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	assert_int(_game.complete_step(GameStateScript.Outcome.VICTORY, 7)).is_equal(GameStateScript.Next.STEP)
	assert_str(_game.current_step_id).is_equal("victory")
	assert_int(_game.player_hp).is_equal(7)


func test_last_step_ends_the_story() -> void:
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	_game.complete_step(GameStateScript.Outcome.VICTORY, 7)
	assert_int(_game.complete_step(GameStateScript.Outcome.DONE)).is_equal(GameStateScript.Next.END)
	assert_bool(_game.story_completed).is_true()
	assert_str(_game.current_step_id).is_empty()
	assert_bool(_game.has_game()).is_false()


func test_defeat_step_is_followed_when_defined() -> void:
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	# La ressource de l'histoire est partagée par tous les tests : on la
	# remet en état sur l'étape de combat elle-même, pas sur l'étape courante.
	var combat_step: StoryStep = _game.current_step()
	combat_step.defeat_step = &"intro"
	var next: int = _game.complete_step(GameStateScript.Outcome.DEFEAT)
	combat_step.defeat_step = &""
	assert_int(next).is_equal(GameStateScript.Next.STEP)
	assert_str(_game.current_step_id).is_equal("intro")


func test_progress_changed_is_emitted_on_each_new_step() -> void:
	var count := [0]
	_game.progress_changed.connect(func() -> void: count[0] += 1)
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	_game.complete_step(GameStateScript.Outcome.DEFEAT)
	# La défaite sans étape de défaite ne change rien : pas de sauvegarde.
	assert_int(count[0]).is_equal(2)
