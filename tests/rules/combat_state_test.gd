## Tours, déplacements, attaques et fin de combat, sans aucune scène.
extends GdUnitTestSuite

const FixedDice := preload("res://tests/helpers/fixed_dice.gd")
const Fixtures := preload("res://tests/helpers/fixtures.gd")

var _state: CombatState
var _fighter: Combatant
var _goblin: Combatant


## Grille 12×8 sans obstacle, Guerrier en (0, 0), Gobelin en (5, 0).
## Initiative : Guerrier 10 + 1 = 11, Gobelin 5 + 2 = 7, le Guerrier commence.
func before_test() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 0)]
	_state = CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells), Fixtures.fighter())
	_state.start(FixedDice.new([10, 5]))
	_fighter = _state.combatants[0]
	_goblin = _state.combatants[1]


func _run(action: Action, dice: Dice = FixedDice.new([])) -> Array[CombatEvent]:
	assert_str(action.validate(_state)).is_empty()
	return action.execute(_state, dice)


# --- Démarrage ---------------------------------------------------------------


func test_start_rolls_initiative_and_starts_first_turn() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells), Fixtures.fighter())
	var events := state.start(FixedDice.new([10, 5]))
	assert_int(events.size()).is_equal(2)
	assert_object(events[0]).is_instanceof(InitiativeRolledEvent)
	assert_object(events[1]).is_instanceof(TurnStartedEvent)
	assert_int(state.round).is_equal(1)
	assert_object(state.active()).is_same(state.combatants[0])
	assert_int(state.movement_left).is_equal(6)
	assert_bool(state.action_used).is_false()


func test_combatants_start_on_their_cells() -> void:
	assert_that(_fighter.position).is_equal(Vector2i(0, 0))
	assert_that(_goblin.position).is_equal(Vector2i(5, 0))
	assert_int(_fighter.side).is_equal(Combatant.Side.PLAYER)
	assert_int(_goblin.side).is_equal(Combatant.Side.ENEMY)


# --- Déplacement -------------------------------------------------------------


func test_movement_can_be_split_up_to_speed() -> void:
	_run(MoveAction.new(_fighter, Vector2i(0, 3)))
	assert_int(_state.movement_left).is_equal(3)
	_run(MoveAction.new(_fighter, Vector2i(3, 3)))
	assert_int(_state.movement_left).is_equal(0)
	assert_str(MoveAction.new(_fighter, Vector2i(4, 3)).validate(_state)).is_equal(Action.NOT_ENOUGH_MOVEMENT)


func test_move_event_contains_the_path() -> void:
	var events := _run(MoveAction.new(_fighter, Vector2i(2, 2)))
	var moved := events[0] as MovedEvent
	assert_that(moved.from).is_equal(Vector2i(0, 0))
	assert_array(moved.path).contains_exactly(Vector2i(1, 1), Vector2i(2, 2))
	assert_that(_fighter.position).is_equal(Vector2i(2, 2))


func test_cannot_move_beyond_speed_in_one_go() -> void:
	assert_str(MoveAction.new(_fighter, Vector2i(7, 7)).validate(_state)).is_equal(Action.NOT_ENOUGH_MOVEMENT)


func test_cannot_move_onto_an_occupied_cell() -> void:
	assert_str(MoveAction.new(_fighter, Vector2i(5, 0)).validate(_state)).is_equal(Action.CELL_UNREACHABLE)


func test_cannot_move_onto_its_own_cell() -> void:
	assert_str(MoveAction.new(_fighter, Vector2i(0, 0)).validate(_state)).is_equal(Action.SAME_CELL)


# --- Attaque -----------------------------------------------------------------


func test_attack_needs_an_adjacent_target() -> void:
	assert_str(AttackAction.new(_fighter, _goblin).validate(_state)).is_equal(Action.TARGET_OUT_OF_REACH)


func test_attack_diagonally_adjacent_target() -> void:
	_run(MoveAction.new(_fighter, Vector2i(4, 1)))
	assert_str(AttackAction.new(_fighter, _goblin).validate(_state)).is_empty()


func test_attack_resolves_and_applies_damage() -> void:
	_run(MoveAction.new(_fighter, Vector2i(4, 0)))
	# 15 + 5 = 20 contre CA 15 : touché, 2d6+3 = 1 + 2 + 3 = 6.
	var events := _run(AttackAction.new(_fighter, _goblin), FixedDice.new([15, 1, 2]))
	assert_object(events[0]).is_instanceof(AttackRolledEvent)
	var damage := events[1] as DamageDealtEvent
	assert_int(damage.amount).is_equal(6)
	assert_int(damage.hp_after).is_equal(4)
	assert_int(_goblin.hp).is_equal(4)
	assert_bool(_state.action_used).is_true()


