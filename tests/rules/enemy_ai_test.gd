extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")


## Combat où le Gobelin joue en premier (initiative 2 + 1 contre 20 + 2).
func _goblin_turn(player_cell: Vector2i, goblin_cell: Vector2i, blocked: Array[Vector2i] = []) -> CombatState:
	var cells: Array[Vector2i] = [goblin_cell]
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), player_cell, cells, blocked), Fixtures.fighter())
	state.start(FixedDice.new([1, 20]))
	assert_int(state.active().side).is_equal(Combatant.Side.ENEMY)
	return state


func test_attacks_when_adjacent() -> void:
	var state := _goblin_turn(Vector2i(3, 3), Vector2i(4, 4))
	var plan := EnemyAI.plan_turn(state, state.active())
	assert_int(plan.size()).is_equal(2)
	assert_object(plan[0]).is_instanceof(AttackAction)
	assert_object(plan[1]).is_instanceof(EndTurnAction)


func test_moves_next_to_target_then_attacks_when_in_range() -> void:
	var state := _goblin_turn(Vector2i(0, 0), Vector2i(5, 0))
	var plan := EnemyAI.plan_turn(state, state.active())
	assert_int(plan.size()).is_equal(3)
	var move := plan[0] as MoveAction
	assert_that(move.destination).is_equal(Vector2i(1, 0))
	assert_object(plan[1]).is_instanceof(AttackAction)
	assert_object(plan[2]).is_instanceof(EndTurnAction)


func test_moves_closer_by_full_speed_when_too_far() -> void:
	var state := _goblin_turn(Vector2i(0, 0), Vector2i(11, 0))
	var plan := EnemyAI.plan_turn(state, state.active())
	assert_int(plan.size()).is_equal(2)
	# Plusieurs chemins de 6 cases sont équivalents (diagonales à coût 1) :
	# on vérifie seulement qu'il finit à 5 cases du Guerrier.
	var move := plan[0] as MoveAction
	assert_int(move.destination.x).is_equal(5)
	assert_str(move.validate(state)).is_empty()
	assert_object(plan[1]).is_instanceof(EndTurnAction)


func test_ends_turn_when_target_cannot_be_reached() -> void:
	# Le Guerrier est enfermé dans le coin par des obstacles.
	var walls: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var state := _goblin_turn(Vector2i(0, 0), Vector2i(8, 5), walls)
	var plan := EnemyAI.plan_turn(state, state.active())
	assert_int(plan.size()).is_equal(1)
	assert_object(plan[0]).is_instanceof(EndTurnAction)


func test_planned_actions_are_all_valid_in_sequence() -> void:
	var state := _goblin_turn(Vector2i(0, 0), Vector2i(5, 3))
	for action in EnemyAI.plan_turn(state, state.active()):
		assert_str(action.validate(state)).is_empty()
		action.execute(state, Dice.seeded(1))


func test_without_movement_left_does_not_plan_a_move() -> void:
	var state := _goblin_turn(Vector2i(0, 0), Vector2i(11, 0))
	state.movement_left = 0
	var plan := EnemyAI.plan_turn(state, state.active())
	assert_int(plan.size()).is_equal(1)
	assert_object(plan[0]).is_instanceof(EndTurnAction)


func test_every_planned_action_is_valid_when_played_in_order() -> void:
	for movement: int in [0, 1, 3, 6]:
		var state := _goblin_turn(Vector2i(0, 0), Vector2i(11, 0))
		state.movement_left = movement
		for action in EnemyAI.plan_turn(state, state.active()):
			assert_str(action.validate(state)).override_failure_message("Déplacement %d : action refusée." % movement).is_empty()
			action.execute(state, FixedDice.new([]))
