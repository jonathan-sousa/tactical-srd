## La bande : le Sbire gobelin et ses dagues, l'IA face à un groupe
## (choix de la cible, déplacements entre alliés), et des combats complets
## sur la vraie rencontre.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState


## Combat sur une grille vide (sauf `blocked`) : des Guerriers de base aux
## cases `starts`, puis les ennemis de `enemies` (fiche → case, dans
## l'ordre). Le premier ennemi joue en premier (20 à l'initiative, 1 pour
## les autres).
func _fight(grid: Vector2i, starts: Array[Vector2i], enemies: Array[Array], blocked: Array[Vector2i] = []) -> void:
	var no_cells: Array[Vector2i] = []
	var encounter := Fixtures.party_encounter(grid, starts, no_cells, blocked)
	for pair in enemies:
		var placement := EnemyPlacement.new()
		placement.character = pair[0]
		placement.cell = pair[1]
		encounter.enemies.append(placement)
	var party: Array[CharacterDef] = []
	for i in starts.size():
		party.append(Fixtures.fighter())
	_state = CombatState.create_party(encounter, party)
	var rolls: Array = []
	for combatant in _state.combatants:
		rolls.append(1)
	rolls[starts.size()] = 20
	_state.start(_dice(rolls))
	assert_object(_state.active()).is_same(_state.combatants[starts.size()])


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


## Joue le tour de l'IA jusqu'au bout et renvoie ses actions.
func _play_turn(dice: Dice) -> Array[Action]:
	var actor := _state.active()
	var played: Array[Action] = []
	for i in EnemyAI.MAX_ACTIONS_PER_TURN:
		if _state.is_over or _state.active() != actor:
			break
		var action := EnemyAI.next_action(_state, actor)
		assert_str(action.validate(_state)).override_failure_message("Action refusée : %s" % action.get_script().get_global_name()).is_empty()
		played.append(action)
		action.execute(_state, dice)
		while _state.pending != null:
			EnemyAI.decide(_state).execute(_state, dice)
	return played


func _attacks(actions: Array[Action]) -> Array[AttackAction]:
	var attacks: Array[AttackAction] = []
	for action in actions:
		if action is AttackAction:
			attacks.append(action)
	return attacks


func _enemy(index: int) -> Combatant:
	return _state.combatants[_state.party().size() + index]


# --- Le Sbire et ses dagues ------------------------------------------------------


func test_minion_throws_a_dagger_from_afar_and_loses_it() -> void:
	_fight(Vector2i(12, 8), [Vector2i(1, 1)], [[Fixtures.minion(), Vector2i(5, 1)]])
	var minion := _enemy(0)
	# 20 ft : portée normale de la dague. 1 naturel : raté.
	var attacks := _attacks(_play_turn(_dice([1])))
	assert_int(attacks.size()).is_equal(1)
	assert_str(attacks[0].weapon.id).is_equal(&"dagger")
	assert_int(_state.attack_kind(minion, attacks[0].target, attacks[0].weapon)).is_equal(CombatState.AttackKind.RANGED)
	assert_int(minion.quantity(attacks[0].weapon)).is_equal(2)
	assert_that(minion.position).is_equal(Vector2i(5, 1))


func test_minion_keeps_its_last_dagger_for_melee() -> void:
	_fight(Vector2i(12, 8), [Vector2i(1, 1)], [[Fixtures.minion(), Vector2i(5, 1)]])
	var minion := _enemy(0)
	var dagger := minion.definition.weapons[0]
	minion.quantities[dagger.id] = 1
	var played := _play_turn(_dice([1]))
	assert_object(played[0]).is_instanceof(MoveAction)
	var attacks := _attacks(played)
	assert_int(attacks.size()).is_equal(1)
	assert_int(GridPathfinder.chebyshev(minion.position, attacks[0].target.position)).is_equal(1)
	assert_int(minion.quantity(dagger)).is_equal(1)


func test_adjacent_minion_stabs_without_losing_its_dagger() -> void:
	_fight(Vector2i(12, 8), [Vector2i(1, 1)], [[Fixtures.minion(), Vector2i(2, 1)]])
	var minion := _enemy(0)
	var attacks := _attacks(_play_turn(_dice([1])))
	assert_int(attacks.size()).is_equal(1)
	assert_int(_state.attack_kind(minion, attacks[0].target, attacks[0].weapon)).is_equal(CombatState.AttackKind.MELEE)
	assert_int(minion.quantity(attacks[0].weapon)).is_equal(3)


# --- Choix de la cible -------------------------------------------------------------


