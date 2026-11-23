## IA du Gobelin : se cacher d'abord, tirer de loin, frapper au contact, se
## désengager avant de reculer à l'abri, achever un Guerrier inconscient.
## Chaque action proposée est valide et le tour se termine toujours.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×8 : Guerrier (fiche de base) et Gobelin complet, le Gobelin
## commence (1 + 1 contre 20 + 2).
func _goblin_turn(player_cell: Vector2i, goblin_cell: Vector2i, blocked: Array[Vector2i] = []) -> void:
	var cells: Array[Vector2i] = [goblin_cell]
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 8), player_cell, cells, blocked, Fixtures.full_goblin()), Fixtures.fighter())
	_state.start(_dice([1, 20]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]
	assert_object(_state.active()).is_same(_goblin)


func _dice(values: Array) -> Dice:
	var typed: Array[int] = []
	typed.assign(values)
	return FixedDice.new(typed)


## Joue le tour de l'IA jusqu'au bout et renvoie ses actions. Les réactions
## éventuelles du Guerrier sont jouées par l'IA aussi.
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
	assert_bool(_state.is_over or _state.active() != actor).override_failure_message("Le tour ne se termine pas.").is_true()
	return played


func _types(actions: Array[Action]) -> Array[String]:
	var names: Array[String] = []
	for action in actions:
		names.append(action.get_script().get_global_name())
	return names


func test_adjacent_goblin_strikes_then_disengages_and_retreats_to_cover() -> void:
	var wall: Array[Vector2i] = [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4)]
	_goblin_turn(Vector2i(3, 3), Vector2i(4, 3), wall)
	# 1 naturel : le cimeterre rate.
	var played := _play_turn(_dice([1]))
	assert_array(_types(played)).is_equal(["AttackAction", "StandardAction", "MoveAction", "EndTurnAction"])
	assert_object((played[0] as AttackAction).weapon).is_same(_goblin.melee_weapon())
	var disengage := played[1] as StandardAction
	assert_str(disengage.kind).is_equal(StandardAction.DISENGAGE)
	assert_bool(disengage.bonus_action).is_true()
	# Désengagé : pas d'attaque d'opportunité, et il finit hors de vue.
	assert_bool(_fighter.reaction_available).is_true()
	assert_bool(_state.is_out_of_sight_at(_goblin, _goblin.position)).is_true()


func test_out_of_sight_goblin_hides_first_then_shoots_with_advantage() -> void:
	var wall: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	_goblin_turn(Vector2i(1, 3), Vector2i(8, 3), wall)
	# Discrétion 10 + 6 = 16 : caché. Tir avec l'avantage : 2 et 15, on
	# garde 15, 19 contre CA 16 : touché ; 1d6 + 2 et 1d4 : 3 + 2 + 2.
	var played := _play_turn(_dice([10, 2, 15, 3, 2]))
	assert_array(_types(played).slice(0, 3)).is_equal(["HideAction", "MoveAction", "AttackAction"])
	assert_bool((played[0] as HideAction).bonus_action).is_true()
	assert_object((played[2] as AttackAction).weapon).is_same(_goblin.definition.weapons[1])
	assert_int(_fighter.hp).is_equal(5)
	assert_bool(_state.is_hidden(_goblin)).is_false()


func test_goblin_in_sight_shoots_from_where_it_stands() -> void:
	_goblin_turn(Vector2i(1, 3), Vector2i(8, 3))
	var start := _goblin.position
	var played := _play_turn(_dice([1]))
	assert_array(_types(played)).is_equal(["AttackAction", "EndTurnAction"])
	assert_object((played[0] as AttackAction).weapon).is_same(_goblin.definition.weapons[1])
	assert_that(_goblin.position).is_equal(start)


func test_goblin_finishes_an_unconscious_fighter_in_melee() -> void:
	_goblin_turn(Vector2i(1, 3), Vector2i(4, 3))
	HitPoints.apply_damage(_state, _fighter, 12, DamageType.Type.SLASHING)
	# Avantage : 12 et 3 ; 16 contre CA 16, touché au contact : critique.
	# 2d6 + 2 et 2d4 ; puis le jet contre la mort du Guerrier (10).
	var played := _play_turn(_dice([12, 3, 1, 1, 1, 1, 10]))
	assert_array(_types(played)).is_equal(["MoveAction", "AttackAction", "EndTurnAction"])
	assert_int(GridPathfinder.chebyshev(_goblin.position, _fighter.position)).is_equal(1)
	assert_object((played[1] as AttackAction).weapon).is_same(_goblin.melee_weapon())
	assert_int(_fighter.death_save_failures).is_equal(2)


func test_picks_the_cell_with_the_shortest_path() -> void:
	# Mur à gauche du Guerrier inconscient : par le haut ou par le bas, 5
	# pas ; (5, 2) l'emporte à égalité (case la plus haute, puis à gauche).
	var wall: Array[Vector2i] = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4)]
	_goblin_turn(Vector2i(5, 3), Vector2i(2, 3), wall)
	HitPoints.apply_damage(_state, _fighter, 12, DamageType.Type.SLASHING)
	var move := EnemyAI.next_action(_state, _goblin) as MoveAction
	assert_object(move).is_not_null()
	assert_that(move.destination).is_equal(Vector2i(5, 2))
	assert_int(_state.find_path(_goblin, move.destination).size()).is_equal(5)


func test_down_actor_just_ends_its_turn() -> void:
	_goblin_turn(Vector2i(1, 3), Vector2i(8, 3))
	_goblin.hp = 0
	assert_object(EnemyAI.next_action(_state, _goblin)).is_instanceof(EndTurnAction)


func test_prone_actor_stands_up_first() -> void:
	_goblin_turn(Vector2i(1, 3), Vector2i(8, 3))
	_state.add_effect(Effect.new(Effect.PRONE, _goblin, _goblin, Effect.Expiry.UNTIL_REMOVED))
	assert_object(EnemyAI.next_action(_state, _goblin)).is_instanceof(StandUpAction)


func test_searches_when_every_enemy_is_hidden() -> void:
	var wall: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4)]
	_goblin_turn(Vector2i(1, 3), Vector2i(8, 3), wall)
	HideAction.new(_goblin).execute(_state, _dice([12]))
	EndTurnAction.new(_goblin).execute(_state, _dice([]))
	assert_object(EnemyAI.next_action(_state, _fighter)).is_instanceof(SearchAction)


func test_every_turn_ends_with_valid_actions() -> void:
	var wall: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4), Vector2i(8, 6)]
	var starts: Array[Vector2i] = [Vector2i(11, 7), Vector2i(2, 3), Vector2i(6, 3), Vector2i(9, 0), Vector2i(4, 6)]
	for goblin_cell in starts:
		for seed_value: int in [1, 2, 3]:
			_goblin_turn(Vector2i(1, 3), goblin_cell, wall)
			_play_turn(Dice.seeded(seed_value))