func test_missed_attack_deals_no_damage() -> void:
	_run(MoveAction.new(_fighter, Vector2i(4, 0)))
	var events := _run(AttackAction.new(_fighter, _goblin), FixedDice.new([2]))
	assert_int(events.size()).is_equal(1)
	assert_int(_goblin.hp).is_equal(10)


func test_only_one_attack_per_turn_but_can_still_move() -> void:
	_run(MoveAction.new(_fighter, Vector2i(4, 0)))
	_run(AttackAction.new(_fighter, _goblin), FixedDice.new([2]))
	assert_str(AttackAction.new(_fighter, _goblin).validate(_state)).is_equal(Action.ACTION_ALREADY_USED)
	# 4 cases utilisées, il en reste 2 après l'action.
	_run(MoveAction.new(_fighter, Vector2i(4, 2)))
	assert_int(_state.movement_left).is_equal(0)


func test_cannot_attack_an_ally_or_itself() -> void:
	assert_str(AttackAction.new(_fighter, _fighter).validate(_state)).is_equal(Action.TARGET_NOT_ENEMY)


func test_cannot_act_outside_its_turn() -> void:
	assert_str(MoveAction.new(_goblin, Vector2i(6, 0)).validate(_state)).is_equal(Action.NOT_YOUR_TURN)
	assert_str(EndTurnAction.new(_goblin).validate(_state)).is_equal(Action.NOT_YOUR_TURN)


# --- Tours -------------------------------------------------------------------


func test_end_turn_passes_to_next_and_resets_budget() -> void:
	_run(MoveAction.new(_fighter, Vector2i(4, 0)))
	_run(AttackAction.new(_fighter, _goblin), FixedDice.new([2]))
	var events := _run(EndTurnAction.new(_fighter))
	assert_object((events[0] as TurnStartedEvent).combatant).is_same(_goblin)
	assert_object(_state.active()).is_same(_goblin)
	assert_int(_state.movement_left).is_equal(6)
	assert_bool(_state.action_used).is_false()
	assert_int(_state.round).is_equal(1)


func test_new_round_after_everyone_played() -> void:
	_run(EndTurnAction.new(_fighter))
	_run(EndTurnAction.new(_goblin))
	assert_object(_state.active()).is_same(_fighter)
	assert_int(_state.round).is_equal(2)


func test_downed_combatant_is_skipped() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 0), Vector2i(7, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells), Fixtures.fighter())
	# Initiative : Guerrier 11, premier Gobelin 9, second Gobelin 7.
	state.start(FixedDice.new([10, 7, 5]))
	state.combatants[1].take_damage(10)
	EndTurnAction.new(state.combatants[0]).execute(state, FixedDice.new([]))
	assert_object(state.active()).is_same(state.combatants[2])


# --- Fin du combat ------------------------------------------------------------


func test_combat_ends_when_last_enemy_falls() -> void:
	_goblin.take_damage(9)
	_run(MoveAction.new(_fighter, Vector2i(4, 0)))
	var events := _run(AttackAction.new(_fighter, _goblin), FixedDice.new([15, 1, 1]))
	assert_object(events[2]).is_instanceof(CombatantDownedEvent)
	var ended := events[3] as CombatEndedEvent
	assert_int(ended.winner).is_equal(Combatant.Side.PLAYER)
	assert_bool(_state.is_over).is_true()
	assert_str(EndTurnAction.new(_fighter).validate(_state)).is_equal(Action.COMBAT_OVER)


func test_player_loses_at_zero_hit_points() -> void:
	_fighter.take_damage(11)
	_run(EndTurnAction.new(_fighter))
	_run(MoveAction.new(_goblin, Vector2i(1, 0)))
	var events := _run(AttackAction.new(_goblin, _fighter), FixedDice.new([15, 3]))
	assert_int((events.back() as CombatEndedEvent).winner).is_equal(Combatant.Side.ENEMY)
	assert_bool(_fighter.is_down()).is_true()


func test_player_can_start_with_remaining_hit_points() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 0)]
	var state := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells), Fixtures.fighter(), 7)
	assert_int(state.combatants[0].hp).is_equal(7)
	# Jamais au-delà du maximum.
	var healed := CombatState.create(Fixtures.encounter(Vector2i(12, 8), Vector2i(0, 0), cells), Fixtures.fighter(), 99)
	assert_int(healed.combatants[0].hp).is_equal(12)
