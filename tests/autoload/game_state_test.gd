## Progression dans l'histoire. On teste une instance neuve de GameState,
## sans toucher au singleton du jeu ni changer de scène.
extends GdUnitTestSuite

const GameStateScript := preload("res://autoload/game_state.gd")
const FixedDice := preload("res://tests/helpers/fixed_dice.gd")

var _game: Node


func before_test() -> void:
	# Note gdUnit4 : auto_free() libère le Node à la fin du test.
	_game = auto_free(GameStateScript.new())
	_game.setup(DataRegistry.load_from())
	# Dé de vie du repos court : 6.
	_game.rest_dice = FixedDice.new([6, 6] as Array[int])


## Le Guerrier à la fin d'un combat gagné.
func _survivor(hp: int, second_wind_uses: int = 2, inspiration: bool = true) -> Combatant:
	var fighter := Combatant.new(_game.party_definitions()[0], Combatant.Side.PLAYER)
	fighter.hp = hp
	fighter.second_wind_uses = second_wind_uses
	fighter.heroic_inspiration = inspiration
	return fighter


func _survivors(fighter: Combatant) -> Array[Combatant]:
	return [fighter]


func test_new_game_starts_at_first_step_with_full_hp() -> void:
	_game.new_game()
	assert_str(_game.current_step_id).is_equal("intro")
	assert_int(_game.party.size()).is_equal(2)
	assert_str(_game.party[1].id).is_equal(&"rogue_lvl1")
	assert_int(_game.party[1].hp).is_equal(10)
	assert_int(_game.party[0].hp).is_equal(12)
	assert_int(_game.party[0].second_wind_uses).is_equal(2)
	assert_bool(_game.party[0].heroic_inspiration).is_true()
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
	assert_int(_game.party[0].hp).is_equal(12)


func test_victory_keeps_remaining_hp_then_a_short_rest() -> void:
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	assert_int(_game.complete_step(GameStateScript.Outcome.VICTORY, _survivors(_survivor(3, 0, false)))).is_equal(GameStateScript.Next.STEP)
	assert_str(_game.current_step_id).is_equal("after_ambush")
	# Repos court avant le dialogue : dé de vie 6 + CON 2, et un Second
	# souffle revient. L'Inspiration héroïque, elle, attend un repos long.
	assert_int(_game.party[0].hp).is_equal(11)
	assert_int(_game.party[0].hit_dice).is_equal(0)
	assert_int(_game.party[0].second_wind_uses).is_equal(1)
	assert_bool(_game.party[0].heroic_inspiration).is_false()
	var report: Array[ShortRestResult] = _game.take_rest_report()
	assert_int(report.size()).is_equal(2)
	assert_int(report[0].healed).is_equal(8)
	# Le Roublard, intact, ne dépense rien.
	assert_int(report[1].hit_die_roll).is_equal(0)
	assert_array(_game.take_rest_report()).is_empty()


func test_last_step_ends_the_story() -> void:
	_game.new_game()
	_game.complete_step(GameStateScript.Outcome.DONE)
	_game.complete_step(GameStateScript.Outcome.VICTORY, _survivors(_survivor(7)))
	_game.complete_step(GameStateScript.Outcome.DONE)
	assert_str(_game.current_step_id).is_equal("goblin_band")
	_game.complete_step(GameStateScript.Outcome.VICTORY, _survivors(_survivor(7)))
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


func test_restore_refuses_a_party_that_is_not_the_game_party() -> void:
	var stranger := PartyMember.fresh(_game.party_definitions()[0])
	stranger.id = &"rogue_lvl1"
	var members: Array[PartyMember] = [stranger]
	assert_bool(_game.restore(&"goblin_ambush", members, false)).is_false()
	var empty: Array[PartyMember] = []
	assert_bool(_game.restore(&"goblin_ambush", empty, false)).is_false()