func test_goblin_prefers_a_standing_character_to_a_downed_one() -> void:
	_fight(Vector2i(12, 8), [Vector2i(3, 3), Vector2i(7, 3)], [[Fixtures.goblin(), Vector2i(4, 4)]])
	var downed := _state.combatants[0]
	var standing := _state.combatants[1]
	downed.hp = 0
	# Raté (1), puis le jet contre la mort du Guerrier à terre, qui joue
	# ensuite (10).
	var attacks := _attacks(_play_turn(_dice([1, 10])))
	assert_int(attacks.size()).is_equal(1)
	assert_object(attacks[0].target).is_same(standing)


func test_goblin_strikes_a_downed_character_when_no_one_else_is_within_reach() -> void:
	_fight(Vector2i(12, 8), [Vector2i(0, 4), Vector2i(11, 4)], [[Fixtures.goblin(), Vector2i(1, 4)]])
	var downed := _state.combatants[0]
	downed.hp = 0
	# Avantage contre un personnage à terre : 1 et 1, raté. Puis son jet
	# contre la mort (10).
	var attacks := _attacks(_play_turn(_dice([1, 1, 10])))
	assert_int(attacks.size()).is_equal(1)
	assert_object(attacks[0].target).is_same(downed)


func test_goblin_goes_for_the_closest_character_by_path_length() -> void:
	# A est à 3 cases à vol d'oiseau mais derrière un mur (5 cases de
	# chemin) ; B est à 4 cases, en ligne droite (3 cases de chemin).
	var wall: Array[Vector2i] = [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]
	_fight(Vector2i(12, 8), [Vector2i(5, 0), Vector2i(9, 3)], [[Fixtures.goblin(), Vector2i(5, 3)]], wall)
	var attacks := _attacks(_play_turn(_dice([1])))
	assert_int(attacks.size()).is_equal(1)
	assert_object(attacks[0].target).is_same(_state.combatants[1])


# --- Se déplacer entre alliés ------------------------------------------------------


func test_approach_stops_short_of_an_ally_standing_where_it_would_stop() -> void:
	# Couloir d'une case de large : le gobelin passe par la case de son allié,
	# mais ne peut pas s'y arrêter.
	_fight(Vector2i(12, 1), [Vector2i(11, 0)], [[Fixtures.goblin(), Vector2i(0, 0)], [Fixtures.goblin(), Vector2i(6, 0)]])
	var action := EnemyAI.next_action(_state, _state.active())
	assert_str(action.validate(_state)).is_empty()
	assert_object(action).is_instanceof(MoveAction)
	assert_that((action as MoveAction).destination).is_equal(Vector2i(5, 0))


func test_goblins_walk_through_each_other_to_reach_the_fight() -> void:
	# Couloir : le gobelin du fond traverse son allié pour aller au contact.
	_fight(Vector2i(12, 1), [Vector2i(0, 0)], [[Fixtures.goblin(), Vector2i(4, 0)], [Fixtures.goblin(), Vector2i(2, 0)]])
	var attacks := _attacks(_play_turn(_dice([1])))
	assert_int(attacks.size()).is_equal(1)
	assert_that(_enemy(0).position).is_equal(Vector2i(1, 0))


# --- Noms ----------------------------------------------------------------------------


func test_identical_creatures_are_numbered() -> void:
	var state := CombatState.create_party(DataRegistry.load_from().encounter(&"goblin_band"), [Fixtures.fighter()])
	var names: Array[String] = []
	for combatant in state.combatants:
		names.append(combatant.display_name)
	assert_array(names).contains_exactly(["Guerrier", "Sbire gobelin 1", "Sbire gobelin 2", "Gobelin guerrier"])
	assert_str(state.combatants[0].short_name()).is_equal("Guerrier")
	assert_str(state.combatants[2].short_name()).is_equal("Sbire 2")


# --- Combats complets ----------------------------------------------------------------


func test_band_fights_to_the_end_with_legal_actions_only() -> void:
	var registry := DataRegistry.load_from()
	var fighter := registry.character(&"fighter_lvl1")
	var party: Array[CharacterDef] = [fighter, fighter]
	for seed_value in range(1, 11):
		var simulator := CombatSimulator.new(CombatState.create_party(registry.encounter(&"goblin_band"), party), Dice.seeded(seed_value))
		simulator.start()
		simulator.run_to_end()
		assert_bool(simulator.state.is_over).override_failure_message("Graine %d : combat pas fini." % seed_value).is_true()
		assert_array(simulator.refused).override_failure_message("Graine %d : %s" % [seed_value, simulator.refused]).is_empty()
